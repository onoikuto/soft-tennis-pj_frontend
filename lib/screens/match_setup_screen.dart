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
  String? _firstServe = 'team1'; // デフォルトでペアAが先サーブ
  
  List<Map<String, dynamic>> _players = [];
  List<String> _clubs = [];
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final players = await DatabaseHelper.instance.getAllPlayers();
      final clubs = await DatabaseHelper.instance.getAllClubs();
      setState(() {
        _players = players;
        _clubs = clubs;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  /// 所属に応じた選手名リストを取得
  List<String> _getPlayerNamesForClub(String? club) {
    if (club == null || club.isEmpty) {
      // 所属が未選択の場合は、所属なしの選手のみ
      return _players
          .where((p) => p['club'] == null || (p['club'] as String).isEmpty)
          .map((p) => p['name'] as String)
          .toSet()
          .toList();
    } else {
      // 所属が選択されている場合は、その所属の選手のみ
      return _players
          .where((p) => p['club'] == club)
          .map((p) => p['name'] as String)
          .toSet()
          .toList();
    }
  }

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
      // バリデーションが成功した場合のみ、すべてのフィールドが入力されている
      
      final team1Player1 = _team1Player1Controller.text.trim();
      final team1Player2 = _team1Player2Controller.text.trim();
      final team2Player1 = _team2Player1Controller.text.trim();
      final team2Player2 = _team2Player2Controller.text.trim();
      
      // 同じペア内で同じ選手が登録されていないかチェック
      if (team1Player1 == team1Player2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ペアAで同じ選手が選択されています。\n異なる選手を選択してください。',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      if (team2Player1 == team2Player2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ペアBで同じ選手が選択されています。\n異なる選手を選択してください。',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      // ペアAとペアBに同じ人物が登録されていないかチェック（名前と所属の組み合わせでチェック）
      final team1Club = _team1ClubController.text.trim();
      final team2Club = _team2ClubController.text.trim();
      
      // ペアAの選手リスト（名前と所属の組み合わせ）
      final team1Players = [
        {'name': team1Player1, 'club': team1Club},
        {'name': team1Player2, 'club': team1Club},
      ];
      
      // ペアBの選手リスト（名前と所属の組み合わせ）
      final team2Players = [
        {'name': team2Player1, 'club': team2Club},
        {'name': team2Player2, 'club': team2Club},
      ];
      
      // 重複チェック（名前と所属の両方が一致する場合のみ重複とみなす）
      final duplicatePlayers = <String>[];
      for (var player1 in team1Players) {
        for (var player2 in team2Players) {
          if (player1['name'] == player2['name'] && player1['club'] == player2['club']) {
            duplicatePlayers.add(player1['name'] as String);
          }
        }
      }
      
      if (duplicatePlayers.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ペアAとペアBに同じ選手（${duplicatePlayers.join('、')}）が含まれています。\n異なる選手を選択してください。',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      final match = Match(
        tournamentName: _tournamentController.text.trim(),
        team1Player1: team1Player1,
        team1Player2: team1Player2,
        team1Club: _team1ClubController.text.trim(),
        team2Player1: team2Player1,
        team2Player2: team2Player2,
        team2Club: _team2ClubController.text.trim(),
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
            // 大会・イベント名
            _buildSection(
              '大会・イベント名',
              TextFormField(
                controller: _tournamentController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '大会・イベント名を入力してください';
                  }
                  return null;
                },
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
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
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
              'ペアA',
              _team1Player1Controller,
              _team1Player2Controller,
              _team1ClubController,
              true,
            ),
            const SizedBox(height: 40),
            // ペアB
            _buildPairSection(
              'ペアB',
              _team2Player1Controller,
              _team2Player2Controller,
              _team2ClubController,
              false,
            ),
            const SizedBox(height: 24),
            // 同名・同所属の選手についての説明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '同じ名前・同じ所属の選手が複数いる場合（例：兄弟など）は、\n'
                      '識別子を追加してください。\n'
                      '例：「山田（太）」「山田（花）」\n'
                      'これにより統計データが正確に計算されます。',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[900],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // ゲーム数
            _buildGameCountSection('ゲーム数'),
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
        child: SizedBox(
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
              '試合を開始する',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.4,
              ),
            ),
          ),
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
    bool isTeam1,
  ) {
    final teamKey = isTeam1 ? 'team1' : 'team2';
    final isFirstServe = _firstServe == teamKey;
    
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
            // 先サーブチェックボックス
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_firstServe == teamKey) {
                    _firstServe = null;
                  } else {
                    _firstServe = teamKey;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isFirstServe ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFirstServe ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 14,
                      color: isFirstServe ? Colors.white : const Color(0xFF7F7F7F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '先サーブ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isFirstServe ? FontWeight.w600 : FontWeight.normal,
                        color: isFirstServe ? Colors.white : const Color(0xFF7F7F7F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 所属フィールドを先に配置
        _buildClubField(clubController, label),
        const SizedBox(height: 12),
        // 選手フィールド
        Row(
          children: [
            Expanded(
              child: _buildPlayerField('選手 1', player1Controller, clubController),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPlayerField('選手 2', player2Controller, clubController),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerField(String label, TextEditingController controller, TextEditingController clubController) {
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
        _buildPlayerAutocompleteField(
          controller: controller,
          hintText: '名前',
          clubController: clubController,
          isRequired: true,
          errorMessage: '名前を入力してください',
        ),
      ],
    );
  }

  Widget _buildPlayerAutocompleteField({
    required TextEditingController controller,
    required String hintText,
    required TextEditingController clubController,
    bool isRequired = false,
    String? errorMessage,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        // 所属に応じた選手リストを動的に取得
        final club = clubController.text.trim().isEmpty ? null : clubController.text.trim();
        final playerNames = _getPlayerNamesForClub(club);
        
        if (textEditingValue.text.isEmpty) {
          return playerNames.take(10);
        }
        final query = textEditingValue.text.toLowerCase();
        return playerNames.where((item) {
          return item.toLowerCase().contains(query);
        }).take(10);
      },
      onSelected: (String selection) {
        controller.text = selection;
        setState(() {});
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // 初期値を設定
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (fieldController.text != controller.text) {
            fieldController.text = controller.text;
          }
        });
        
        // コントローラーを同期するためのリスナー
        fieldController.addListener(() {
          if (fieldController.text != controller.text) {
            controller.text = fieldController.text;
          }
        });
        
        // 所属フィールドの変更を監視
        clubController.addListener(() {
          setState(() {});
        });
        
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return errorMessage ?? '入力してください';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      },
    );
  }


  Widget _buildClubField(TextEditingController controller, String teamLabel) {
    return _buildAutocompleteField(
      controller: controller,
      hintText: '所属名を入力',
      options: _clubs,
      isRequired: true,
      errorMessage: '$teamLabelの所属名を入力してください',
      onChanged: () {
        // 所属が変更されたら選手リストを更新
        setState(() {});
      },
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String hintText,
    required List<String> options,
    bool isRequired = false,
    String? errorMessage,
    TextEditingController? clubController,
    VoidCallback? onChanged,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return options.take(10); // 空欄時は最初の10件を表示
        }
        final query = textEditingValue.text.toLowerCase();
        return options.where((item) {
          return item.toLowerCase().contains(query);
        }).take(10);
      },
      onSelected: (String selection) {
        controller.text = selection;
        if (onChanged != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged();
          });
        }
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // 初期値を設定
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (fieldController.text != controller.text) {
            fieldController.text = controller.text;
          }
        });
        
        // コントローラーを同期するためのリスナー
        fieldController.addListener(() {
          if (fieldController.text != controller.text) {
            controller.text = fieldController.text;
            // 変更時にコールバックを実行
            if (onChanged != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onChanged();
              });
            }
          }
        });
        
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return errorMessage ?? '入力してください';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: options.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7F7F7F)),
                    onPressed: () {
                      focusNode.requestFocus();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 14),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: index < options.length - 1 ? 1 : 0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameCountSection(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
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
