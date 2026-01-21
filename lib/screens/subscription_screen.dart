import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isSubscribed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSubscribed = prefs.getBool('is_subscribed') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final newStatus = !_isSubscribed;
    await prefs.setBool('is_subscribed', newStatus);
    setState(() {
      _isSubscribed = newStatus;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'プレミアムプランに登録しました' : 'プレミアムプランを解約しました'),
          backgroundColor: newStatus ? const Color(0xFF4CAF50) : Colors.grey[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'サブスクリプション',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 現在のステータス
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isSubscribed
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE0E0E0),
                          width: _isSubscribed ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _isSubscribed
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isSubscribed ? Icons.workspace_premium : Icons.star_border,
                              size: 32,
                              color: _isSubscribed
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF888888),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isSubscribed ? 'プレミアムプラン' : 'フリープラン',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _isSubscribed
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSubscribed
                                ? 'すべての機能をご利用いただけます'
                                : '一部機能が制限されています',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // プレミアム機能一覧
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'プレミアム機能',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem(
                            Icons.block,
                            '広告非表示',
                            '煩わしい広告を完全に非表示にします',
                            _isSubscribed,
                          ),
                          _buildFeatureItem(
                            Icons.analytics,
                            '詳細統計',
                            'ファイナルゲーム勝率など高度な統計データを表示',
                            _isSubscribed,
                          ),
                          _buildFeatureItem(
                            Icons.groups,
                            'クラブ別統計',
                            '所属クラブごとの統計データを確認',
                            _isSubscribed,
                          ),
                          _buildFeatureItem(
                            Icons.person,
                            '選手別統計',
                            '選手個人の詳細な統計データを確認',
                            _isSubscribed,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 価格情報
                    if (!_isSubscribed)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6B4EE6), Color(0xFF9B6DFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'プレミアムプラン',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '¥500',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    ' / 月',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '年額プラン ¥5,000 (¥417/月相当)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    // アクションボタン
                    ElevatedButton(
                      onPressed: _toggleSubscription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSubscribed
                            ? Colors.grey[200]
                            : const Color(0xFF6B4EE6),
                        foregroundColor: _isSubscribed
                            ? Colors.grey[700]
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isSubscribed ? 'プランを解約する' : 'プレミアムに登録する',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_isSubscribed) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          // 購入の復元処理
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('購入情報を確認中...'),
                            ),
                          );
                        },
                        child: Text(
                          '購入を復元する',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // 注意事項
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '注意事項',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• サブスクリプションは自動更新されます\n'
                            '• 解約は次の更新日の24時間前までに行ってください\n'
                            '• 購入後のキャンセル・返金はできません',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String description,
    bool isEnabled,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEnabled
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isEnabled
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF888888),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    if (isEnabled) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Color(0xFF4CAF50),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
