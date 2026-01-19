import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/screens/official_scoring_screen.dart';

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tournamentController = TextEditingController();
  final _team1Player1Controller = TextEditingController();
  final _team1Player2Controller = TextEditingController();
  final _team1ClubController = TextEditingController();
  final _team2Player1Controller = TextEditingController();
  final _team2Player2Controller = TextEditingController();
  final _team2ClubController = TextEditingController();
  
  int _gameCount = 7;
  String? _firstServe;

  @override
  void dispose() {
    _tournamentController.dispose();
    _team1Player1Controller.dispose();
    _team1Player2Controller.dispose();
    _team1ClubController.dispose();
    _team2Player1Controller.dispose();
    _team2Player2Controller.dispose();
    _team2ClubController.dispose();
    super.dispose();
  }

  Future<void> _saveAndStart() async {
    if (_formKey.currentState!.validate()) {
      final match = Match(
        tournamentName: _tournamentController.text.trim().isEmpty
            ? null
            : _tournamentController.text.trim(),
        team1Player1: _team1Player1Controller.text.trim(),
        team1Player2: _team1Player2Controller.text.trim(),
        team1Club: _team1ClubController.text.trim().isEmpty
            ? null
            : _team1ClubController.text.trim(),
        team2Player1: _team2Player1Controller.text.trim(),
        team2Player2: _team2Player2Controller.text.trim(),
        team2Club: _team2ClubController.text.trim().isEmpty
            ? null
            : _team2ClubController.text.trim(),
        gameCount: _gameCount,
        firstServe: _firstServe,
        createdAt: DateTime.now(),
      );

      final matchId = await DatabaseHelper.instance.insertMatch(match);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OfficialScoringScreen(matchId: matchId),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '試合設定',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.4,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 大会名
            _buildSection(
              'Tournament',
              TextFormField(
                controller: _tournamentController,
                decoration: const InputDecoration(
                  hintText: '大会名を入力',
                  filled: true,
                  fillColor: Color(0xFFF9F9F9),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF333333)),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 40),
            // ペアA
            _buildPairSection(
              'Pair A',
              _team1Player1Controller,
              _team1Player2Controller,
              _team1ClubController,
              true,
            ),
            const SizedBox(height: 40),
            // ペアB
            _buildPairSection(
              'Pair B',
              _team2Player1Controller,
              _team2Player2Controller,
              _team2ClubController,
              false,
            ),
            const SizedBox(height: 40),
            // ゲーム数
            _buildGameCountSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAndStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '保存して戻る',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'キャンセル',
                style: TextStyle(
                  color: Color(0xFF7F7F7F),
                  fontSize: 14,
                  letterSpacing: 2.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.4,
              color: Color(0xFF7F7F7F),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildPairSection(
    String label,
    TextEditingController player1Controller,
    TextEditingController player2Controller,
    TextEditingController clubController,
    bool isFirstServe,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.4,
                color: Color(0xFF7F7F7F),
              ),
            ),
            if (isFirstServe)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '先サーブ',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7F7F7F),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPlayerField('選手 1', player1Controller),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPlayerField('選手 2', player2Controller),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildClubField(clubController),
      ],
    );
  }

  Widget _buildPlayerField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF7F7F7F),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '必須';
            }
            return null;
          },
          decoration: const InputDecoration(
            hintText: '名前',
            filled: true,
            fillColor: Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildClubField(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: const Text(
            '学校・クラブ名',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF7F7F7F),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'ペア共通の所属名を入力',
            filled: true,
            fillColor: Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildGameCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'Game Count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.4,
              color: Color(0xFF7F7F7F),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildGameCountButton(5),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildGameCountButton(7),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildGameCountButton(9),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '7ゲームマッチ、ファイナル 3-3 タイブレーク',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF7F7F7F),
              letterSpacing: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameCountButton(int count) {
    final isSelected = _gameCount == count;
    return GestureDetector(
      onTap: () => setState(() => _gameCount = count),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          '$count ゲーム',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? const Color(0xFF000000)
                : const Color(0xFF7F7F7F),
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}
