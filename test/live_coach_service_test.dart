import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soft_tennis_scoring/services/live_coach_service.dart';
import 'package:soft_tennis_scoring/services/pair_report.dart';

PairReport _report() => const PairReport(
      players: [
        PlayerReport(name: '佐藤', bad: 'バックハンドで3失点。'),
      ],
      summary: 'いま一番失点しているのは佐藤のバックハンド（5本）。',
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('LiveCoachService.report', () {
    test('ルールの文言がそのまま返る（端末内LLMなしでも動く）', () async {
      final message = await LiveCoachService.report(_report());

      expect(message, isNotNull);
      expect(message!.phrasedByAi, isFalse);
      expect(message.report.summary, contains('佐藤のバックハンド'));
    });

    test('課金していなくても出す（課金対象は統計画面だけ）', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': false});

      expect(await LiveCoachService.report(_report()), isNotNull);
    });

    test('材料がなければ出さない', () async {
      const empty = PairReport(players: []);
      expect(await LiveCoachService.report(empty), isNull);
    });
  });

  group('LiveCoachService.sanitize', () {
    test('前置きや箇条書きを落とす', () {
      expect(
        LiveCoachService.sanitize('- 佐藤のバックハンドでの失点が5本。'),
        '佐藤のバックハンドでの失点が5本。',
      );
    });

    test('長すぎる出力は捨てる（元の文に戻すため）', () {
      expect(LiveCoachService.sanitize('あ' * 200), isNull);
    });

    test('日本語が含まれない出力は捨てる', () {
      expect(LiveCoachService.sanitize('Sure! Here is the summary:'), isNull);
    });

    test('空やnullはnullのまま', () {
      expect(LiveCoachService.sanitize(null), isNull);
      expect(LiveCoachService.sanitize('   \n  '), isNull);
    });
  });

  group('LiveCoachService.buildPrompt', () {
    test('ルールが選んだ一言と、書かせない指示を渡す', () {
      final prompt = LiveCoachService.buildPrompt('佐藤のバックハンドで5失点。');

      expect(prompt, contains('佐藤のバックハンドで5失点。'));
      expect(prompt, contains('対策や励ましは書かないでください'));
    });
  });
}
