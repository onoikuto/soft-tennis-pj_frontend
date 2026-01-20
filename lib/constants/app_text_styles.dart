import 'package:flutter/material.dart';

/// アプリ全体で使用するテキストスタイルの定数
/// 
/// シンプルなタイポグラフィを定義します。
class AppTextStyles {
  AppTextStyles._(); // インスタンス化を防ぐ

  // セクションラベル
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 2.4,
    color: Color(0xFF7F7F7F),
  );

  // アプリバータイトル
  static const TextStyle appBarTitle = TextStyle(
    color: Color(0xFF333333),
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.4,
  );

  // プライマリボタンテキスト
  static const TextStyle primaryButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.4,
  );

  // 大きなプライマリボタンタイトル
  static const TextStyle largePrimaryButtonTitle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.6,
  );

  // 大きなプライマリボタンサブタイトル
  static TextStyle largePrimaryButtonSubtitle = TextStyle(
    color: Colors.white.withOpacity(0.7),
    fontSize: 11,
    letterSpacing: 2.4,
    fontWeight: FontWeight.w500,
  );

  // セカンダリボタンタイトル
  static const TextStyle secondaryButtonTitle = TextStyle(
    color: Color(0xFF333333),
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.8,
  );

  // セカンダリボタンサブタイトル
  static const TextStyle secondaryButtonSubtitle = TextStyle(
    color: Color(0xFF888888),
    fontSize: 10,
    letterSpacing: 2.4,
    fontWeight: FontWeight.w500,
  );
}
