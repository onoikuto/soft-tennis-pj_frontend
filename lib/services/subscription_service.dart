import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

import 'package:soft_tennis_scoring/config/ai_config.dart';

/// 購入処理が失敗した理由
///
/// UI側でユーザー向けの文言に変換するために使用します。
/// （開発者向けの技術的な詳細はログにのみ出力し、ユーザーには見せません）
enum PurchaseFailureReason {
  /// 失敗していない
  none,

  /// ストアに接続できない（ネットワーク不通、App Storeの一時的な不調など）
  storeUnavailable,

  /// 商品情報が取得できない
  /// （App Store Connect側でProduct IDの紐付け・契約状態に問題がある可能性が高い）
  productNotFound,

  /// 購入フローの開始自体に失敗した
  purchaseFlowFailed,
}

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

  /// 直近の購入処理で発生した失敗理由（UI側の文言出し分け用）
  static PurchaseFailureReason lastFailureReason = PurchaseFailureReason.none;
  
  /// サブスクリプション状態を取得
  static Future<bool> isSubscribed() async {
    // 動作確認用の抜け道。シミュレータでは課金できないため、
    // `--dart-define=AI_FORCE_PREMIUM=true` でプレミアム扱いにできます。
    // **デバッグビルドでしか効きません。** リリースビルドに紛れ込んでも
    // kDebugMode が false なので課金の迂回にはなりません。
    if (kDebugMode && AiConfig.forcePremium) return true;

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
  ///
  /// 失敗した場合、[lastFailureReason] に理由が設定されます。
  /// UI側はこれを見てユーザー向けの文言を出し分けてください
  /// （開発者向けの技術的な詳細は debugPrint のログにのみ出力します）。
  Future<bool> purchaseSubscription() async {
    lastFailureReason = PurchaseFailureReason.none;

    // macOS/Webではテスト用に手動で有効化
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      await _saveSubscriptionStatus(true);
      return true;
    }

    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('In-app purchase not available');
        lastFailureReason = PurchaseFailureReason.storeUnavailable;
        return false;
      }

      final ProductDetails? product = await getSubscriptionProduct();
      if (product == null) {
        // 主な原因: App Store Connect側でProduct IDの紐付け・
        // Paid Applications Agreementの締結状況に問題がある可能性が高い
        debugPrint('Product not found - check App Store Connect configuration');
        debugPrint('Expected product ID: $_subscriptionProductId');
        lastFailureReason = PurchaseFailureReason.productNotFound;
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

      if (!success) {
        lastFailureReason = PurchaseFailureReason.purchaseFlowFailed;
      }

      // 購入処理が開始された（支払いシートが表示される）
      // 実際の購入完了はpurchaseStreamで通知される
      return success;
    } catch (e) {
      debugPrint('Error purchasing subscription: $e');
      lastFailureReason = PurchaseFailureReason.purchaseFlowFailed;
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

  /// アプリ起動時にサブスクリプション状態を購入履歴と同期する
  ///
  /// 購入更新のリスナーを登録した上で [restorePurchases] を呼び出し、
  /// 端末に保存された状態（[isSubscribed]）と実際の購入履歴のずれを解消します。
  /// 主に機種変更・再インストール後の同期漏れ、
  /// アプリがバックグラウンドの間に完了した購入（Ask to Buy等）の取りこぼしに対応します。
  ///
  /// 注意: このパッケージは購入履歴（過去に購入したことがある事実）は復元できますが、
  /// 「サブスクリプションが現在も有効か（解約・期限切れでないか）」までは判定できません。
  /// 解約直後にプレミアム機能を即座に無効化するには、サーバーサイドでのレシート検証
  /// （App Store Server Notifications 等）が別途必要です。
  static Future<void> syncOnAppStart() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }

    final service = SubscriptionService();
    service.listenToPurchaseUpdates((_) {});
    await service.restorePurchases();
  }
}
