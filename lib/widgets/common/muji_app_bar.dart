import 'package:flutter/material.dart';

/// シンプルなアプリバーコンポーネント
/// 
/// 統一感のあるアプリバーを提供します。
class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool centerTitle;

  const SimpleAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actions,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: onBackPressed != null
          ? IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF333333)),
              onPressed: onBackPressed,
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 2.4,
        ),
      ),
      centerTitle: centerTitle,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
