import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:soft_tennis_scoring/config/ad_config.dart';

/// 統計画面用の広告バナー
///
/// macOS/Web、またはサブスクリプション済みの場合は表示しません。
///
/// [BannerAd] は一度だけ生成してロードし、ウィジェットの破棄時に
/// 必ず [BannerAd.dispose] を呼びます（再描画のたびに新規生成すると
/// 広告インスタンスがリークするため）。
class AdBanner extends StatefulWidget {
  final bool isSubscribed;

  const AdBanner({
    super.key,
    required this.isSubscribed,
  });

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  bool get _adsSupported =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    if (_adsSupported && !widget.isSubscribed) {
      _loadAd();
    }
  }

  @override
  void didUpdateWidget(AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // サブスクリプション状態が変わった場合、広告の生成・破棄を切り替える
    if (widget.isSubscribed && !oldWidget.isSubscribed) {
      _disposeAd();
    } else if (!widget.isSubscribed && oldWidget.isSubscribed && _adsSupported) {
      _loadAd();
    }
  }

  void _loadAd() {
    try {
      final bannerAd = BannerAd(
        adUnitId: AdConfig.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) {
              setState(() => _isLoaded = true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('広告の読み込みに失敗しました: $error');
            ad.dispose();
          },
        ),
      );
      bannerAd.load();
      _bannerAd = bannerAd;
    } catch (e) {
      debugPrint('広告の作成に失敗しました: $e');
    }
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    if (mounted) {
      setState(() => _isLoaded = false);
    } else {
      _isLoaded = false;
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adsSupported || widget.isSubscribed || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: 50,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
