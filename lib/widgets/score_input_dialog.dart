import 'package:flutter/material.dart';

class ScoreInputDialog extends StatefulWidget {
  final String team1Name;
  final String team2Name;
  final int setNumber;

  const ScoreInputDialog({
    super.key,
    required this.team1Name,
    required this.team2Name,
    required this.setNumber,
  });

  @override
  State<ScoreInputDialog> createState() => _ScoreInputDialogState();
}

class _ScoreInputDialogState extends State<ScoreInputDialog> {
  int _team1Score = 0;
  int _team2Score = 0;

  void _incrementTeam1() {
    setState(() {
      if (_team1Score < 7) {
        _team1Score++;
      }
    });
  }

  void _decrementTeam1() {
    setState(() {
      if (_team1Score > 0) {
        _team1Score--;
      }
    });
  }

  void _incrementTeam2() {
    setState(() {
      if (_team2Score < 7) {
        _team2Score++;
      }
    });
  }

  void _decrementTeam2() {
    setState(() {
      if (_team2Score > 0) {
        _team2Score--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('セット ${widget.setNumber} のスコア'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // チーム1
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    widget.team1Name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _decrementTeam1,
                        icon: const Icon(Icons.remove_circle),
                        iconSize: 32,
                      ),
                      Text(
                        '$_team1Score',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _incrementTeam1,
                        icon: const Icon(Icons.add_circle),
                        iconSize: 32,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('VS', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 16),
          // チーム2
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    widget.team2Name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _decrementTeam2,
                        icon: const Icon(Icons.remove_circle),
                        iconSize: 32,
                      ),
                      Text(
                        '$_team2Score',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _incrementTeam2,
                        icon: const Icon(Icons.add_circle),
                        iconSize: 32,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'team1': _team1Score,
              'team2': _team2Score,
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
