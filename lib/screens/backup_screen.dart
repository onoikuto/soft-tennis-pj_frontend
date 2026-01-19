import 'package:flutter/material.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF4C6B70)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'データのバックアップと移行',
          style: TextStyle(
            color: Color(0xFF131616),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          const Text(
            '大切な試合記録を安全に管理します。\n定期的なバックアップを推奨しています。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6A797C),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
          // エクスポート
          _buildCard(
            icon: Icons.upload_file,
            title: 'データのエクスポート',
            description:
                '現在のすべての試合・統計データをファイルとして保存します。機種変更やデータの共有に利用してください。',
            buttonText: 'バックアップファイルを作成',
            isPrimary: true,
            onTap: () {
              // TODO: エクスポート機能を実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('エクスポート機能は今後実装予定です')),
              );
            },
          ),
          const SizedBox(height: 24),
          // インポート
          _buildCard(
            icon: Icons.settings_backup_restore,
            title: 'データのインポート',
            description:
                '保存済みのファイルからデータを復元します。既存のデータが上書きされる場合がありますのでご注意ください。',
            buttonText: 'ファイルを選択して復元',
            isPrimary: false,
            onTap: () {
              // TODO: インポート機能を実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('インポート機能は今後実装予定です')),
              );
            },
          ),
          const SizedBox(height: 40),
          // 最終同期状態
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Last Sync Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '前回のバックアップ: 2023/10/27 14:30',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF131616),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF4C6B70).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: const Color(0xFF4C6B70),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF131616),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6A797C),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary
                    ? const Color(0xFF4C6B70)
                    : const Color(0xFF4C6B70).withOpacity(0.1),
                foregroundColor: isPrimary ? Colors.white : const Color(0xFF4C6B70),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
