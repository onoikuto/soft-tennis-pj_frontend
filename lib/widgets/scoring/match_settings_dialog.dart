import 'package:flutter/material.dart';

/// 試合設定ダイアログ（独立したStatefulWidget）
class MatchSettingsDialog extends StatefulWidget {
  final String initialTournamentName;
  final String initialTeam1Player1;
  final String initialTeam1Player2;
  final String initialTeam1Club;
  final String initialTeam2Player1;
  final String initialTeam2Player2;
  final String initialTeam2Club;
  final String? initialFirstServe;

  const MatchSettingsDialog({
    super.key,
    required this.initialTournamentName,
    required this.initialTeam1Player1,
    required this.initialTeam1Player2,
    required this.initialTeam1Club,
    required this.initialTeam2Player1,
    required this.initialTeam2Player2,
    required this.initialTeam2Club,
    this.initialFirstServe,
  });

  @override
  State<MatchSettingsDialog> createState() => _MatchSettingsDialogState();
}

class _MatchSettingsDialogState extends State<MatchSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _firstServe;

  late TextEditingController _tournamentNameController;
  late TextEditingController _team1Player1Controller;
  late TextEditingController _team1Player2Controller;
  late TextEditingController _team1ClubController;
  late TextEditingController _team2Player1Controller;
  late TextEditingController _team2Player2Controller;
  late TextEditingController _team2ClubController;

  @override
  void initState() {
    super.initState();
    _firstServe = widget.initialFirstServe;
    _tournamentNameController = TextEditingController(text: widget.initialTournamentName);
    _team1Player1Controller = TextEditingController(text: widget.initialTeam1Player1);
    _team1Player2Controller = TextEditingController(text: widget.initialTeam1Player2);
    _team1ClubController = TextEditingController(text: widget.initialTeam1Club);
    _team2Player1Controller = TextEditingController(text: widget.initialTeam2Player1);
    _team2Player2Controller = TextEditingController(text: widget.initialTeam2Player2);
    _team2ClubController = TextEditingController(text: widget.initialTeam2Club);
  }

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _team1Player1Controller.dispose();
    _team1Player2Controller.dispose();
    _team1ClubController.dispose();
    _team2Player1Controller.dispose();
    _team2Player2Controller.dispose();
    _team2ClubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        '試合設定',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // イベント名
              const Text(
                '大会・イベント名',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF7F7F7F),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tournamentNameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '大会・イベント名を入力してください';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: '大会名など',
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              // ペアA
              _buildPairSection(
                'ペアA',
                _team1ClubController,
                _team1Player1Controller,
                _team1Player2Controller,
                isFirstServe: _firstServe == 'team1',
              ),
              const SizedBox(height: 16),
              // ペアB
              _buildPairSection(
                'ペアB',
                _team2ClubController,
                _team2Player1Controller,
                _team2Player2Controller,
                isFirstServe: _firstServe == 'team2',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'キャンセル',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF333333),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      // バリデーション：同じペア内で同じ選手チェック
      final team1Player1 = _team1Player1Controller.text.trim();
      final team1Player2 = _team1Player2Controller.text.trim();
      final team2Player1 = _team2Player1Controller.text.trim();
      final team2Player2 = _team2Player2Controller.text.trim();

      if (team1Player1 == team1Player2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ペアAで同じ選手が選択されています'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (team2Player1 == team2Player2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ペアBで同じ選手が選択されています'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ペア間で同じ選手（名前と所属の組み合わせ）チェック
      final team1Club = _team1ClubController.text.trim();
      final team2Club = _team2ClubController.text.trim();

      final team1Players = [
        {'name': team1Player1, 'club': team1Club},
        {'name': team1Player2, 'club': team1Club},
      ];
      final team2Players = [
        {'name': team2Player1, 'club': team2Club},
        {'name': team2Player2, 'club': team2Club},
      ];

      final duplicatePlayers = <String>[];
      for (var p1 in team1Players) {
        for (var p2 in team2Players) {
          if (p1['name'] == p2['name'] && p1['club'] == p2['club']) {
            duplicatePlayers.add(p1['name'] as String);
          }
        }
      }

      if (duplicatePlayers.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ペアAとペアBに同じ選手（${duplicatePlayers.join('、')}）が含まれています'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.of(context).pop({
        'firstServe': _firstServe,
        'tournamentName': _tournamentNameController.text.trim(),
        'team1Player1': team1Player1,
        'team1Player2': team1Player2,
        'team1Club': team1Club,
        'team2Player1': team2Player1,
        'team2Player2': team2Player2,
        'team2Club': team2Club,
      });
    }
  }

  Widget _buildPairSection(
    String label,
    TextEditingController clubController,
    TextEditingController player1Controller,
    TextEditingController player2Controller, {
    required bool isFirstServe,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              // 先サーブ表示（変更不可）
              if (isFirstServe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '先サーブ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 所属
          TextFormField(
            controller: clubController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '所属を入力してください';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: '所属',
              labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          // 選手
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: player1Controller,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '選手1を入力';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: '選手1',
                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: player2Controller,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '選手2を入力';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: '選手2',
                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
