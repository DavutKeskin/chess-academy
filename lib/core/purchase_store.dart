import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satın alma hataları; metinleri arayüz dile göre üretir.
enum PurchaseError { storeUnavailable, storeUnavailableShort, notStarted, failed }

/// "Tüm Dersler" tek seferlik satın alımı. Google Play / App Store faturalandırması üzerinden;
/// hak cihazda önbelleklenir ve her açılışta mağazadan geri yüklenerek doğrulanır.
class PurchaseStore extends ChangeNotifier {
  PurchaseStore._();
  static final PurchaseStore instance = PurchaseStore._();

  static const productId = 'lessons_full';
  static const _kOwned = 'owns_lessons_full';

  /// Mağaza fiyatı gelmezse gösterilecek metin.
  static const fallbackPrice = '199 TL';

  late SharedPreferences _prefs;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _owned = false;
  bool _available = false;
  bool _busy = false;
  ProductDetails? _product;
  PurchaseError? _error;
  String? _errorDetail;

  bool get hasFullAccess => _owned;
  bool get storeAvailable => _available;
  bool get busy => _busy;
  String get priceText => _product?.price ?? fallbackPrice;
  PurchaseError? get error => _error;
  String? get errorDetail => _errorDetail;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _owned = _prefs.getBool(_kOwned) ?? false;
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        _error = PurchaseError.failed;
        _errorDetail = e.toString();
        notifyListeners();
      });
      final resp = await _iap.queryProductDetails({productId});
      if (resp.productDetails.isNotEmpty) _product = resp.productDetails.first;
      // Cihaz değiştirmiş ya da uygulamayı yeniden kurmuş kullanıcı için sessiz geri yükleme.
      await _iap.restorePurchases();
    } catch (e) {
      _error = PurchaseError.storeUnavailable;
      _errorDetail = e.toString();
    }
    notifyListeners();
  }

  Future<void> buy() async {
    if (_busy) return;
    _error = null;
    if (!_available || _product == null) {
      _error = PurchaseError.storeUnavailable;
      notifyListeners();
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: _product!));
    } catch (e) {
      _error = PurchaseError.notStarted;
      _errorDetail = e.toString();
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!_available) {
      _error = PurchaseError.storeUnavailableShort;
      notifyListeners();
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } finally {
      // Akış cevap vermezse düğme kilitli kalmasın.
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (_busy) {
          _busy = false;
          notifyListeners();
        }
      });
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant();
        case PurchaseStatus.error:
          _error = PurchaseError.failed;
          _errorDetail = p.error?.message;
        case PurchaseStatus.canceled:
          _error = null;
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
    _busy = false;
    notifyListeners();
  }

  Future<void> _grant() async {
    _owned = true;
    await _prefs.setBool(_kOwned, true);
  }

  /// Yalnızca geliştirme derlemesinde: mağaza olmadan kilidi açıp akışı test etmek için.
  Future<void> debugGrant() async {
    if (!kDebugMode) return;
    await _grant();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
