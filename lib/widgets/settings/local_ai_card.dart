import 'package:flutter/material.dart';

import 'package:soft_tennis_scoring/config/local_ai_config.dart';
import 'package:soft_tennis_scoring/services/local_llm.dart';

/// 端末内AIのダウンロード・削除を行う設定カード
///
/// モデルは数百MBあるため、アプリには同梱せず、ここから利用者が
/// 明示的にダウンロードします。**通信量に関わるので、必ず容量を見せてから
/// 落とさせます。**
///
/// 端末内AIが無効なビルドでは、このカードは何も描画しません。
class LocalAiCard extends StatefulWidget {
  const LocalAiCard({super.key});

  @override
  State<LocalAiCard> createState() => _LocalAiCardState();
}

class _LocalAiCardState extends State<LocalAiCard> {
  LocalLlmState _state = LocalLlmState.unavailable;
  int _progress = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = await LocalLlm.state();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _install() async {
    setState(() {
      _state = LocalLlmState.installing;
      _progress = 0;
    });

    final ok = await LocalLlm.install(onProgress: (percent) {
      if (!mounted) return;
      setState(() => _progress = percent);
    });

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ダウンロードに失敗しました。通信環境を確認してください。')),
      );
    }
    await _refresh();
  }

  Future<void> _uninstall() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('端末内AIを削除'),
        content: const Text('モデルを削除すると容量が空きますが、'
            '試合中のアドバイスは定型文だけになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await LocalLlm.uninstall();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // 使えない構成では、存在自体を見せない
    if (_loading || _state == LocalLlmState.unavailable) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '端末内AI',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ダウンロードしておくと、試合中のアドバイスを'
            '通信なしでその場の状況に合わせた言い方にします。',
            style:
                TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 12),
          if (_state == LocalLlmState.installing) ...[
            LinearProgressIndicator(value: _progress / 100),
            const SizedBox(height: 8),
            Text(
              'ダウンロード中… $_progress%',
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ] else if (_state == LocalLlmState.ready) ...[
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 16, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'ダウンロード済み',
                    style: TextStyle(fontSize: 13, color: Color(0xFF333333)),
                  ),
                ),
                TextButton(
                  onPressed: _uninstall,
                  child: const Text('削除'),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _install,
                child: Text(
                  LocalAiConfig.usesLocalFile
                      ? '端末のファイルを読み込む'
                      : 'ダウンロード（約${LocalAiConfig.modelSizeMb}MB）',
                ),
              ),
            ),
            if (!LocalAiConfig.usesLocalFile) ...[
              const SizedBox(height: 6),
              const Text(
                'Wi-Fiでのダウンロードをおすすめします。',
                style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
