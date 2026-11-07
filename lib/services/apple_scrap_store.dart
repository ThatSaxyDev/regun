import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/utils/format_number.dart';

class AppleScrapStore extends ChangeNotifier with WidgetsBindingObserver {
  AppleScrapStore._();
  static final shared = AppleScrapStore._();

  static bool get supported =>
      const bool.fromEnvironment('REGUN_APPLE_SCRAP') &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  final _account = AccountController.shared;
  InAppPurchasePlatform get _store => InAppPurchasePlatform.instance;
  final _claiming = <String>{};
  final _packs = <String, int>{};
  String? _owner;
  bool _started = false;
  bool _checkout = false, _checkoutInterrupted = false;
  String? _pendingProduct;
  String message = '';
  bool canRetryConfirmation = false;
  bool get busy => _checkout || _claiming.isNotEmpty;
  bool get awaitingPayment => _pendingProduct != null;

  void start() {
    if (!supported || _started) return;
    InAppPurchaseStoreKitPlatform.registerPlatform();
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _account.addListener(_accountChanged);
    _store.purchaseStream.listen(
      (updates) => unawaited(_updates(updates)),
      onError: (Object error) {
        _checkout = false;
        _message('Checkout is unavailable.');
      },
    );
  }

  void _accountChanged() {
    final owner = _account.attached ? _account.session?.accountId : null;
    if (owner == _owner) return;
    _owner = owner;
    _packs.clear();
    _checkoutInterrupted = false;
    _pendingProduct = null;
    _message('');
    if (owner != null) unawaited(recover());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(recover());
  }

  void _message(String value, {bool retry = false}) {
    canRetryConfirmation = retry;
    message = value;
    notifyListeners();
  }

  Future<List<({int amount, ProductDetails product})>> load() async {
    start();
    if (!supported || !await _store.isAvailable()) {
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
        '/apple-scrap',
        token: token,
        body: {'action': 'catalog'},
      );
    } on AccountError {
      throw const AccountError(
        'Scrap packs are unavailable for this account right now.',
      );
    }
    if (_account.session?.accountId != owner ||
        data['accountId'] != owner ||
        (data['environment'] != 'Sandbox' &&
            data['environment'] != 'Production')) {
      throw const AccountError('Scrap checkout is unavailable.');
    }
    final packs = Map<String, int>.from(data['packs'] as Map);
    final response = await _store.queryProductDetails(packs.keys.toSet());
    if (_account.session?.accountId != owner) {
      throw const AccountError('Account changed. Open the store again.');
    }
    _packs
      ..clear()
      ..addAll(packs);
    final offers = [
      for (final product in response.productDetails)
        if (packs.containsKey(product.id))
          (amount: packs[product.id]!, product: product),
    ]..sort((a, b) => a.amount.compareTo(b.amount));
    if (offers.isEmpty) {
      throw const AccountError('No Scrap packs are available right now.');
    }
    await recover();
    return offers;
  }

  Future<void> buy(ProductDetails product, String owner) async {
    if (!supported ||
        busy ||
        awaitingPayment ||
        !_account.attached ||
        _account.session?.accountId != owner ||
        !_packs.containsKey(product.id)) {
      return;
    }
    _checkout = true;
    _pendingProduct = product.id;
    _message('Opening checkout…');
    try {
      if (!await _store.buyConsumable(
        purchaseParam: Sk2PurchaseParam(
          productDetails: product,
          applicationUserName: owner,
        ),
      )) {
        _pendingProduct = null;
        _message('Checkout could not open.');
      }
    } catch (_) {
      if (_account.session?.accountId == owner) {
        _checkoutInterrupted = true;
        _message('Checkout was interrupted.');
        await recover();
      }
    } finally {
      _checkout = false;
      notifyListeners();
    }
  }

  Future<void> _updates(List<PurchaseDetails> updates) async {
    for (final update in updates) {
      _checkoutInterrupted = false;
      switch (update.status) {
        case PurchaseStatus.pending:
          _pendingProduct = update.productID;
          _message('Payment pending. Scrap will be added when it’s confirmed.');
        case PurchaseStatus.canceled:
          _pendingProduct = null;
          _message('Purchase canceled.');
        case PurchaseStatus.error:
          _pendingProduct = null;
          _message('Purchase could not be completed.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await recover();
      }
    }
  }

  Future<void> recover() async {
    final owner = _account.session?.accountId;
    if (!supported || owner == null || !_account.attached) return;
    try {
      final unfinished = await SK2Transaction.unfinishedTransactions();
      if (_account.session?.accountId != owner) return;
      for (final tx in unfinished) {
        final signed = tx.receiptData;
        final id = int.tryParse(tx.id);
        if (tx.appAccountToken?.toLowerCase() != owner.toLowerCase() ||
            signed == null ||
            id == null ||
            !tx.productId.startsWith('dev.kiishi.regun.scrap.')) {
          continue;
        }
        _checkoutInterrupted = false;
        if (!_claiming.add(tx.id)) continue;
        try {
          _pendingProduct = tx.productId;
          _message('Confirming your Scrap…');
          if (_account.session?.accountId != owner) break;
          final token = await _account.accessToken();
          if (_account.session?.accountId != owner) break;
          final receipt = await _account.api.request(
            '/apple-scrap',
            token: token,
            body: {'action': 'claim', 'signedTransaction': signed},
          );
          if (receipt['accountId'] != owner ||
              receipt['transaction'] != tx.id ||
              receipt['product'] != tx.productId) {
            throw const AccountError('Invalid purchase confirmation.');
          }
          final amount = receipt['amount'];
          if (amount is! int || amount <= 0) {
            throw const AccountError('Invalid purchase confirmation.');
          }
          await SK2Transaction.finish(id);
          if (_account.session?.accountId == owner) {
            _pendingProduct = null;
            await _account.sync();
            if (_account.session?.accountId == owner) {
              _message(
                _account.conflict || _account.issue.isNotEmpty
                    ? 'Scrap delivered. Sync your account to see the balance.'
                    : '+${formatNumber(amount)} Scrap added.',
              );
            }
          }
        } finally {
          _claiming.remove(tx.id);
          notifyListeners();
        }
      }
      if (_account.session?.accountId == owner && _checkoutInterrupted) {
        _checkoutInterrupted = false;
        _pendingProduct = null;
        _message('Checkout was interrupted. Try again.');
      }
    } catch (_) {
      if (_account.session?.accountId == owner) {
        _message('Could not confirm your purchase yet.', retry: true);
      }
    }
  }
}
