import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'プライバシーポリシー',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'はじめに',
              'VALVE（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めています。本プライバシーポリシーは、本アプリが収集する情報、その使用方法、およびユーザーの権利について説明します。',
            ),
            _buildSection(
              '収集する情報',
              '本アプリは以下の情報を収集する場合があります：\n\n'
              '• 試合データ（選手名、所属、スコアなど）\n'
              '• アプリの利用状況に関する匿名の統計情報\n\n'
              'これらの情報は、端末内にローカル保存され、ユーザーの同意なく外部サーバーに送信されることはありません。',
            ),
            _buildSection(
              '情報の使用目的',
              '収集した情報は以下の目的で使用されます：\n\n'
              '• アプリの機能提供および改善\n'
              '• 統計データの表示\n'
              '• アプリの不具合修正およびパフォーマンス向上',
            ),
            _buildSection(
              '広告について',
              '本アプリでは、無料プランのユーザーに対して広告を表示する場合があります。広告配信には第三者の広告ネットワーク（Google AdMob等）を使用しており、これらのサービスは独自のプライバシーポリシーに従って情報を収集する場合があります。',
            ),
            _buildSection(
              '情報の共有',
              '本アプリは、以下の場合を除き、ユーザーの個人情報を第三者と共有することはありません：\n\n'
              '• ユーザーの同意がある場合\n'
              '• 法律により開示が求められる場合\n'
              '• アプリの機能提供に必要な業務委託先への提供',
            ),
            _buildSection(
              'セキュリティ',
              '本アプリは、ユーザーの情報を保護するために適切なセキュリティ対策を講じています。ただし、インターネット上での情報送信は完全に安全であることを保証することはできません。',
            ),
            _buildSection(
              '子どものプライバシー',
              '本アプリは、13歳未満の子どもから意図的に個人情報を収集することはありません。13歳未満のお子様が本アプリを使用する場合は、保護者の監督のもとでご利用ください。',
            ),
            _buildSection(
              'プライバシーポリシーの変更',
              '本プライバシーポリシーは、必要に応じて更新される場合があります。重要な変更がある場合は、アプリ内で通知いたします。',
            ),
            _buildSection(
              'お問い合わせ',
              'プライバシーポリシーに関するご質問やご懸念がある場合は、アプリ内の「お問い合わせ」フォームよりご連絡ください。',
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '最終更新日: 2026年1月21日',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
