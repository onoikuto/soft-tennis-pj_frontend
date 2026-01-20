import 'package:flutter/material.dart';

/// シンプルなボトムナビゲーションバーコンポーネント
class SimpleBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SimpleBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: const Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'ホーム', 0),
              _buildNavItem(Icons.history, '履歴', 1),
              _buildNavItem(Icons.analytics, '統計', 2),
              _buildNavItem(Icons.person, 'マイページ', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isSelected
                ? const Color(0xFF333333)
                : const Color(0xFF999999),
            fill: isSelected ? 1.0 : 0.0,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color(0xFF333333)
                  : const Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
}
