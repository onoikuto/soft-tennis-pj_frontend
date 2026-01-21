import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  List<Map<String, dynamic>> _players = [];
  List<String> _clubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final players = await DatabaseHelper.instance.getAllPlayers();
    final clubs = await DatabaseHelper.instance.getAllClubs();
    setState(() {
      _players = players;
      _clubs = clubs;
      _isLoading = false;
    });
  }

  Future<void> _loadPlayers() async {
    final players = await DatabaseHelper.instance.getAllPlayers();
    setState(() {
      _players = players;
    });
  }

  /// 選手を所属ごとにグループ化
  Map<String, List<Map<String, dynamic>>> _groupPlayersByClub() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (var player in _players) {
      final club = player['club'] as String?;
      final clubKey = club != null && club.isNotEmpty ? club : '所属なし';
      
      if (!grouped.containsKey(clubKey)) {
        grouped[clubKey] = [];
      }
      grouped[clubKey]!.add(player);
    }
    
    // 所属名でソート（「所属なし」は最後に）
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '所属なし') return 1;
        if (b == '所属なし') return -1;
        return a.compareTo(b);
      });
    
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (var key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }
    
    return sortedMap;
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? player}) async {
    final nameController = TextEditingController(text: player?['name'] ?? '');
    final clubController = TextEditingController(text: player?['club'] ?? '');
    final formKey = GlobalKey<FormState>();
    String? selectedClub = player?['club'] as String?;
    if (selectedClub != null && selectedClub.isEmpty) {
      selectedClub = null;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              player == null ? '選手を追加' : '選手を編集',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '選手名',
                        hintText: '選手名を入力',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '選手名を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      initialValue: selectedClub != null ? TextEditingValue(text: selectedClub!) : null,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _clubs.take(10);
                        }
                        final query = textEditingValue.text.toLowerCase();
                        return _clubs.where((club) {
                          return club.toLowerCase().contains(query);
                        }).take(10);
                      },
                      onSelected: (String selection) {
                        setDialogState(() {
                          selectedClub = selection;
                          clubController.text = selection;
                        });
                      },
                      fieldViewBuilder: (
                        BuildContext context,
                        TextEditingController fieldController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (selectedClub != null && fieldController.text != selectedClub) {
                            fieldController.text = selectedClub!;
                            clubController.text = selectedClub!;
                          }
                        });
                        return TextFormField(
                          controller: fieldController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: '所属',
                            hintText: '所属を選択（任意）',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            suffixIcon: fieldController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setDialogState(() {
                                        fieldController.clear();
                                        clubController.clear();
                                        selectedClub = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              clubController.text = value;
                              if (value.isEmpty) {
                                selectedClub = null;
                              } else if (_clubs.contains(value)) {
                                selectedClub = value;
                              } else {
                                selectedClub = value;
                              }
                            });
                          },
                        );
                      },
                    ),
                    if (_clubs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '所属チームが登録されていません。\n所属チーム管理から登録してください。',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final club = clubController.text.trim().isEmpty ? null : clubController.text.trim();
      
      // 重複チェック
      final isDuplicate = await DatabaseHelper.instance.checkPlayerDuplicate(
        name: name,
        club: club,
        excludeId: player?['id'] as int?,
      );
      
      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                club != null && club.isNotEmpty
                    ? '同じ名前・同じ所属の選手が既に存在します'
                    : '同じ名前の選手が既に存在します（所属なし）',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      if (player == null) {
        // 新規追加
        await DatabaseHelper.instance.insertPlayer(
          name: name,
          club: club,
        );
      } else {
        // 編集
        await DatabaseHelper.instance.updatePlayer(
          id: player['id'] as int,
          name: name,
          club: club,
        );
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(player == null ? '選手を追加しました' : '選手を更新しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> player) async {
    final playerName = player['name'] as String;
    final club = player['club'] as String?;
    final displayText = club != null && club.isNotEmpty
        ? '$playerName（$club）'
        : playerName;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('選手を削除しますか？'),
        content: Text('$displayTextを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (result == true) {
      await DatabaseHelper.instance.deletePlayer(player['id'] as int);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('選手を削除しました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '選手管理',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF333333)),
            iconSize: 24,
            onPressed: () => _showAddEditDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF333333),
              ),
            )
          : _players.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 40,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '登録されている選手がありません',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '右上の+ボタンから選手を追加してください',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPlayers,
                  color: const Color(0xFF333333),
                  child: Builder(
                    builder: (context) {
                      final groupedPlayers = _groupPlayersByClub();
                      final sections = groupedPlayers.entries.toList();
                      
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        children: sections.map((section) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // セクションヘッダー
                              Container(
                                margin: EdgeInsets.only(
                                  top: sections.indexOf(section) == 0 ? 0 : 32,
                                  bottom: 12,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: section.key == '所属なし'
                                            ? const Color(0xFFF5F5F5)
                                            : const Color(0xFFE8F4F8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        section.key == '所属なし'
                                            ? Icons.person_outline
                                            : Icons.sports_tennis,
                                        size: 18,
                                        color: section.key == '所属なし'
                                            ? const Color(0xFF888888)
                                            : const Color(0xFF4A90E2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        section.key,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF333333),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${section.value.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF555555),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 選手リスト
                              ...section.value.map((player) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE8E8E8),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _showAddEditDialog(player: player),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                player['name'] as String,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Color(0xFF333333),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                color: Color(0xFF666666),
                                                size: 20,
                                              ),
                                              onPressed: () => _showAddEditDialog(player: player),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Color(0xFFE53935),
                                                size: 20,
                                              ),
                                              onPressed: () => _showDeleteDialog(player),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
    );
  }
}
