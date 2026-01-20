import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/screens/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // データベースファクトリーの初期化（最初に実行する必要がある）
  if (kIsWeb) {
    // Web版 - sqflite_common_ffi_webは追加セットアップが必要なため、
    // エラーが発生してもアプリは起動（データベース機能は制限される可能性あり）
    try {
      databaseFactory = databaseFactoryFfiWeb;
    } catch (e) {
      debugPrint('Web版データベースファクトリー設定エラー: $e');
    }
  } else {
    // デスクトップ・モバイル版
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // データベースの初期化（エラーが発生してもアプリは起動）
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('データベース初期化エラー: $e');
    debugPrint('注意: Web版ではSQLiteの使用に制限があります。');
    debugPrint('デスクトップ版またはモバイル版での使用を推奨します。');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ソフトテニス採点表',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
