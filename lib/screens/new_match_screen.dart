import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/screens/match_detail_screen.dart';

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _team1ClubController = TextEditingController();
  final _team1Player1Controller = TextEditingController();
  final _team1Player2Controller = TextEditingController();
  final _team2ClubController = TextEditingController();
  final _team2Player1Controller = TextEditingController();
  final _team2Player2Controller = TextEditingController();

  List<String> _playerNames = [];
  List<String> _clubs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final players = await DatabaseHelper.instance.getAllPlayerNames();
      final clubs = await DatabaseHelper.instance.getAllClubs();
      setState(() {
        _playerNames = players;
        _clubs = clubs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _team1ClubController.dispose();
    _team1Player1Controller.dispose();
    _team1Player2Controller.dispose();
    _team2ClubController.dispose();
    _team2Player1Controller.dispose();
    _team2Player2Controller.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
    if (_formKey.currentState!.validate()) {
      final match = Match(
        tournamentName: '',
        team1Player1: _team1Player1Controller.text.trim(),
        team1Player2: _team1Player2Controller.text.trim(),
        team1Club: _team1ClubController.text.trim(),
        team2Player1: _team2Player1Controller.text.trim(),
        team2Player2: _team2Player2Controller.text.trim(),
        team2Club: _team2ClubController.text.trim(),
        createdAt: DateTime.now(),
      );

      final matchId = await DatabaseHelper.instance.insertMatch(match);

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchDetailScreen(matchId: matchId),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新しいマッチ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'チーム1',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              controller: _team1ClubController,
              labelText: '所属',
              hintText: '所属を入力または選択',
              options: _clubs,
              icon: Icons.business,
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              controller: _team1Player1Controller,
              labelText: 'プレイヤー1',
              hintText: 'プレイヤー名を入力または選択',
              options: _playerNames,
              icon: Icons.person,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              controller: _team1Player2Controller,
              labelText: 'プレイヤー2',
              hintText: 'プレイヤー名を入力または選択',
              options: _playerNames,
              icon: Icons.person,
              isRequired: true,
            ),
            const SizedBox(height: 32),
            const Text(
              'チーム2',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              controller: _team2ClubController,
              labelText: '所属',
              hintText: '所属を入力または選択',
              options: _clubs,
              icon: Icons.business,
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              controller: _team2Player1Controller,
              labelText: 'プレイヤー1',
              hintText: 'プレイヤー名を入力または選択',
              options: _playerNames,
              icon: Icons.person,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              controller: _team2Player2Controller,
              labelText: 'プレイヤー2',
              hintText: 'プレイヤー名を入力または選択',
              options: _playerNames,
              icon: Icons.person,
              isRequired: true,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _createMatch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'マッチを作成',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required List<String> options,
    required IconData icon,
    bool isRequired = false,
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
        
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon),
            suffixIcon: options.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () {
                      focusNode.requestFocus();
                    },
                  )
                : null,
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$labelTextを入力してください';
                  }
                  return null;
                }
              : null,
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
            borderRadius: BorderRadius.circular(8),
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
                            icon,
                            size: 20,
                            color: Colors.grey,
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
}
