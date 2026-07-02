import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

/// サブスクリプション管理サービス
/// 
/// iOS/Androidでは実際のin_app_purchaseを使用
/// macOS/Webでは使用しない（ビルドエラー回避）
class SubscriptionService {
  static const String _subscriptionKey = 'is_subscribed';
  
  // App Store Connectで設定したサブスクリプションプロダクトID
  static const String _subscriptionProductId = 'premium_subscription';
  
  static final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  /// サブスクリプション状態を取得
  static Future<bool> isSubscribed() async {
    // SharedPreferencesから状態を取得
    // 購入履歴の確認はrestorePurchases()とpurchaseStreamで行う
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscriptionKey) ?? false;
  }
  
  /// サブスクリプション状態を保存
  static Future<void> _saveSubscriptionStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscriptionKey, value);
  }
  
  /// サブスクリプション商品を取得
  Future<ProductDetails?> getSubscriptionProduct() async {
    // macOS/Webではnullを返す
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return null;
    }
    
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('In-app purchase is not available');
        return null;
      }
      
      debugPrint('Querying product with ID: $_subscriptionProductId');
      final Set<String> productIds = {_subscriptionProductId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.error != null) {
        debugPrint('Error querying products: ${response.error}');
        debugPrint('Error code: ${response.error?.code}');
        debugPrint('Error message: ${response.error?.message}');
        debugPrint('Error details: ${response.error?.details}');
        return null;
      }
      
      if (response.productDetails.isEmpty) {
        debugPrint('No products found for ID: $_subscriptionProductId');
        debugPrint('Not found IDs: ${response.notFoundIDs}');
        return null;
      }
      
      debugPrint('Product found: ${response.productDetails.first.id} - ${response.productDetails.first.title}');
      return response.productDetails.first;
    } catch (e) {
      debugPrint('Error getting subscription product: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }
  
  /// サブスクリプションを購入
  Future<bool> purchaseSubscription() async {
    // macOS/Webではテスト用に手動で有効化
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      await _saveSubscriptionStatus(true);
      return true;
    }
    
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('In-app purchase not available');
        return false;
      }
      
      final ProductDetails? product = await getSubscriptionProduct();
      if (product == null) {
        debugPrint('Product not found - check App Store Connect configuration');
        debugPrint('Expected product ID: $_subscriptionProductId');
        return false;
      }
      
      // 購入処理を開始（これでAppleの支払いシートが表示される）
      // サブスクリプションの場合はbuyNonConsumableを使用
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );
      
      // サブスクリプションの購入を開始
      // buyNonConsumableは自動更新可能なサブスクリプションにも使用可能
      final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      // 購入処理が開始された（支払いシートが表示される）
      // 実際の購入完了はpurchaseStreamで通知される
      return success;
    } catch (e) {
      debugPrint('Error purchasing subscription: $e');
      return false;
    }
  }
  
  /// 購入履歴を確認してサブスクリプション状態を更新
  Future<void> restorePurchases() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }
    
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        return;
      }
      
      // 購入履歴を復元
      // 復元された購入情報はpurchaseStreamを通じて通知される
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }
  
  /// 購入更新のリスナーを設定
  void listenToPurchaseUpdates(Function(PurchaseDetails) onPurchaseUpdate) {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }
    
    // 購入更新のストリームをリッスン
    _subscription?.cancel();
    _subscription = _inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
          if (purchaseDetails.productID == _subscriptionProductId) {
            // 購入が完了した場合
            if (purchaseDetails.status == PurchaseStatus.purchased ||
                purchaseDetails.status == PurchaseStatus.restored) {
              _saveSubscriptionStatus(true);
              onPurchaseUpdate(purchaseDetails);
              
              // 購入を完了としてマーク
              if (purchaseDetails.pendingCompletePurchase) {
                _inAppPurchase.completePurchase(purchaseDetails);
              }
            } else if (purchaseDetails.status == PurchaseStatus.error) {
              debugPrint('Purchase error: ${purchaseDetails.error}');
              onPurchaseUpdate(purchaseDetails);
            } else if (purchaseDetails.status == PurchaseStatus.pending) {
              debugPrint('Purchase pending');
              onPurchaseUpdate(purchaseDetails);
            }
          }
        }
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint('Purchase stream error: $error');
      },
    );
  }
  
  /// リスナーをクリーンアップ
  void dispose() {
    _subscription?.cancel();
  }
}
