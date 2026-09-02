import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/services/statistics_calculator.dart';

/// テスト用の試合を作る
Match buildMatch({
  String team1Player1 = '山崎',
  String team1Player2 = '佐藤',
  String team1Club = 'A高校',
  String team2Player1 = '田中',
  String team2Player2 = '鈴木',
  String team2Club = 'B高校',
}) {
  return Match(
    id: 1,
    tournamentName: '練習試合',
    team1Player1: team1Player1,
    team1Player2: team1Player2,
    team1Club: team1Club,
    team2Player1: team2Player1,
    team2Player2: team2Player2,
    team2Club: team2Club,
    createdAt: DateTime(2026, 9, 1),
    completedAt: DateTime(2026, 9, 1),
    winner: 'team1',
  );
}

void main() {
  group('StatsSubject - ペア単位', () {
    test('所属付きの表示名でも、ペア名でチームを判定できる', () {
      final subject = StatsSubject(0, '山崎・佐藤 (A高校)');
      final match = buildMatch();

      expect(subject.covers(match), isTrue);
      expect(subject.isTeam1(match), isTrue);
      expect(subject.opponentLabel(match), '田中・鈴木 (B高校)');
    });

    test('相手側のペアを選んだときはチーム2として扱う', () {
      final subject = StatsSubject(0, '田中・鈴木 (B高校)');
      final match = buildMatch();

      expect(subject.isTeam1(match), isFalse);
      expect(subject.opponentLabel(match), '山崎・佐藤 (A高校)');
    });

    test('関係のないペアの試合は集計対象に含めない', () {
      final subject = StatsSubject(0, '高橋・伊藤');
      expect(subject.covers(buildMatch()), isFalse);
    });
  });

  group('StatsSubject - 学校・クラブ単位', () {
    test('相手も所属名で集計する', () {
      final subject = StatsSubject(1, 'A高校');
      final match = buildMatch();

      expect(subject.covers(match), isTrue);
      expect(subject.isTeam1(match), isTrue);
      expect(subject.opponentLabel(match), 'B高校');
    });
  });

  group('StatsSubject - 個人単位', () {
    test('同姓の選手を所属で区別する', () {
      final subject = StatsSubject(2, '山崎 (A高校)');

      // 同じ「山崎」でも所属が違えば別人として扱う
      final otherClub = buildMatch(team1Club: 'C高校');
      expect(subject.covers(otherClub), isFalse);

      expect(subject.covers(buildMatch()), isTrue);
      expect(subject.isTeam1(buildMatch()), isTrue);
    });

    test('「所属なし」の選手は所属が空の試合だけを対象にする', () {
      final subject = StatsSubject(2, '山崎 (所属なし)');

      expect(subject.covers(buildMatch(team1Club: '')), isTrue);
      expect(subject.covers(buildMatch(team1Club: 'A高校')), isFalse);
    });

    test('ペアの2人目でも本人として判定される', () {
      final subject = StatsSubject(2, '佐藤 (A高校)');
      final match = buildMatch();

      expect(subject.covers(match), isTrue);
      expect(subject.isTeam1(match), isTrue);
    });

    test('相手チームにいる選手はチーム2として扱う', () {
      final subject = StatsSubject(2, '田中 (B高校)');
      final match = buildMatch();

      expect(subject.covers(match), isTrue);
      expect(subject.isTeam1(match), isFalse);
      expect(subject.opponentLabel(match), '山崎・佐藤 (A高校)');
    });

    test('旧形式（所属の括弧なし）の表示名も読める', () {
      final subject = StatsSubject(2, '山崎');
      expect(subject.playerName, '山崎');
      expect(subject.playerClub, isNull);
      expect(subject.covers(buildMatch(team1Club: '')), isTrue);
    });
  });
}
