import 'package:flutter/foundation.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:regun/services/apple_scrap_store.dart';
import 'package:regun/services/bachs_scrap_store.dart';

/// One purchasable pack, whichever storefront sells it.
class ScrapStoreOffer {
  const ScrapStoreOffer({
    required this.id,
    required this.amount,
    required this.label,
    this.alternate = '',
  });

  /// Provider handle: the App Store product ID, or the web pack key.
  final String id;
  final int amount;

  /// The price exactly as the player must see it. Apple supplies its localized
  /// string from StoreKit; web supplies the server's approved Naira amount.
  final String label;

  /// A second currency the same pack can be bought in, already formatted, or
  /// empty. Shown so an international player knows the price will not surprise
  /// them at the hosted page, which settles in their own currency.
  final String alternate;
}

/// The surface the store dialog needs. Deliberately small: adding a provider
/// must not require teaching the UI about that provider.
abstract class ScrapStoreBase implements Listenable {
  bool get busy;
  bool get awaitingPayment;
  bool get canRetryConfirmation;
  String get message;

  void start();
  Future<List<ScrapStoreOffer>> load();
  Future<void> buy(ScrapStoreOffer offer, String owner);
  Future<void> recover();
}

/// Presents the existing App Store flow through the shared interface.
///
/// This is a pass-through on purpose: the Apple implementation is not rewritten,
/// so iOS and macOS behave exactly as they did before web existed. It only
/// remembers the loaded `ProductDetails` so `buy` can hand the same object back.
class AppleScrapStoreAdapter extends ChangeNotifier implements ScrapStoreBase {
  AppleScrapStoreAdapter(this._store) {
    _store.addListener(notifyListeners);
  }

  final AppleScrapStore _store;
  final _products = <String, ProductDetails>{};

  @override
  bool get busy => _store.busy;
  @override
  bool get awaitingPayment => _store.awaitingPayment;
  @override
  bool get canRetryConfirmation => _store.canRetryConfirmation;
  @override
  String get message => _store.message;

  @override
  void start() => _store.start();

  @override
  Future<List<ScrapStoreOffer>> load() async {
    final offers = await _store.load();
    _products
      ..clear()
      ..addEntries(offers.map((offer) => MapEntry(offer.product.id, offer.product)));
    return [
      for (final offer in offers)
        ScrapStoreOffer(
          id: offer.product.id,
          amount: offer.amount,
          label: offer.product.price,
        ),
    ];
  }

  @override
  Future<void> buy(ScrapStoreOffer offer, String owner) async {
    final product = _products[offer.id];
    if (product == null) return;
    await _store.buy(product, owner);
  }

  @override
  Future<void> recover() => _store.recover();

  @override
  void dispose() {
    _store.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Chooses the storefront for the current build.
///
/// Apple owns iOS and macOS. Web is Bachs, and only when the build was compiled
/// with `REGUN_WEB_SCRAP`, so an unflagged web build has no store at all — which
/// is the shipping default. The two are mutually exclusive by construction:
/// neither platform can ever see the other's checkout.
abstract final class ScrapStore {
  static final AppleScrapStoreAdapter _apple = AppleScrapStoreAdapter(
    AppleScrapStore.shared,
  );

  static ScrapStoreBase get shared =>
      BachsScrapStore.supported ? BachsScrapStore.shared : _apple;

  static bool get supported =>
      BachsScrapStore.supported || AppleScrapStore.supported;

  static void start() => shared.start();
}
