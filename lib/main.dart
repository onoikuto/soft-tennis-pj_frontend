import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/screens/main_menu_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  // Flutterのエラーハンドリングを設定（ウィジェットツリー内のエラーもキャッチ）
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutterエラー: ${details.exception}');
    debugPrint('スタックトレース: ${details.stack}');
  };

  // 全体をエラーハンドリングで囲む（予期しないエラーでもクラッシュを防ぐ）
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    debugPrint('🚀 アプリ初期化開始');
    
    // データベースファクトリーの初期化（プラットフォームに応じて処理を分ける）
    if (kIsWeb) {
      // Web版専用の設定
      try {
        databaseFactory = databaseFactoryFfiWeb;
        debugPrint('✅ Web版データベースファクトリー設定成功');
      } catch (e, stackTrace) {
        debugPrint('❌ Web版データベースファクトリー設定エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
      }
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
               defaultTargetPlatform == TargetPlatform.linux ||
               defaultTargetPlatform == TargetPlatform.macOS) {
      // デスクトップ版専用の設定（Windows、Linux、macOS）
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        debugPrint('✅ デスクトップ版データベースファクトリー初期化成功');
      } catch (e, stackTrace) {
        debugPrint('❌ デスクトップ版データベースファクトリー初期化エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
      }
    } else {
      debugPrint('✅ Android/iOS: 標準のsqfliteを使用（追加の初期化は不要）');
    }
    
    // データベースの初期化（エラーが発生してもアプリは起動）
    try {
      await DatabaseHelper.instance.database;
      debugPrint('✅ データベース初期化成功');
    } catch (e, stackTrace) {
      debugPrint('❌ データベース初期化エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
    }
    
    // Google Mobile Adsの初期化（モバイル版のみ、macOSは除外）
    if (!kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.android || 
         defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        debugPrint('📱 Google Mobile Ads初期化開始...');
        await MobileAds.instance.initialize();
        debugPrint('✅ Google Mobile Ads初期化成功');
      } catch (e, stackTrace) {
        debugPrint('❌ Google Mobile Ads初期化エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
      }
    }
    
    debugPrint('🚀 アプリを起動します...');
    runApp(const MyApp());
  }, (error, stackTrace) {
    // 予期しないエラーが発生した場合の処理
    debugPrint('❌❌❌ 予期しないエラーが発生しました ❌❌❌');
    debugPrint('エラー: $error');
    debugPrint('スタックトレース: $stackTrace');
    // エラーが発生してもアプリを起動
    runApp(const MyApp());
  });
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
      home: const SafeMainMenuScreen(),
      debugShowCheckedModeBanner: false,
      // エラーウィジェットをカスタマイズ（クラッシュを防ぐ）
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'エラーが発生しました',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      child: Text(
                        '${details.exception}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // アプリを再起動
                      runApp(const MyApp());
                    },
                    child: const Text('再起動'),
                  ),
                ],
              ),
            ),
          );
        };
        return child ?? const SizedBox();
      },
    );
  }
}

// MainMenuScreenを安全にラップするウィジェット
class SafeMainMenuScreen extends StatefulWidget {
  const SafeMainMenuScreen({super.key});

  @override
  State<SafeMainMenuScreen> createState() => _SafeMainMenuScreenState();
}

class _SafeMainMenuScreenState extends State<SafeMainMenuScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('✅ SafeMainMenuScreen initState完了');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('✅ SafeMainMenuScreen build開始');
    try {
      return const MainMenuScreen();
    } catch (e, stackTrace) {
      debugPrint('❌ MainMenuScreenエラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'MainMenuScreenでエラーが発生しました',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // アプリを再起動
                  runApp(const MyApp());
                },
                child: const Text('再起動'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
