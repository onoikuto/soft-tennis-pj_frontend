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
  final _team1Player1Controller = TextEditingController();
  final _team1Player2Controller = TextEditingController();
  final _team2Player1Controller = TextEditingController();
  final _team2Player2Controller = TextEditingController();

  @override
  void dispose() {
    _team1Player1Controller.dispose();
    _team1Player2Controller.dispose();
    _team2Player1Controller.dispose();
    _team2Player2Controller.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
    if (_formKey.currentState!.validate()) {
      final match = Match(
        team1Player1: _team1Player1Controller.text.trim(),
        team1Player2: _team1Player2Controller.text.trim(),
        team2Player1: _team2Player1Controller.text.trim(),
        team2Player2: _team2Player2Controller.text.trim(),
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
            TextFormField(
              controller: _team1Player1Controller,
              decoration: const InputDecoration(
                labelText: 'プレイヤー1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'プレイヤー名を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _team1Player2Controller,
              decoration: const InputDecoration(
                labelText: 'プレイヤー2',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'プレイヤー名を入力してください';
                }
                return null;
              },
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
            TextFormField(
              controller: _team2Player1Controller,
              decoration: const InputDecoration(
                labelText: 'プレイヤー1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'プレイヤー名を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _team2Player2Controller,
              decoration: const InputDecoration(
                labelText: 'プレイヤー2',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'プレイヤー名を入力してください';
                }
                return null;
              },
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
}
