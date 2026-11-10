import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/checkout_window.dart';
import 'package:regun/services/scrap_store.dart';
import 'package:regun/utils/format_number.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web Scrap checkout through Bachs' hosted page.
///
/// The browser opens the hosted page in a new tab, so the game is never
/// navigated away from. Nothing about returning from that page grants Scrap:
/// the balance only moves when the server has a verified, amount-checked
/// delivery from Bachs. This client merely asks the server what happened.
class BachsScrapStore extends ChangeNotifier
    with WidgetsBindingObserver
    implements ScrapStoreBase {
  BachsScrapStore._();
  static final shared = BachsScrapStore._();

  /// A web build only offers checkout when it was compiled for it. Native
  /// builds are excluded even if the flag leaks in, because App Store rules
  /// forbid routing in-app users to an external storefront.
  static bool get supported =>
      kIsWeb && const bool.fromEnvironment('REGUN_WEB_SCRAP');

  static const _pollEvery = Duration(seconds: 4);

  /// How long to keep asking after the player closes the payment tab. The
  /// webhook can land a moment after the redirect, so stopping the instant the
  /// tab closes would abandon a payment that is about to settle.
  static const _closedChecks = 15;

  final _account = AccountController.shared;
  String? _owner;
  String? _reference;
  CheckoutTab? _tab;
  int _closedFor = 0;
  bool _busy = false;
  bool _checking = false;
  bool _retry = false;
  bool _started = false;
  Timer? _poll;
  @override
  String message = '';

  @override
  bool get busy => _busy;
  @override
  bool get awaitingPayment => _reference != null;
  @override
  bool get canRetryConfirmation => _retry;

  @override
  void start() {
    if (!BachsScrapStore.supported || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _account.addListener(_accountChanged);
  }

  @override
  void dispose() {
    _stopPolling();
    if (_started) {
      _account.removeListener(_accountChanged);
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
    super.dispose();
  }

  void _accountChanged() {
    final owner = _account.attached ? _account.session?.accountId : null;
    if (owner == _owner) return;
    _owner = owner;
    // An order belongs to the account that opened it. Switching accounts must
    // never let the next one inherit the previous one's pending purchase.
    _resetOrder();
    message = '';
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final owner = _owner;
    if (owner != null && _reference != null) unawaited(_check(owner));
  }

  void _say(String value, {bool retry = false}) {
    _retry = retry;
    message = value;
    notifyListeners();
  }

  @override
  Future<List<ScrapStoreOffer>> load() async {
    start();
    // A finished outcome is history, not state. Returning to the store must
    // show the account as it is now, so any message from an attempt that is no
    // longer pending is cleared here. Only an outstanding payment survives,
    // because that genuinely is still being waited on.
    _clearFinished();
    if (!BachsScrapStore.supported) {
      throw const AccountError('Scrap checkout is unavailable.');
    }
    final owner = _account.session?.accountId;
    await _account.sync();
    if (owner == null ||
        _account.session?.accountId != owner ||
        !_account.attached ||
        !_account.ready ||
        _account.conflict) {
      throw const AccountError('Sign in and sync your Regun account.');
    }
    final token = await _account.accessToken();
    final Map<String, dynamic> data;
    try {
      data = await _account.api.request(
        '/web-scrap',
        token: token,
        body: {'action': 'catalog'},
      );
    } on AccountError {
      throw const AccountError(
        'Scrap packs are unavailable for this account right now.',
      );
    }
    if (_account.session?.accountId != owner || data['accountId'] != owner) {
      throw const AccountError('Account changed. Open the store again.');
    }
    if (data['salesEnabled'] == false) {
      throw const AccountError('Scrap checkout is paused right now.');
    }
    final packs = data['packs'];
    if (packs is! List) {
      throw const AccountError('Scrap packs are unavailable right now.');
    }
    final offers = <ScrapStoreOffer>[];
    for (final pack in packs) {
      if (pack is! Map) continue;
      final key = pack['pack'];
      final quantity = pack['quantity'];
      final amount = pack['amount'];
      final currency = pack['currency'];
      if (key is! String ||
          quantity is! int ||
          amount is! String ||
          currency is! String) {
        continue;
      }
      offers.add(ScrapStoreOffer(
        id: key,
        amount: quantity,
        label: _price(amount, currency),
        alternate: _alternate(pack['prices'], currency),
      ));
    }
    offers.sort((a, b) => a.amount.compareTo(b.amount));
    if (offers.isEmpty) {
      throw const AccountError('No Scrap packs are available right now.');
    }
    await recover();
    return offers;
  }

  @override
  Future<void> buy(ScrapStoreOffer offer, String owner) async {
    start();
    if (!BachsScrapStore.supported ||
        busy ||
        awaitingPayment ||
        !_account.attached ||
        _account.session?.accountId != owner) {
      return;
    }
    _busy = true;
    _say('Opening checkout…');
    final operation = _uuid();
    // Open the tab before the first `await`, while the tap is still the active
    // user gesture. Opening after the network round-trip gets pop-up blocked
    // and looks like nothing happened.
    var tab = openCheckoutTab();
    var navigated = false;
    try {
      final token = await _account.accessToken();
      if (_account.session?.accountId != owner) return;
      final data = await _account.api.request(
        '/web-scrap',
        token: token,
        body: {'action': 'create', 'pack': offer.id, 'operation': operation},
      );
      final url = data['checkoutUrl'];
      final reference = data['reference'];
      if (url is! String || reference is! String) {
        _say('Checkout is unavailable right now.', retry: true);
        return;
      }
      if (_account.session?.accountId != owner) return;
      if (tab != null) {
        tab.navigate(url);
        navigated = true;
      } else {
        // No window handle (a browser refused to open one). Fall back to the
        // launcher; the game then relies on polling alone to notice the end.
        navigated = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: 'regun_checkout',
        );
      }
      if (!navigated) {
        _say('Checkout could not open. Allow pop-ups and try again.');
        return;
      }
      _reference = reference;
      _tab = tab;
      _closedFor = 0;
      _say('Finish the payment in the new tab, then come back here.');
      _poll = Timer.periodic(_pollEvery, (_) => unawaited(_check(owner)));
    } on AccountError catch (error) {
      _say(error.message, retry: true);
    } catch (_) {
      _say('Checkout is unavailable right now.', retry: true);
    } finally {
      // Nothing was charged, so do not leave an empty tab behind.
      if (!navigated) {
        tab?.close();
        tab = null;
      }
      _busy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> recover() async {
    final owner = _account.session?.accountId;
    if (!BachsScrapStore.supported || owner == null || !_account.attached) return;
    if (_reference == null) return;
    await _check(owner);
  }

  /// Asks the server what became of the outstanding order. A `paid` answer can
  /// only exist because a verified delivery already credited the wallet, so
  /// syncing afterwards is what makes the new balance visible.
  Future<void> _check(String owner) async {
    final reference = _reference;
    if (reference == null || _checking) return;
    if (!_account.attached || _account.session?.accountId != owner) {
      _stopPolling();
      return;
    }
    _checking = true;
    try {
      final token = await _account.accessToken();
      if (_account.session?.accountId != owner) return;
      final data = await _account.api.request(
        '/web-scrap',
        token: token,
        body: {'action': 'status', 'reference': reference},
      );
      if (_account.session?.accountId != owner) return;
      final status = data['status'];
      if (status == 'paid') {
        final quantity = data['quantity'];
        _resetOrder();
        await _account.sync();
        if (_account.session?.accountId == owner) {
          _say(
            _account.conflict || _account.issue.isNotEmpty
                ? 'Scrap delivered. Sync your account to see the balance.'
                : quantity is int
                ? '+${formatNumber(quantity)} Scrap added.'
                : 'Scrap added.',
          );
        }
        return;
      }
      if (status == 'failed' ||
          status == 'expired' ||
          status == 'underpaid' ||
          status == 'refunded' ||
          status == 'cancelled') {
        final cancelled = status == 'cancelled';
        _resetOrder();
        _say(
          cancelled
              ? 'Checkout cancelled. Nothing was charged.'
              : status == 'expired'
              ? 'Checkout expired. Try again.'
              : 'That payment was not completed.',
        );
        return;
      }
      // Still open on the server. If the player has closed the payment tab,
      // give the webhook a short grace window and then stop waiting: the tab
      // closing is the only signal we get when someone walks away, and polling
      // a dead checkout until it expires would look like a stuck game.
      final tab = _tab;
      if (tab != null && tab.closed) {
        _closedFor += 1;
        if (_closedFor >= _closedChecks) {
          _resetOrder();
          _say('Checkout closed. Nothing was charged.');
          return;
        }
        _say('Checking your payment…');
        return;
      }
      // Tab still open, or no handle: keep waiting rather than guessing.
      notifyListeners();
    } catch (_) {
      // Network trouble is not a failed purchase. Keep the order alive so a
      // later poll or a page refresh can still settle it.
      if (_reference != null) _say('Waiting for confirmation…', retry: true);
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Forgets the outstanding order. Every terminal outcome goes through this, so
  /// there is no path that stops polling but keeps a stale reference (which
  /// would make the next open think a payment is still pending).
  void _resetOrder() {
    _reference = null;
    _tab = null;
    _closedFor = 0;
    _retry = false;
    _stopPolling();
  }

  /// Drops any message left by a finished attempt. A payment still in flight is
  /// kept, so reopening the store during a wait does not look like it forgot.
  ///
  /// Deliberately silent: this runs from the dialog's `initState`, and the fresh
  /// build reads [message] immediately, so notifying here would only risk a
  /// build-phase repaint.
  void _clearFinished() {
    if (_reference != null) return;
    _retry = false;
    message = '';
  }

  /// `₦1,350.00` / `$1.00` from the server's decimal string. The server never
  /// sends minor units, so this only groups and prefixes; it never rescales.
  /// The symbol follows the currency, because hardcoding Naira made a USD offer
  /// read as `₦1.00`.
  static String _price(String amount, String currency) {
    final parts = amount.split('.');
    final whole = parts.first;
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i += 1) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
      grouped.write(whole[i]);
    }
    final fraction = parts.length > 1 ? '.${parts[1]}' : '';
    final symbol = switch (currency) {
      'NGN' => '₦',
      'USD' => r'$',
      _ => '$currency ',
    };
    return '$symbol$grouped$fraction';
  }

  /// The first price in a currency other than the base, formatted for the
  /// secondary label. Empty when the pack is sold in one currency only.
  static String _alternate(Object? prices, String base) {
    if (prices is! List) return '';
    for (final entry in prices) {
      if (entry is! Map) continue;
      final currency = entry['currency'];
      final amount = entry['amount'];
      if (currency is! String || amount is! String || currency == base) continue;
      return _price(amount, currency);
    }
    return '';
  }

  /// A v4 UUID. The server turns this into the Bachs `reference`, which is what
  /// makes a repeated tap on the same pack idempotent instead of opening two
  /// checkouts.
  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
