import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// サブスクリプション管理サービス
/// 
/// macOS/Webではin_app_purchaseを使用しない（ビルドエラー回避）
/// モバイル版（iOS/Android）では、実際の実装時にin_app_purchaseを追加
class SubscriptionService {
  static const String _subscriptionKey = 'is_subscribed';
  static const String _subscriptionProductId = 'premium_subscription'; // 実際のプロダクトIDに置き換える
  
  /// サブスクリプション状態を取得
  static Future<bool> isSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscriptionKey) ?? false;
  }
  
  /// サブスクリプション状態を設定
  static Future<void> setSubscribed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscriptionKey, value);
  }
  
  /// サブスクリプション商品を取得
  /// 
  /// macOS/Webではnullを返す（テスト用に手動で有効化可能）
  /// モバイル版では、実際の実装時にin_app_purchaseを使用
  Future<dynamic> getSubscriptionProduct() async {
    // macOS/Webではサブスクリプション機能を無効化
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return null;
    }
    
    // モバイル版での実装（実際の実装時にin_app_purchaseを使用）
    // 現時点ではnullを返す
    return null;
  }
  
  /// サブスクリプションを購入
  /// 
  /// macOS/Webではテスト用に手動で有効化できるようにする
  /// モバイル版では、実際の実装時にin_app_purchaseを使用
  Future<bool> purchaseSubscription() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      // macOS/Webではテスト用に手動で有効化できるようにする
      await setSubscribed(true);
      return true;
    }
    
    // モバイル版での実装（実際の実装時にin_app_purchaseを使用）
    // 現時点ではテスト用に手動で有効化
    await setSubscribed(true);
    return true;
  }
  
  /// 購入履歴を確認してサブスクリプション状態を更新
  Future<void> restorePurchases() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }
    
    // モバイル版での実装（実際の実装時にin_app_purchaseを使用）
  }
  
  /// 購入更新のリスナーを設定
  void listenToPurchaseUpdates(Function(dynamic) onPurchaseUpdate) {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }
    
    // モバイル版での実装（実際の実装時にin_app_purchaseを使用）
  }
}
