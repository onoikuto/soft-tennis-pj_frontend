import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/widgets/common/simple_text_field.dart';
import 'package:soft_tennis_scoring/widgets/common/simple_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _teamController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastNameController.text = prefs.getString('account_last_name') ?? '';
      _firstNameController.text = prefs.getString('account_first_name') ?? '';
      _teamController.text = prefs.getString('account_team') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('account_last_name', _lastNameController.text.trim());
      await prefs.setString('account_first_name', _firstNameController.text.trim());
      await prefs.setString('account_team', _teamController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アカウント設定を保存しました'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // 保存完了を通知
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'アカウント設定',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // プロフィールセクション（マイページと同じスタイル、アイコンなし）
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 苗字（必須）
                    SimpleTextField(
                      label: '苗字',
                      hintText: '苗字を入力',
                      controller: _lastNameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '苗字は必須です';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // 名前（任意）
                    SimpleTextField(
                      label: '名前',
                      hintText: '名前を入力',
                      controller: _firstNameController,
                    ),
                    const SizedBox(height: 16),
                    // 所属チーム（任意）
                    SimpleTextField(
                      label: '所属チーム',
                      hintText: '所属チームを入力',
                      controller: _teamController,
                    ),
                  ],
                ),
              ),
              // 保存ボタン
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '保存する',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

}
