import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/screens/backup_screen.dart';
import 'package:soft_tennis_scoring/screens/subscription_screen.dart';
import 'package:soft_tennis_scoring/screens/privacy_policy_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'マイページ',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // サブスクリプション
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'プラン',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSection(
            [
              _buildMenuItem(
                Icons.workspace_premium,
                'サブスクリプション',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // データ管理
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'データ管理',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSection(
            [
              _buildMenuItem(
                Icons.sync,
                'データのバックアップと移行',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BackupScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // サポート
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'サポート',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSection(
            [
              _buildMenuItem(
                Icons.help_outline,
                'お問い合わせ',
                () async {
                  final url = Uri.parse('https://forms.gle/X7ReoaPkyE65UeBU7');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildMenuItem(
                Icons.privacy_tip_outlined,
                'プライバシーポリシー',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // バージョン情報
          const Center(
            child: Text(
              'Version 1.0.2',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                letterSpacing: 2.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(List<Widget> items, {Widget? footer}) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          ...items,
          if (footer != null) footer,
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: textColor ?? Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor ?? const Color(0xFF333333),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}
