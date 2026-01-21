import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/screens/match_history_screen.dart';
import 'package:soft_tennis_scoring/screens/match_setup_screen.dart';
import 'package:soft_tennis_scoring/screens/statistics_screen.dart';
import 'package:soft_tennis_scoring/screens/my_page_screen.dart';
import 'package:soft_tennis_scoring/screens/master_management_screen.dart';
import 'package:soft_tennis_scoring/widgets/common/bottom_navigation_bar.dart';
import 'package:soft_tennis_scoring/widgets/common/simple_button.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    _HomeContent(onNavigateToIndex: (index) => setState(() => _currentIndex = index)),
    const MatchHistoryScreen(),
    const StatisticsScreen(),
    const MyPageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return SimpleBottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final ValueChanged<int> onNavigateToIndex;

  const _HomeContent({required this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
            child: Text(
              'Main Menu',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.5,
                color: const Color(0xFF888888).withOpacity(0.7),
              ),
            ),
          ),
          // メインコンテンツ（スクロール可能）
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // 新しく試合を始めるボタン
                  SimpleLargePrimaryButton(
                    title: '新しく試合を始める',
                    subtitle: 'New Match',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MatchSetupScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // その他のボタン
                  SimpleSecondaryButton(
                    title: '過去の試合一覧',
                    subtitle: 'Match History',
                    onTap: () {
                      // ボトムナビゲーションバーの「履歴」タブ（index 1）に切り替え
                      onNavigateToIndex(1);
                    },
                  ),
                  const SizedBox(height: 16),
                  SimpleSecondaryButton(
                    title: '統計データ',
                    subtitle: 'Statistics',
                    onTap: () {
                      // ボトムナビゲーションバーの「統計」タブ（index 2）に切り替え
                      onNavigateToIndex(2);
                    },
                  ),
                  const SizedBox(height: 16),
                  SimpleSecondaryButton(
                    title: '選手・所属チーム管理',
                    subtitle: 'Player & Club Management',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MasterManagementScreen(),
                        ),
                      );
                    },
                  ),
                  // 下部に余白を追加（ボトムナビゲーションバーの高さ分）
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
