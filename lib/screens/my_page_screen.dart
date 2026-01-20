import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/screens/backup_screen.dart';
import 'package:soft_tennis_scoring/screens/account_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  String _lastName = '';
  String _firstName = '';
  String _team = '';

  @override
  void initState() {
    super.initState();
    _loadAccountSettings();
  }

  Future<void> _loadAccountSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastName = prefs.getString('account_last_name') ?? '';
      _firstName = prefs.getString('account_first_name') ?? '';
      _team = prefs.getString('account_team') ?? '';
    });
  }

  String get _displayName {
    if (_lastName.isEmpty && _firstName.isEmpty) {
      return '佐藤 健太'; // デフォルト値
    }
    if (_firstName.isEmpty) {
      return _lastName;
    }
    return '$_lastName $_firstName';
  }

  String get _displayTeam {
    return _team.isEmpty ? '早稲田ソフトテニスクラブ' : _team; // デフォルト値
  }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _displayTeam,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
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
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountSettingsScreen(),
                    ),
                  );
                  // 設定が保存された場合、プロフィール情報を再読み込み
                  if (result == true) {
                    _loadAccountSettings();
                  }
                },
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
