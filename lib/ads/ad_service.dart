// AdMob wiring. Ships with Google's official TEST ids — swap to real ids
// before production (see RELEASE_CHECKLIST.md).
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Google sample ids (test). Replace for release.
  static const String bannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedId = 'ca-app-pub-3940256099942544/5224354917';

  bool _initialized = false;
  Future<void>? _initFuture;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _winsSinceInterstitial = 0;

  /// Shared init future: concurrent callers await the same init instead
  /// of the second one returning early while init is still running.
  Future<void> init() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  BannerAd makeBanner() {
    return BannerAd(
      size: AdSize.banner,
      adUnitId: bannerId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  /// Call on every level win. Shows an interstitial every 3rd win.
  void onLevelWon() {
    _winsSinceInterstitial++;
    if (_winsSinceInterstitial >= 3) {
      _winsSinceInterstitial = 0;
      final ad = _interstitial;
      if (ad != null) {
        _interstitial = null;
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (a) {
            a.dispose();
            _loadInterstitial();
          },
          onAdFailedToShowFullScreenContent: (a, _) {
            a.dispose();
            _loadInterstitial();
          },
        );
        ad.show();
      } else {
        _loadInterstitial();
      }
    }
  }

  /// Shows a rewarded ad. Completes with true when the user earned it.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadRewarded();
      },
    );
    await ad.show(
      onUserEarnedReward: (_, _) => earned = true,
    );
    return earned;
  }
}
