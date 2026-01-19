import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/screens/backup_screen.dart';

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
          // プロフィールセクション
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 20),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '佐藤 健太',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '早稲田ソフトテニスクラブ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // アカウント設定
          _buildSection(
            [
              _buildMenuItem(
                Icons.manage_accounts,
                'アカウント設定',
                () {},
              ),
              _buildMenuItem(
                Icons.mail,
                'お問い合わせ',
                () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          // データのバックアップと移行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'データのバックアップと移行',
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
                Icons.upload,
                'データのエクスポート (書き出し)',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BackupScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.download,
                'データのインポート (読み込み)',
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
            footer: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: const Text(
                'CSVや専用形式で試合データを保存・復元できます',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // ログアウト
          _buildSection(
            [
              _buildMenuItem(
                Icons.logout,
                'ログアウト',
                () {},
                textColor: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 48),
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
