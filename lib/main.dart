import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show Platform, HttpHeaders, HttpClient, HttpClientRequest, HttpClientResponse;
import 'dart:math' as math;
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart' as appsflyer_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodChannel, SystemChrome, SystemUiOverlayStyle, MethodCall;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:loungeoflendess/psladnes.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz_zone;

import 'ledness.dart';

// ============================================================================
// Константы
// ============================================================================

const String loungeOfIdlenessLoadedOnceKey = 'loaded_once';
const String loungeOfIdlenessStatEndpoint = 'https://sub.sllounge.club/stat';
const String loungeOfIdlenessCachedFcmKey = 'cached_fcm';
const String loungeOfIdlenessCachedDeepKey = 'cached_deep_push_uri';

// ============================================================================
// Лёгкие сервисы
// ============================================================================

class LoungeOfIdlenessLoggerService {
  static final LoungeOfIdlenessLoggerService sharedLoungeInstance =
  LoungeOfIdlenessLoggerService._internalLoungeConstructor();

  LoungeOfIdlenessLoggerService._internalLoungeConstructor();

  factory LoungeOfIdlenessLoggerService() => sharedLoungeInstance;

  final Connectivity loungeOfIdlenessConnectivity = Connectivity();

  void loungeOfIdlenessLogInfo(Object message) => debugPrint('[I] $message');
  void loungeOfIdlenessLogWarn(Object message) => debugPrint('[W] $message');
  void loungeOfIdlenessLogError(Object message) => debugPrint('[E] $message');
}

class LoungeOfIdlenessNetworkService {
  final LoungeOfIdlenessLoggerService loungeOfIdlenessLogger =
  LoungeOfIdlenessLoggerService();

  Future<bool> loungeOfIdlenessIsOnline() async {
    final List<ConnectivityResult> loungeOfIdlenessResults =
    await loungeOfIdlenessLogger.loungeOfIdlenessConnectivity
        .checkConnectivity();
    return loungeOfIdlenessResults.isNotEmpty &&
        !loungeOfIdlenessResults.contains(ConnectivityResult.none);
  }

  Future<void> loungeOfIdlenessPostJson(
      String url,
      Map<String, dynamic> data,
      ) async {
    try {
      await http.post(
        Uri.parse(url),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
    } catch (error) {
      loungeOfIdlenessLogger
          .loungeOfIdlenessLogError('postJson error: $error');
    }
  }
}

// ============================================================================
// Профиль устройства
// ============================================================================

class LoungeOfIdlenessDeviceProfile {
  String? loungeOfIdlenessDeviceId;
  String? loungeOfIdlenessSessionId = 'retrocar-session';
  String? loungeOfIdlenessPlatformName;
  String? loungeOfIdlenessOsVersion;
  String? loungeOfIdlenessAppVersion;
  String? loungeOfIdlenessLanguageCode;
  String? loungeOfIdlenessTimezoneName;
  bool loungeOfIdlenessPushEnabled = false;

  Future<void> loungeOfIdlenessInitialize() async {
    final DeviceInfoPlugin loungeOfIdlenessDeviceInfoPlugin =
    DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo loungeOfIdlenessAndroidInfo =
      await loungeOfIdlenessDeviceInfoPlugin.androidInfo;
      loungeOfIdlenessDeviceId = loungeOfIdlenessAndroidInfo.id;
      loungeOfIdlenessPlatformName = 'android';
      loungeOfIdlenessOsVersion =
          loungeOfIdlenessAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo loungeOfIdlenessIosInfo =
      await loungeOfIdlenessDeviceInfoPlugin.iosInfo;
      loungeOfIdlenessDeviceId =
          loungeOfIdlenessIosInfo.identifierForVendor;
      loungeOfIdlenessPlatformName = 'ios';
      loungeOfIdlenessOsVersion =
          loungeOfIdlenessIosInfo.systemVersion;
    }

    final PackageInfo loungeOfIdlenessPackageInfo =
    await PackageInfo.fromPlatform();
    loungeOfIdlenessAppVersion = loungeOfIdlenessPackageInfo.version;
    loungeOfIdlenessLanguageCode = Platform.localeName.split('_').first;
    loungeOfIdlenessTimezoneName = tz_zone.local.name;
    loungeOfIdlenessSessionId =
    'retrocar-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> loungeOfIdlenessToMap({String? fcmToken}) =>
      <String, dynamic>{
        'fcm_token': fcmToken ?? 'missing_token',
        'device_id': loungeOfIdlenessDeviceId ?? 'missing_id',
        'app_name': 'sllounge',
        'instance_id': loungeOfIdlenessSessionId ?? 'missing_session',
        'platform': loungeOfIdlenessPlatformName ?? 'missing_system',
        'os_version': loungeOfIdlenessOsVersion ?? 'missing_build',
        'app_version': loungeOfIdlenessAppVersion ?? 'missing_app',
        'language': loungeOfIdlenessLanguageCode ?? 'en',
        'timezone': loungeOfIdlenessTimezoneName ?? 'UTC',
        'push_enabled': loungeOfIdlenessPushEnabled,
      };
}

// ============================================================================
// AppsFlyer Spy
// ============================================================================

class LoungeOfIdlenessAnalyticsSpyService {
  appsflyer_core.AppsFlyerOptions? loungeOfIdlenessAppsFlyerOptions;
  appsflyer_core.AppsflyerSdk? loungeOfIdlenessAppsFlyerSdk;

  String loungeOfIdlenessAppsFlyerUid = '';
  String loungeOfIdlenessAppsFlyerData = '';

  void loungeOfIdlenessStartTracking({VoidCallback? onUpdate}) {
    final appsflyer_core.AppsFlyerOptions loungeOfIdlenessConfig =
    appsflyer_core.AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6759056932',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    loungeOfIdlenessAppsFlyerOptions = loungeOfIdlenessConfig;
    loungeOfIdlenessAppsFlyerSdk =
        appsflyer_core.AppsflyerSdk(loungeOfIdlenessConfig);

    loungeOfIdlenessAppsFlyerSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    loungeOfIdlenessAppsFlyerSdk?.startSDK(
      onSuccess: () => LoungeOfIdlenessLoggerService()
          .loungeOfIdlenessLogInfo('RetroCarAnalyticsSpy started'),
      onError: (int code, String msg) => LoungeOfIdlenessLoggerService()
          .loungeOfIdlenessLogError('RetroCarAnalyticsSpy error $code: $msg'),
    );

    loungeOfIdlenessAppsFlyerSdk?.onInstallConversionData(
            (dynamic value) {
          loungeOfIdlenessAppsFlyerData = value.toString();
          onUpdate?.call();
        });

    loungeOfIdlenessAppsFlyerSdk?.getAppsFlyerUID().then((dynamic value) {
      loungeOfIdlenessAppsFlyerUid = value.toString();
      onUpdate?.call();
    });
  }
}

// ============================================================================
// Новый лоадер Lounge of Idleness
// ============================================================================

class LoungeOfIdlenessWaveLoader extends StatefulWidget {
  const LoungeOfIdlenessWaveLoader({Key? key}) : super(key: key);

  @override
  State<LoungeOfIdlenessWaveLoader> createState() =>
      _LoungeOfIdlenessWaveLoaderState();
}

class _LoungeOfIdlenessWaveLoaderState
    extends State<LoungeOfIdlenessWaveLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController loungeOfIdlenessWaveController;

  @override
  void initState() {
    super.initState();
    loungeOfIdlenessWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    loungeOfIdlenessWaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color loungeOfIdlenessBackground = Color(0xFF05071B);
    const Color loungeOfIdlenessPrimary = Color(0xFF49F2FF);
    const Color loungeOfIdlenessSecondary = Color(0xFFFFA54B);

    const String loungeOfIdlenessTitle = 'Lounge';
    const String loungeOfIdlenessSubtitle = 'of Idleness';

    return Container(
      color: loungeOfIdlenessBackground,
      child: Center(
        child: AnimatedBuilder(
          animation: loungeOfIdlenessWaveController,
          builder: (BuildContext context, Widget? child) {
            final double loungeOfIdlenessT =
                loungeOfIdlenessWaveController.value * 2 * math.pi;

            List<Widget> loungeOfIdlenessLetters = <Widget>[];
            for (int loungeOfIdlenessIndex = 0;
            loungeOfIdlenessIndex < loungeOfIdlenessTitle.length;
            loungeOfIdlenessIndex++) {
              final String loungeOfIdlenessChar =
              loungeOfIdlenessTitle[loungeOfIdlenessIndex];
              final double loungeOfIdlenessPhase =
                  loungeOfIdlenessT + loungeOfIdlenessIndex * 0.6;
              final double loungeOfIdlenessDy =
                  math.sin(loungeOfIdlenessPhase) * 6.0;
              final double loungeOfIdlenessOpacity =
                  0.7 + 0.3 * math.sin(loungeOfIdlenessPhase).abs();

              loungeOfIdlenessLetters.add(
                Transform.translate(
                  offset: Offset(0, loungeOfIdlenessDy),
                  child: Text(
                    loungeOfIdlenessChar,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: loungeOfIdlenessPrimary
                          .withOpacity(loungeOfIdlenessOpacity),
                      shadows: <Shadow>[
                        Shadow(
                          color: loungeOfIdlenessSecondary.withOpacity(
                              0.6 * loungeOfIdlenessOpacity),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.transparent,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: loungeOfIdlenessPrimary.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                    border: Border.all(
                      color: loungeOfIdlenessPrimary.withOpacity(0.9),
                      width: 3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: loungeOfIdlenessLetters,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loungeOfIdlenessSubtitle,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 3,
                    color: loungeOfIdlenessPrimary.withOpacity(0.9),
                    shadows: <Shadow>[
                      Shadow(
                        color: loungeOfIdlenessSecondary.withOpacity(0.7),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// FCM фон
// ============================================================================

@pragma('vm:entry-point')
Future<void> loungeOfIdlenessFcmBackgroundHandler(
    RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  LoungeOfIdlenessLoggerService()
      .loungeOfIdlenessLogInfo('bg-fcm: ${message.messageId}');
  LoungeOfIdlenessLoggerService()
      .loungeOfIdlenessLogInfo('bg-data: ${message.data}');

  final dynamic loungeOfIdlenessLink = message.data['uri'];
  if (loungeOfIdlenessLink != null) {
    try {
      final SharedPreferences loungeOfIdlenessPrefs =
      await SharedPreferences.getInstance();
      await loungeOfIdlenessPrefs.setString(
        loungeOfIdlenessCachedDeepKey,
        loungeOfIdlenessLink.toString(),
      );
    } catch (e) {
      LoungeOfIdlenessLoggerService()
          .loungeOfIdlenessLogError('bg-fcm save deep failed: $e');
    }
  }
}

// ============================================================================
// BLoC (на ChangeNotifier) + состояние
// ============================================================================

class LoungeOfIdlenessAppState {
  final String? loungeOfIdlenessFcmToken;
  final LoungeOfIdlenessDeviceProfile loungeOfIdlenessDeviceProfile;
  final bool loungeOfIdlenessIsDeviceReady;
  final bool loungeOfIdlenessIsAppsFlyerReady;

  const LoungeOfIdlenessAppState({
    required this.loungeOfIdlenessFcmToken,
    required this.loungeOfIdlenessDeviceProfile,
    required this.loungeOfIdlenessIsDeviceReady,
    required this.loungeOfIdlenessIsAppsFlyerReady,
  });

  LoungeOfIdlenessAppState loungeOfIdlenessCopyWith({
    String? loungeOfIdlenessFcmToken,
    LoungeOfIdlenessDeviceProfile? loungeOfIdlenessDeviceProfile,
    bool? loungeOfIdlenessIsDeviceReady,
    bool? loungeOfIdlenessIsAppsFlyerReady,
  }) {
    return LoungeOfIdlenessAppState(
      loungeOfIdlenessFcmToken:
      loungeOfIdlenessFcmToken ?? this.loungeOfIdlenessFcmToken,
      loungeOfIdlenessDeviceProfile:
      loungeOfIdlenessDeviceProfile ?? this.loungeOfIdlenessDeviceProfile,
      loungeOfIdlenessIsDeviceReady:
      loungeOfIdlenessIsDeviceReady ?? this.loungeOfIdlenessIsDeviceReady,
      loungeOfIdlenessIsAppsFlyerReady: loungeOfIdlenessIsAppsFlyerReady ??
          this.loungeOfIdlenessIsAppsFlyerReady,
    );
  }
}

class LoungeOfIdlenessAppBloc extends ChangeNotifier {
  final LoungeOfIdlenessLoggerService loungeOfIdlenessLoggerService =
  LoungeOfIdlenessLoggerService();
  final LoungeOfIdlenessAnalyticsSpyService
  loungeOfIdlenessAnalyticsSpyService;
  final LoungeOfIdlenessDeviceProfile loungeOfIdlenessDeviceProfile;

  LoungeOfIdlenessAppState loungeOfIdlenessState;

  LoungeOfIdlenessAppState get state => loungeOfIdlenessState;

  LoungeOfIdlenessAppBloc({
    required this.loungeOfIdlenessAnalyticsSpyService,
    required this.loungeOfIdlenessDeviceProfile,
  }) : loungeOfIdlenessState = LoungeOfIdlenessAppState(
    loungeOfIdlenessFcmToken: null,
    loungeOfIdlenessDeviceProfile: loungeOfIdlenessDeviceProfile,
    loungeOfIdlenessIsDeviceReady: false,
    loungeOfIdlenessIsAppsFlyerReady: false,
  );

  Future<void> loungeOfIdlenessInitialize() async {
    await loungeOfIdlenessInitDeviceProfile();
    await loungeOfIdlenessInitAppsFlyer();
    await loungeOfIdlenessInitFcmToken();
  }

  Future<void> loungeOfIdlenessInitDeviceProfile() async {
    try {
      await loungeOfIdlenessDeviceProfile.loungeOfIdlenessInitialize();

      final FirebaseMessaging loungeOfIdlenessMessaging =
          FirebaseMessaging.instance;
      final NotificationSettings loungeOfIdlenessSettings =
      await loungeOfIdlenessMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      loungeOfIdlenessDeviceProfile.loungeOfIdlenessPushEnabled =
          loungeOfIdlenessSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              loungeOfIdlenessSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;

      loungeOfIdlenessState = loungeOfIdlenessState.loungeOfIdlenessCopyWith(
        loungeOfIdlenessDeviceProfile: loungeOfIdlenessDeviceProfile,
        loungeOfIdlenessIsDeviceReady: true,
      );
      notifyListeners();
    } catch (e, st) {
      loungeOfIdlenessLoggerService.loungeOfIdlenessLogError(
          'BLoC: initDeviceProfile error: $e\n$st');
    }
  }

  Future<void> loungeOfIdlenessInitAppsFlyer() async {
    try {
      loungeOfIdlenessAnalyticsSpyService.loungeOfIdlenessStartTracking(
        onUpdate: () {
          loungeOfIdlenessState =
              loungeOfIdlenessState.loungeOfIdlenessCopyWith(
                loungeOfIdlenessIsAppsFlyerReady: true,
              );
          notifyListeners();
        },
      );
    } catch (e, st) {
      loungeOfIdlenessLoggerService.loungeOfIdlenessLogError(
          'BLoC: initAppsFlyer error: $e\n$st');
    }
  }

  Future<void> loungeOfIdlenessInitFcmToken() async {
    try {
      final String? loungeOfIdlenessToken =
      await FirebaseMessaging.instance.getToken();
      if (loungeOfIdlenessToken != null &&
          loungeOfIdlenessToken.isNotEmpty) {
        loungeOfIdlenessSetFcmToken(loungeOfIdlenessToken);
      }
      FirebaseMessaging.instance
          .onTokenRefresh
          .listen(loungeOfIdlenessSetFcmToken);
    } catch (e, st) {
      loungeOfIdlenessLoggerService.loungeOfIdlenessLogError(
          'BLoC: initFcmToken error: $e\n$st');
    }
  }

  void loungeOfIdlenessSetFcmToken(String newToken) {
    loungeOfIdlenessState =
        loungeOfIdlenessState.loungeOfIdlenessCopyWith(
          loungeOfIdlenessFcmToken: newToken,
        );
    notifyListeners();
  }
}

// ============================================================================
// FCM Bridge (нативный канал)
// ============================================================================

class LoungeOfIdlenessFcmBridge {
  final LoungeOfIdlenessLoggerService loungeOfIdlenessLoggerService =
  LoungeOfIdlenessLoggerService();
  String? loungeOfIdlenessToken;
  final List<void Function(String)> loungeOfIdlenessTokenWaiters =
  <void Function(String)>[];

  String? get loungeOfIdlenessFcmToken => loungeOfIdlenessToken;

  LoungeOfIdlenessFcmBridge() {
    const MethodChannel('com.example.fcm/token')
        .setMethodCallHandler((MethodCall call) async {
      if (call.method == 'setToken') {
        final String loungeOfIdlenessTokenString =
        call.arguments as String;
        if (loungeOfIdlenessTokenString.isNotEmpty) {
          loungeOfIdlenessSetToken(loungeOfIdlenessTokenString);
        }
      }
    });

    loungeOfIdlenessRestoreToken();
  }

  Future<void> loungeOfIdlenessRestoreToken() async {
    try {
      final SharedPreferences loungeOfIdlenessPrefs =
      await SharedPreferences.getInstance();
      final String? loungeOfIdlenessCachedToken =
      loungeOfIdlenessPrefs.getString(loungeOfIdlenessCachedFcmKey);
      if (loungeOfIdlenessCachedToken != null &&
          loungeOfIdlenessCachedToken.isNotEmpty) {
        loungeOfIdlenessSetToken(
          loungeOfIdlenessCachedToken,
          notify: false,
        );
      }
    } catch (_) {}
  }

  Future<void> loungeOfIdlenessPersistToken(String newToken) async {
    try {
      final SharedPreferences loungeOfIdlenessPrefs =
      await SharedPreferences.getInstance();
      await loungeOfIdlenessPrefs.setString(
          loungeOfIdlenessCachedFcmKey, newToken);
    } catch (_) {}
  }

  void loungeOfIdlenessSetToken(
      String newToken, {
        bool notify = true,
      }) {
    loungeOfIdlenessToken = newToken;
    loungeOfIdlenessPersistToken(newToken);
    if (notify) {
      for (final void Function(String) loungeOfIdlenessCallback
      in List<void Function(String)>.from(
          loungeOfIdlenessTokenWaiters)) {
        try {
          loungeOfIdlenessCallback(newToken);
        } catch (error) {
          loungeOfIdlenessLoggerService
              .loungeOfIdlenessLogWarn('fcm waiter error: $error');
        }
      }
      loungeOfIdlenessTokenWaiters.clear();
    }
  }

  Future<void> loungeOfIdlenessWaitForToken(
      Function(String token) loungeOfIdlenessOnToken,
      ) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if ((loungeOfIdlenessToken ?? '').isNotEmpty) {
        loungeOfIdlenessOnToken(loungeOfIdlenessToken!);
        return;
      }

      loungeOfIdlenessTokenWaiters.add(loungeOfIdlenessOnToken);
    } catch (error) {
      loungeOfIdlenessLoggerService
          .loungeOfIdlenessLogError('waitToken error: $error');
    }
  }
}

// ============================================================================
// Splash / Hall
// ============================================================================

class LoungeOfIdlenessHall extends StatefulWidget {
  const LoungeOfIdlenessHall({Key? key}) : super(key: key);

  @override
  State<LoungeOfIdlenessHall> createState() =>
      _LoungeOfIdlenessHallState();
}

class _LoungeOfIdlenessHallState extends State<LoungeOfIdlenessHall> {
  final LoungeOfIdlenessFcmBridge loungeOfIdlenessFcmBridge =
  LoungeOfIdlenessFcmBridge();
  bool loungeOfIdlenessNavigatedOnce = false;
  Timer? loungeOfIdlenessFallbackTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    final LoungeOfIdlenessAppBloc loungeOfIdlenessBloc =
    context.read<LoungeOfIdlenessAppBloc>();
    loungeOfIdlenessBloc.loungeOfIdlenessInitialize();

    loungeOfIdlenessFcmBridge
        .loungeOfIdlenessWaitForToken((String loungeOfIdlenessToken) {
      loungeOfIdlenessGoToHarbor(loungeOfIdlenessToken);
    });

    loungeOfIdlenessFallbackTimer = Timer(
      const Duration(seconds: 8),
          () => loungeOfIdlenessGoToHarbor(
        context
            .read<LoungeOfIdlenessAppBloc>()
            .state
            .loungeOfIdlenessFcmToken ??
            '',
      ),
    );
  }

  void loungeOfIdlenessGoToHarbor(String loungeOfIdlenessSignal) {
    if (loungeOfIdlenessNavigatedOnce) return;
    loungeOfIdlenessNavigatedOnce = true;
    loungeOfIdlenessFallbackTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<Widget>(
        builder: (BuildContext context) => LoungeOfIdlenessHarbor(
          loungeOfIdlenessSignal: loungeOfIdlenessSignal,
        ),
      ),
    );
  }

  @override
  void dispose() {
    loungeOfIdlenessFallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: LoungeOfIdlenessWaveLoader(),
      ),
    );
  }
}

// ============================================================================
// ViewModel + Courier
// ============================================================================

class LoungeOfIdlenessBosunViewModel {
  final LoungeOfIdlenessDeviceProfile loungeOfIdlenessDeviceProfile;
  final LoungeOfIdlenessAnalyticsSpyService
  loungeOfIdlenessAnalyticsSpyService;

  LoungeOfIdlenessBosunViewModel({
    required this.loungeOfIdlenessDeviceProfile,
    required this.loungeOfIdlenessAnalyticsSpyService,
  });

  Map<String, dynamic> loungeOfIdlenessDeviceMap(String? fcmToken) =>
      loungeOfIdlenessDeviceProfile.loungeOfIdlenessToMap(
        fcmToken: fcmToken,
      );

  Map<String, dynamic> loungeOfIdlenessAppsFlyerPayload(
      String? token, {
        String? deepLink,
      }) =>
      <String, dynamic>{
        'content': <String, dynamic>{
          'af_data':
          loungeOfIdlenessAnalyticsSpyService.loungeOfIdlenessAppsFlyerData,
          'af_id':
          loungeOfIdlenessAnalyticsSpyService.loungeOfIdlenessAppsFlyerUid,
          'fb_app_name': 'sllounge',
          'app_name': 'sllounge',
          'deep': deepLink,
          'bundle_identifier': 'com.lougeof.ledes.louge.loungeoflendess',
          'app_version': '1.0.0',
          'apple_id': '6759056932',
          'fcm_token': token ?? 'no_token',
          'device_id':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessDeviceId ??
              'no_device',
          'instance_id':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessSessionId ??
              'no_instance',
          'platform':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessPlatformName ??
              'no_type',
          'os_version':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessOsVersion ??
              'no_os',
          'app_version':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessAppVersion ??
              'no_app',
          'language':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessLanguageCode ??
              'en',
          'timezone':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessTimezoneName ??
              'UTC',
          'push_enabled':
          loungeOfIdlenessDeviceProfile.loungeOfIdlenessPushEnabled,
          'useruid':
          loungeOfIdlenessAnalyticsSpyService.loungeOfIdlenessAppsFlyerUid,
        },
      };
}

class LoungeOfIdlenessCourierService {
  final LoungeOfIdlenessBosunViewModel loungeOfIdlenessBosunViewModel;
  final InAppWebViewController? Function()
  loungeOfIdlenessGetWebViewController;

  LoungeOfIdlenessCourierService({
    required this.loungeOfIdlenessBosunViewModel,
    required this.loungeOfIdlenessGetWebViewController,
  });

  Future<void> loungeOfIdlenessPutDeviceToLocalStorage(
      String? token) async {
    final InAppWebViewController? loungeOfIdlenessController =
    loungeOfIdlenessGetWebViewController();
    if (loungeOfIdlenessController == null) return;

    final Map<String, dynamic> loungeOfIdlenessMap =
    loungeOfIdlenessBosunViewModel.loungeOfIdlenessDeviceMap(token);
    await loungeOfIdlenessController.evaluateJavascript(
      source:
      "localStorage.setItem('app_data', JSON.stringify(${jsonEncode(loungeOfIdlenessMap)}));",
    );
  }

  Future<void> loungeOfIdlenessSendRawToPage(
      String? token, {
        String? deepLink,
      }) async {
    final InAppWebViewController? loungeOfIdlenessController =
    loungeOfIdlenessGetWebViewController();
    if (loungeOfIdlenessController == null) return;

    final Map<String, dynamic> loungeOfIdlenessPayload =
    loungeOfIdlenessBosunViewModel.loungeOfIdlenessAppsFlyerPayload(
      token,
      deepLink: deepLink,
    );
    final String loungeOfIdlenessJsonString =
    jsonEncode(loungeOfIdlenessPayload);

    LoungeOfIdlenessLoggerService().loungeOfIdlenessLogInfo(
        'SendRawData: $loungeOfIdlenessJsonString');

    await loungeOfIdlenessController.evaluateJavascript(
      source: 'sendRawData(${jsonEncode(loungeOfIdlenessJsonString)});',
    );
  }
}

// ============================================================================
// Статистика / переходы
// ============================================================================

Future<String> loungeOfIdlenessResolveFinalUrl(
    String startUrl, {
      int maxHops = 10,
    }) async {
  final HttpClient loungeOfIdlenessHttpClient = HttpClient();

  try {
    Uri loungeOfIdlenessCurrentUri = Uri.parse(startUrl);

    for (int loungeOfIdlenessIndex = 0;
    loungeOfIdlenessIndex < maxHops;
    loungeOfIdlenessIndex++) {
      final HttpClientRequest loungeOfIdlenessRequest =
      await loungeOfIdlenessHttpClient
          .getUrl(loungeOfIdlenessCurrentUri);
      loungeOfIdlenessRequest.followRedirects = false;
      final HttpClientResponse loungeOfIdlenessResponse =
      await loungeOfIdlenessRequest.close();

      if (loungeOfIdlenessResponse.isRedirect) {
        final String? loungeOfIdlenessLocationHeader =
        loungeOfIdlenessResponse.headers
            .value(HttpHeaders.locationHeader);
        if (loungeOfIdlenessLocationHeader == null ||
            loungeOfIdlenessLocationHeader.isEmpty) {
          break;
        }

        final Uri loungeOfIdlenessNextUri =
        Uri.parse(loungeOfIdlenessLocationHeader);
        loungeOfIdlenessCurrentUri =
        loungeOfIdlenessNextUri.hasScheme
            ? loungeOfIdlenessNextUri
            : loungeOfIdlenessCurrentUri
            .resolveUri(loungeOfIdlenessNextUri);
        continue;
      }

      return loungeOfIdlenessCurrentUri.toString();
    }

    return loungeOfIdlenessCurrentUri.toString();
  } catch (error) {
    debugPrint('goldenLuxuryResolveFinalUrl error: $error');
    return startUrl;
  } finally {
    loungeOfIdlenessHttpClient.close(force: true);
  }
}

Future<void> loungeOfIdlenessPostStat({
  required String event,
  required int timeStart,
  required String url,
  required int timeFinish,
  required String appSid,
  int? firstPageLoadTs,
}) async {
  try {
    final String loungeOfIdlenessResolvedUrl =
    await loungeOfIdlenessResolveFinalUrl(url);

    final Map<String, dynamic> loungeOfIdlenessPayload =
    <String, dynamic>{
      'event': event,
      'timestart': timeStart,
      'timefinsh': timeFinish,
      'url': loungeOfIdlenessResolvedUrl,
      'appleID': '6759056932',
      'open_count': '$appSid/$timeStart',
    };

    debugPrint('goldenLuxuryStat $loungeOfIdlenessPayload');

    final http.Response loungeOfIdlenessResponse = await http.post(
      Uri.parse('$loungeOfIdlenessStatEndpoint/$appSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(loungeOfIdlenessPayload),
    );

    debugPrint(
        'goldenLuxuryStat resp=${loungeOfIdlenessResponse.statusCode} body=${loungeOfIdlenessResponse.body}');
  } catch (error) {
    debugPrint('goldenLuxuryPostStat error: $error');
  }
}

// ============================================================================
// Главный WebView — Harbor
// ============================================================================

class LoungeOfIdlenessHarbor extends StatefulWidget {
  final String? loungeOfIdlenessSignal;

  const LoungeOfIdlenessHarbor({
    super.key,
    required this.loungeOfIdlenessSignal,
  });

  @override
  State<LoungeOfIdlenessHarbor> createState() =>
      _LoungeOfIdlenessHarborState();
}

class _LoungeOfIdlenessHarborState extends State<LoungeOfIdlenessHarbor>
    with WidgetsBindingObserver {
  InAppWebViewController? loungeOfIdlenessWebViewController;
  final String loungeOfIdlenessHomeUrl =
      'https://sub.sllounge.club/';

  int loungeOfIdlenessWebViewKeyCounter = 0;
  DateTime? loungeOfIdlenessSleepAt;
  bool loungeOfIdlenessVeilVisible = false;
  double loungeOfIdlenessWarmProgress = 0.0;
  late Timer loungeOfIdlenessWarmTimer;
  final int loungeOfIdlenessWarmSeconds = 6;
  bool loungeOfIdlenessCoverVisible = true;

  bool loungeOfIdlenessLoadedOnceSent = false;
  int? loungeOfIdlenessFirstPageTimestamp;

  LoungeOfIdlenessCourierService? loungeOfIdlenessCourierService;
  LoungeOfIdlenessBosunViewModel? loungeOfIdlenessBosunViewModel;

  String loungeOfIdlenessCurrentUrl = '';
  int loungeOfIdlenessStartLoadTimestamp = 0;

  final LoungeOfIdlenessDeviceProfile loungeOfIdlenessDeviceProfile =
  LoungeOfIdlenessDeviceProfile();
  final LoungeOfIdlenessAnalyticsSpyService
  loungeOfIdlenessAnalyticsSpyService =
  LoungeOfIdlenessAnalyticsSpyService();
  bool loungeOfIdlenessUseSafeArea = false;

  final Set<String> loungeOfIdlenessSpecialSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'viber',
    'skype',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
    'bnl',
  };

  final Set<String> loungeOfIdlenessExternalHosts = <String>{
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'm.me',
    'signal.me',
    'bnl.com',
    'www.bnl.com',
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'instagram.com',
    'www.instagram.com',
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'www.x.com',
  };

  String? loungeOfIdlenessDeepLinkFromPush;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loungeOfIdlenessFirstPageTimestamp =
        DateTime.now().millisecondsSinceEpoch;

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          loungeOfIdlenessCoverVisible = false;
        });
      }
    });

    Future<void>.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() {
        loungeOfIdlenessVeilVisible = true;
      });
    });

    loungeOfIdlenessBootHarbor();
  }

  Future<void> loungeOfIdlenessLoadLoadedFlag() async {
    final SharedPreferences loungeOfIdlenessPrefs =
    await SharedPreferences.getInstance();
    loungeOfIdlenessLoadedOnceSent =
        loungeOfIdlenessPrefs.getBool(loungeOfIdlenessLoadedOnceKey) ??
            false;
  }

  Future<void> loungeOfIdlenessSaveLoadedFlag() async {
    final SharedPreferences loungeOfIdlenessPrefs =
    await SharedPreferences.getInstance();
    await loungeOfIdlenessPrefs.setBool(
        loungeOfIdlenessLoadedOnceKey, true);
    loungeOfIdlenessLoadedOnceSent = true;
  }

  Future<void> loungeOfIdlenessLoadCachedDeep() async {
    try {
      final SharedPreferences loungeOfIdlenessPrefs =
      await SharedPreferences.getInstance();
      final String? loungeOfIdlenessCached =
      loungeOfIdlenessPrefs.getString(
          loungeOfIdlenessCachedDeepKey);
      if ((loungeOfIdlenessCached ?? '').isNotEmpty) {
        loungeOfIdlenessDeepLinkFromPush = loungeOfIdlenessCached;
      }
    } catch (_) {}
  }

  Future<void> loungeOfIdlenessSaveCachedDeep(String uri) async {
    try {
      final SharedPreferences loungeOfIdlenessPrefs =
      await SharedPreferences.getInstance();
      await loungeOfIdlenessPrefs.setString(
          loungeOfIdlenessCachedDeepKey, uri);
    } catch (_) {}
  }

  Future<void> loungeOfIdlenessSendLoadedOnce({
    required String url,
    required int timestart,
  }) async {
    if (loungeOfIdlenessLoadedOnceSent) {
      debugPrint('Loaded already sent, skip');
      return;
    }

    final int loungeOfIdlenessNow =
        DateTime.now().millisecondsSinceEpoch;

    await loungeOfIdlenessPostStat(
      event: 'Loaded',
      timeStart: timestart,
      timeFinish: loungeOfIdlenessNow,
      url: url,
      appSid: loungeOfIdlenessAnalyticsSpyService
          .loungeOfIdlenessAppsFlyerUid,
      firstPageLoadTs: loungeOfIdlenessFirstPageTimestamp,
    );

    await loungeOfIdlenessSaveLoadedFlag();
  }

  void loungeOfIdlenessBootHarbor() {
    loungeOfIdlenessStartWarmProgress();
    loungeOfIdlenessWireFcmHandlers();
    loungeOfIdlenessAnalyticsSpyService.loungeOfIdlenessStartTracking(
      onUpdate: () => setState(() {}),
    );
    loungeOfIdlenessBindNotificationTap();
    loungeOfIdlenessPrepareDeviceProfile();

    Future<void>.delayed(const Duration(seconds: 6), () async {
      await loungeOfIdlenessPushDeviceInfo();
      await loungeOfIdlenessPushAppsFlyerData();
    });
  }

  void loungeOfIdlenessWireFcmHandlers() {
    FirebaseMessaging.onMessage
        .listen((RemoteMessage loungeOfIdlenessMessage) async {
      final dynamic loungeOfIdlenessLink =
      loungeOfIdlenessMessage.data['uri'];
      if (loungeOfIdlenessLink != null) {
        final String loungeOfIdlenessUri =
        loungeOfIdlenessLink.toString();
        loungeOfIdlenessDeepLinkFromPush = loungeOfIdlenessUri;
        await loungeOfIdlenessSaveCachedDeep(loungeOfIdlenessUri);
        loungeOfIdlenessNavigateToUri(loungeOfIdlenessUri);
      } else {
        loungeOfIdlenessResetHomeAfterDelay();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(
            (RemoteMessage loungeOfIdlenessMessage) async {
          final dynamic loungeOfIdlenessLink =
          loungeOfIdlenessMessage.data['uri'];
          if (loungeOfIdlenessLink != null) {
            final String loungeOfIdlenessUri =
            loungeOfIdlenessLink.toString();
            loungeOfIdlenessDeepLinkFromPush = loungeOfIdlenessUri;
            await loungeOfIdlenessSaveCachedDeep(loungeOfIdlenessUri);
            loungeOfIdlenessNavigateToUri(loungeOfIdlenessUri);
          } else {
            loungeOfIdlenessResetHomeAfterDelay();
          }
        });
  }

  void loungeOfIdlenessBindNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNotificationTap') {
        final Map<String, dynamic> loungeOfIdlenessPayload =
        Map<String, dynamic>.from(call.arguments);
        if (loungeOfIdlenessPayload['uri'] != null &&
            !loungeOfIdlenessPayload['uri']
                .toString()
                .contains('Нет URI')) {
          final String loungeOfIdlenessUri =
          loungeOfIdlenessPayload['uri'].toString();
          loungeOfIdlenessDeepLinkFromPush = loungeOfIdlenessUri;
          await loungeOfIdlenessSaveCachedDeep(loungeOfIdlenessUri);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext context) =>
                  LoungeOfIdlenessTableView(loungeOfIdlenessUri),
            ),
                (Route<dynamic> route) => false,
          );
        }
      }
    });
  }

  Future<void> loungeOfIdlenessPrepareDeviceProfile() async {
    try {
      await loungeOfIdlenessDeviceProfile.loungeOfIdlenessInitialize();

      final FirebaseMessaging loungeOfIdlenessMessaging =
          FirebaseMessaging.instance;
      final NotificationSettings loungeOfIdlenessSettings =
      await loungeOfIdlenessMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      loungeOfIdlenessDeviceProfile.loungeOfIdlenessPushEnabled =
          loungeOfIdlenessSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              loungeOfIdlenessSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;

      await loungeOfIdlenessLoadLoadedFlag();
      await loungeOfIdlenessLoadCachedDeep();

      loungeOfIdlenessBosunViewModel = LoungeOfIdlenessBosunViewModel(
        loungeOfIdlenessDeviceProfile: loungeOfIdlenessDeviceProfile,
        loungeOfIdlenessAnalyticsSpyService:
        loungeOfIdlenessAnalyticsSpyService,
      );

      loungeOfIdlenessCourierService =
          LoungeOfIdlenessCourierService(
            loungeOfIdlenessBosunViewModel:
            loungeOfIdlenessBosunViewModel!,
            loungeOfIdlenessGetWebViewController: () =>
            loungeOfIdlenessWebViewController,
          );
    } catch (error) {
      LoungeOfIdlenessLoggerService().loungeOfIdlenessLogError(
          'prepareDeviceProfile fail: $error');
    }
  }

  void loungeOfIdlenessNavigateToUri(String link) async {
    try {
      await loungeOfIdlenessWebViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(link)),
      );
    } catch (error) {
      LoungeOfIdlenessLoggerService()
          .loungeOfIdlenessLogError('navigate error: $error');
    }
  }

  void loungeOfIdlenessResetHomeAfterDelay() {
    Future<void>.delayed(const Duration(seconds: 3), () {
      try {
        loungeOfIdlenessWebViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(loungeOfIdlenessHomeUrl)),
        );
      } catch (_) {}
    });
  }

  Future<void> loungeOfIdlenessPushDeviceInfo() async {
    final LoungeOfIdlenessAppBloc loungeOfIdlenessBloc =
    context.read<LoungeOfIdlenessAppBloc>();
    final String? loungeOfIdlenessBlocToken =
        loungeOfIdlenessBloc.state.loungeOfIdlenessFcmToken;

    final String? token =
    (widget.loungeOfIdlenessSignal != null &&
        widget.loungeOfIdlenessSignal!.isNotEmpty)
        ? widget.loungeOfIdlenessSignal
        : loungeOfIdlenessBlocToken;

    LoungeOfIdlenessLoggerService()
        .loungeOfIdlenessLogInfo('TOKEN ship $token');
    try {
      await loungeOfIdlenessCourierService
          ?.loungeOfIdlenessPutDeviceToLocalStorage(token);
    } catch (error) {
      LoungeOfIdlenessLoggerService()
          .loungeOfIdlenessLogError('pushDeviceInfo error: $error');
    }
  }

  Future<void> loungeOfIdlenessPushAppsFlyerData() async {
    final LoungeOfIdlenessAppBloc loungeOfIdlenessBloc =
    context.read<LoungeOfIdlenessAppBloc>();
    final String? loungeOfIdlenessBlocToken =
        loungeOfIdlenessBloc.state.loungeOfIdlenessFcmToken;

    final String? token =
    (widget.loungeOfIdlenessSignal != null &&
        widget.loungeOfIdlenessSignal!.isNotEmpty)
        ? widget.loungeOfIdlenessSignal
        : loungeOfIdlenessBlocToken;

    try {
      await loungeOfIdlenessCourierService
          ?.loungeOfIdlenessSendRawToPage(
        token,
        deepLink: loungeOfIdlenessDeepLinkFromPush,
      );
    } catch (error) {
      LoungeOfIdlenessLoggerService().loungeOfIdlenessLogError(
          'pushAppsFlyerData error: $error');
    }
  }

  void loungeOfIdlenessStartWarmProgress() {
    int loungeOfIdlenessTick = 0;
    loungeOfIdlenessWarmProgress = 0.0;

    loungeOfIdlenessWarmTimer =
        Timer.periodic(const Duration(milliseconds: 100),
                (Timer timer) {
              if (!mounted) return;

              setState(() {
                loungeOfIdlenessTick++;
                loungeOfIdlenessWarmProgress =
                    loungeOfIdlenessTick / (loungeOfIdlenessWarmSeconds * 10);

                if (loungeOfIdlenessWarmProgress >= 1.0) {
                  loungeOfIdlenessWarmProgress = 1.0;
                  loungeOfIdlenessWarmTimer.cancel();
                }
              });
            });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      loungeOfIdlenessSleepAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      if (Platform.isIOS && loungeOfIdlenessSleepAt != null) {
        final DateTime loungeOfIdlenessNow = DateTime.now();
        final Duration loungeOfIdlenessDrift =
        loungeOfIdlenessNow.difference(loungeOfIdlenessSleepAt!);

        if (loungeOfIdlenessDrift > const Duration(minutes: 25)) {
          loungeOfIdlenessReboardHarbor();
        }
      }
      loungeOfIdlenessSleepAt = null;
    }
  }

  void loungeOfIdlenessReboardHarbor() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<Widget>(
          builder: (BuildContext context) => LoungeOfIdlenessHarbor(
            loungeOfIdlenessSignal: widget.loungeOfIdlenessSignal,
          ),
        ),
            (Route<dynamic> route) => false,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    loungeOfIdlenessWarmTimer.cancel();
    super.dispose();
  }

  bool loungeOfIdlenessIsBareEmail(Uri uri) {
    final String loungeOfIdlenessScheme = uri.scheme;
    if (loungeOfIdlenessScheme.isNotEmpty) return false;
    final String loungeOfIdlenessRaw = uri.toString();
    return loungeOfIdlenessRaw.contains('@') &&
        !loungeOfIdlenessRaw.contains(' ');
  }

  Uri loungeOfIdlenessToMailto(Uri uri) {
    final String loungeOfIdlenessFull = uri.toString();
    final List<String> loungeOfIdlenessParts =
    loungeOfIdlenessFull.split('?');
    final String loungeOfIdlenessEmail =
        loungeOfIdlenessParts.first;
    final Map<String, String> loungeOfIdlenessQueryParams =
    loungeOfIdlenessParts.length > 1
        ? Uri.splitQueryString(loungeOfIdlenessParts[1])
        : <String, String>{};

    return Uri(
      scheme: 'mailto',
      path: loungeOfIdlenessEmail,
      queryParameters: loungeOfIdlenessQueryParams.isEmpty
          ? null
          : loungeOfIdlenessQueryParams,
    );
  }

  bool loungeOfIdlenessIsPlatformLink(Uri uri) {
    final String loungeOfIdlenessScheme =
    uri.scheme.toLowerCase();
    if (loungeOfIdlenessSpecialSchemes.contains(
        loungeOfIdlenessScheme)) {
      return true;
    }

    if (loungeOfIdlenessScheme == 'http' ||
        loungeOfIdlenessScheme == 'https') {
      final String loungeOfIdlenessHost =
      uri.host.toLowerCase();

      if (loungeOfIdlenessExternalHosts
          .contains(loungeOfIdlenessHost)) {
        return true;
      }

      if (loungeOfIdlenessHost.endsWith('t.me')) return true;
      if (loungeOfIdlenessHost.endsWith('wa.me')) return true;
      if (loungeOfIdlenessHost.endsWith('m.me')) return true;
      if (loungeOfIdlenessHost.endsWith('signal.me')) return true;
      if (loungeOfIdlenessHost.endsWith('facebook.com')) return true;
      if (loungeOfIdlenessHost.endsWith('instagram.com')) return true;
      if (loungeOfIdlenessHost.endsWith('twitter.com')) return true;
      if (loungeOfIdlenessHost.endsWith('x.com')) return true;
    }

    return false;
  }

  String loungeOfIdlenessDigitsOnly(String source) =>
      source.replaceAll(RegExp(r'[^0-9+]'), '');

  Uri loungeOfIdlenessHttpizePlatformUri(Uri uri) {
    final String loungeOfIdlenessScheme =
    uri.scheme.toLowerCase();

    if (loungeOfIdlenessScheme == 'tg' ||
        loungeOfIdlenessScheme == 'telegram') {
      final Map<String, String> loungeOfIdlenessQp =
          uri.queryParameters;
      final String? loungeOfIdlenessDomain =
      loungeOfIdlenessQp['domain'];

      if (loungeOfIdlenessDomain != null &&
          loungeOfIdlenessDomain.isNotEmpty) {
        return Uri.https(
          't.me',
          '/$loungeOfIdlenessDomain',
          <String, String>{
            if (loungeOfIdlenessQp['start'] != null)
              'start': loungeOfIdlenessQp['start']!,
          },
        );
      }

      final String loungeOfIdlenessPath =
      uri.path.isNotEmpty ? uri.path : '';

      return Uri.https(
        't.me',
        '/$loungeOfIdlenessPath',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    if ((loungeOfIdlenessScheme == 'http' ||
        loungeOfIdlenessScheme == 'https') &&
        uri.host.toLowerCase().endsWith('t.me')) {
      return uri;
    }

    if (loungeOfIdlenessScheme == 'viber') {
      return uri;
    }

    if (loungeOfIdlenessScheme == 'whatsapp') {
      final Map<String, String> loungeOfIdlenessQp =
          uri.queryParameters;
      final String? loungeOfIdlenessPhone =
      loungeOfIdlenessQp['phone'];
      final String? loungeOfIdlenessText =
      loungeOfIdlenessQp['text'];

      if (loungeOfIdlenessPhone != null &&
          loungeOfIdlenessPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${loungeOfIdlenessDigitsOnly(loungeOfIdlenessPhone)}',
          <String, String>{
            if (loungeOfIdlenessText != null &&
                loungeOfIdlenessText.isNotEmpty)
              'text': loungeOfIdlenessText,
          },
        );
      }

      return Uri.https(
        'wa.me',
        '/',
        <String, String>{
          if (loungeOfIdlenessText != null &&
              loungeOfIdlenessText.isNotEmpty)
            'text': loungeOfIdlenessText,
        },
      );
    }

    if ((loungeOfIdlenessScheme == 'http' ||
        loungeOfIdlenessScheme == 'https') &&
        (uri.host.toLowerCase().endsWith('wa.me') ||
            uri.host.toLowerCase().endsWith('whatsapp.com'))) {
      return uri;
    }

    if (loungeOfIdlenessScheme == 'skype') {
      return uri;
    }

    if (loungeOfIdlenessScheme == 'fb-messenger') {
      final String loungeOfIdlenessPath =
      uri.pathSegments.isNotEmpty
          ? uri.pathSegments.join('/')
          : '';
      final Map<String, String> loungeOfIdlenessQp =
          uri.queryParameters;

      final String loungeOfIdlenessId =
          loungeOfIdlenessQp['id'] ??
              loungeOfIdlenessQp['user'] ??
              loungeOfIdlenessPath;

      if (loungeOfIdlenessId.isNotEmpty) {
        return Uri.https(
          'm.me',
          '/$loungeOfIdlenessId',
          uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      }

      return Uri.https(
        'm.me',
        '/',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    if (loungeOfIdlenessScheme == 'sgnl') {
      final Map<String, String> loungeOfIdlenessQp =
          uri.queryParameters;
      final String? loungeOfIdlenessPhone =
      loungeOfIdlenessQp['phone'];
      final String? loungeOfIdlenessUsername =
      loungeOfIdlenessQp['username'];

      if (loungeOfIdlenessPhone != null &&
          loungeOfIdlenessPhone.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#p/${loungeOfIdlenessDigitsOnly(loungeOfIdlenessPhone)}',
        );
      }

      if (loungeOfIdlenessUsername != null &&
          loungeOfIdlenessUsername.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#u/$loungeOfIdlenessUsername',
        );
      }

      final String loungeOfIdlenessPath =
      uri.pathSegments.join('/');
      if (loungeOfIdlenessPath.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/$loungeOfIdlenessPath',
          uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      }

      return uri;
    }

    if (loungeOfIdlenessScheme == 'tel') {
      return Uri.parse(
          'tel:${loungeOfIdlenessDigitsOnly(uri.path)}');
    }

    if (loungeOfIdlenessScheme == 'mailto') {
      return uri;
    }

    if (loungeOfIdlenessScheme == 'bnl') {
      final String loungeOfIdlenessNewPath =
      uri.path.isNotEmpty ? uri.path : '';
      return Uri.https(
        'bnl.com',
        '/$loungeOfIdlenessNewPath',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    return uri;
  }

  Future<bool> loungeOfIdlenessOpenMailWeb(Uri mailto) async {
    final Uri loungeOfIdlenessGmailUri =
    loungeOfIdlenessGmailizeMailto(mailto);
    return loungeOfIdlenessOpenWeb(loungeOfIdlenessGmailUri);
  }

  Uri loungeOfIdlenessGmailizeMailto(Uri mailUri) {
    final Map<String, String> loungeOfIdlenessQueryParams =
        mailUri.queryParameters;

    final Map<String, String> loungeOfIdlenessParams =
    <String, String>{
      'view': 'cm',
      'fs': '1',
      if (mailUri.path.isNotEmpty) 'to': mailUri.path,
      if ((loungeOfIdlenessQueryParams['subject'] ?? '').isNotEmpty)
        'su': loungeOfIdlenessQueryParams['subject']!,
      if ((loungeOfIdlenessQueryParams['body'] ?? '').isNotEmpty)
        'body': loungeOfIdlenessQueryParams['body']!,
      if ((loungeOfIdlenessQueryParams['cc'] ?? '').isNotEmpty)
        'cc': loungeOfIdlenessQueryParams['cc']!,
      if ((loungeOfIdlenessQueryParams['bcc'] ?? '').isNotEmpty)
        'bcc': loungeOfIdlenessQueryParams['bcc']!,
    };

    return Uri.https('mail.google.com', '/mail/', loungeOfIdlenessParams);
  }

  Future<bool> loungeOfIdlenessOpenWeb(Uri uri) async {
    try {
      if (await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      )) {
        return true;
      }

      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('openInAppBrowser error: $error; url=$uri');
      try {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> loungeOfIdlenessOpenExternal(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('openExternal error: $error; url=$uri');
      return false;
    }
  }

  void loungeOfIdlenessHandleServerSavedata(String savedata) {
    debugPrint('onServerResponse savedata: $savedata');

    if (savedata == 'false') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<Widget>(
          builder: (BuildContext context) => LoungeOfIdlenessApp(),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (savedata == 'true') {
      // остаёмся на вебе
    }
  }

  @override
  Widget build(BuildContext context) {
    loungeOfIdlenessBindNotificationTap();

    Widget loungeOfIdlenessContent = Stack(
      children: <Widget>[
        if (loungeOfIdlenessCoverVisible)
          const LoungeOfIdlenessWaveLoader()
        else
          Container(
            color: Colors.black,
            child: Stack(
              children: <Widget>[
                InAppWebView(
                  key:
                  ValueKey<int>(loungeOfIdlenessWebViewKeyCounter),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    disableDefaultErrorPage: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    allowsPictureInPictureMediaPlayback: true,
                    useOnDownloadStart: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    useShouldOverrideUrlLoading: true,
                    supportMultipleWindows: true,
                    transparentBackground: true,
                  ),
                  initialUrlRequest: URLRequest(
                    url: WebUri(loungeOfIdlenessHomeUrl),
                  ),
                  onWebViewCreated:
                      (InAppWebViewController controller) {
                    loungeOfIdlenessWebViewController =
                        controller;

                    loungeOfIdlenessBosunViewModel ??=
                        LoungeOfIdlenessBosunViewModel(
                          loungeOfIdlenessDeviceProfile:
                          loungeOfIdlenessDeviceProfile,
                          loungeOfIdlenessAnalyticsSpyService:
                          loungeOfIdlenessAnalyticsSpyService,
                        );

                    loungeOfIdlenessCourierService ??=
                        LoungeOfIdlenessCourierService(
                          loungeOfIdlenessBosunViewModel:
                          loungeOfIdlenessBosunViewModel!,
                          loungeOfIdlenessGetWebViewController: () =>
                          loungeOfIdlenessWebViewController,
                        );

                    controller.addJavaScriptHandler(
                      handlerName: 'onServerResponse',
                      callback: (List<dynamic> args) {
                        debugPrint(
                            'onServerResponse raw args: $args');

                        if (args.isEmpty) return null;

                        try {
                          if (args[0] is Map) {
                            final dynamic loungeOfIdlenessRaw =
                            (args[0] as Map)['savedata'];

                            debugPrint(
                                "saveDATA ${loungeOfIdlenessRaw.toString()}");
                            loungeOfIdlenessHandleServerSavedata(
                              loungeOfIdlenessRaw?.toString() ??
                                  '',
                            );
                          } else if (args[0] is String) {
                            loungeOfIdlenessHandleServerSavedata(
                                args[0] as String);
                          } else if (args[0] is bool) {
                            loungeOfIdlenessHandleServerSavedata(
                                (args[0] as bool).toString());
                          }
                        } catch (e, st) {
                          debugPrint(
                              'onServerResponse error: $e\n$st');
                        }

                        return null;
                      },
                    );
                  },
                  onLoadStart: (
                      InAppWebViewController controller,
                      Uri? uri,
                      ) async {
                    setState(() {
                      loungeOfIdlenessStartLoadTimestamp =
                          DateTime.now().millisecondsSinceEpoch;
                    });

                    final Uri? loungeOfIdlenessViewUri = uri;
                    if (loungeOfIdlenessViewUri != null) {
                      if (loungeOfIdlenessIsBareEmail(
                          loungeOfIdlenessViewUri)) {
                        try {
                          await controller.stopLoading();
                        } catch (_) {}
                        final Uri loungeOfIdlenessMailto =
                        loungeOfIdlenessToMailto(
                            loungeOfIdlenessViewUri);
                        await loungeOfIdlenessOpenMailWeb(
                            loungeOfIdlenessMailto);
                        return;
                      }

                      final String loungeOfIdlenessScheme =
                      loungeOfIdlenessViewUri.scheme
                          .toLowerCase();
                      if (loungeOfIdlenessScheme != 'http' &&
                          loungeOfIdlenessScheme != 'https') {
                        try {
                          await controller.stopLoading();
                        } catch (_) {}
                      }
                    }
                  },
                  onLoadError: (
                      InAppWebViewController controller,
                      Uri? uri,
                      int code,
                      String message,
                      ) async {
                    final int loungeOfIdlenessNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String loungeOfIdlenessEvent =
                        'InAppWebViewError(code=$code, message=$message)';

                    await loungeOfIdlenessPostStat(
                      event: loungeOfIdlenessEvent,
                      timeStart: loungeOfIdlenessNow,
                      timeFinish: loungeOfIdlenessNow,
                      url: uri?.toString() ?? '',
                      appSid:
                      loungeOfIdlenessAnalyticsSpyService
                          .loungeOfIdlenessAppsFlyerUid,
                      firstPageLoadTs:
                      loungeOfIdlenessFirstPageTimestamp,
                    );
                  },
                  onReceivedError: (
                      InAppWebViewController controller,
                      WebResourceRequest request,
                      WebResourceError error,
                      ) async {
                    final int loungeOfIdlenessNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String loungeOfIdlenessDescription =
                    (error.description ?? '').toString();
                    final String loungeOfIdlenessEvent =
                        'WebResourceError(code=$error, message=$loungeOfIdlenessDescription)';

                    await loungeOfIdlenessPostStat(
                      event: loungeOfIdlenessEvent,
                      timeStart: loungeOfIdlenessNow,
                      timeFinish: loungeOfIdlenessNow,
                      url: request.url?.toString() ?? '',
                      appSid:
                      loungeOfIdlenessAnalyticsSpyService
                          .loungeOfIdlenessAppsFlyerUid,
                      firstPageLoadTs:
                      loungeOfIdlenessFirstPageTimestamp,
                    );
                  },
                  onLoadStop: (
                      InAppWebViewController controller,
                      Uri? uri,
                      ) async {
                    await loungeOfIdlenessPushDeviceInfo();
                    await loungeOfIdlenessPushAppsFlyerData();

                    setState(() {
                      loungeOfIdlenessCurrentUrl =
                          uri.toString();
                    });

                    Future<void>.delayed(
                      const Duration(seconds: 20),
                          () {
                        loungeOfIdlenessSendLoadedOnce(
                          url:
                          loungeOfIdlenessCurrentUrl.toString(),
                          timestart:
                          loungeOfIdlenessStartLoadTimestamp,
                        );
                      },
                    );
                  },
                  shouldOverrideUrlLoading: (
                      InAppWebViewController controller,
                      NavigationAction action,
                      ) async {
                    final Uri? loungeOfIdlenessUri =
                        action.request.url;
                    if (loungeOfIdlenessUri == null) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    if (loungeOfIdlenessIsBareEmail(
                        loungeOfIdlenessUri)) {
                      final Uri loungeOfIdlenessMailto =
                      loungeOfIdlenessToMailto(
                          loungeOfIdlenessUri);
                      await loungeOfIdlenessOpenMailWeb(
                          loungeOfIdlenessMailto);
                      return NavigationActionPolicy.CANCEL;
                    }

                    final String loungeOfIdlenessScheme =
                    loungeOfIdlenessUri.scheme.toLowerCase();

                    if (loungeOfIdlenessScheme == 'mailto') {
                      await loungeOfIdlenessOpenMailWeb(
                          loungeOfIdlenessUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (loungeOfIdlenessScheme == 'tel') {
                      await launchUrl(
                        loungeOfIdlenessUri,
                        mode: LaunchMode.externalApplication,
                      );
                      return NavigationActionPolicy.CANCEL;
                    }

                    final String loungeOfIdlenessHost =
                    loungeOfIdlenessUri.host.toLowerCase();
                    final bool loungeOfIdlenessIsSocial =
                        loungeOfIdlenessHost
                            .endsWith('facebook.com') ||
                            loungeOfIdlenessHost
                                .endsWith('instagram.com') ||
                            loungeOfIdlenessHost
                                .endsWith('twitter.com') ||
                            loungeOfIdlenessHost
                                .endsWith('x.com');

                    if (loungeOfIdlenessIsSocial) {
                      await loungeOfIdlenessOpenExternal(
                          loungeOfIdlenessUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (loungeOfIdlenessIsPlatformLink(
                        loungeOfIdlenessUri)) {
                      final Uri loungeOfIdlenessWebUri =
                      loungeOfIdlenessHttpizePlatformUri(
                          loungeOfIdlenessUri);
                      await loungeOfIdlenessOpenExternal(
                          loungeOfIdlenessWebUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (loungeOfIdlenessScheme != 'http' &&
                        loungeOfIdlenessScheme != 'https') {
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onCreateWindow: (
                      InAppWebViewController controller,
                      CreateWindowAction request,
                      ) async {
                    final Uri? loungeOfIdlenessUri =
                        request.request.url;
                    if (loungeOfIdlenessUri == null) {
                      return false;
                    }

                    if (loungeOfIdlenessIsBareEmail(
                        loungeOfIdlenessUri)) {
                      final Uri loungeOfIdlenessMailto =
                      loungeOfIdlenessToMailto(
                          loungeOfIdlenessUri);
                      await loungeOfIdlenessOpenMailWeb(
                          loungeOfIdlenessMailto);
                      return false;
                    }

                    final String loungeOfIdlenessScheme =
                    loungeOfIdlenessUri.scheme.toLowerCase();

                    if (loungeOfIdlenessScheme == 'mailto') {
                      await loungeOfIdlenessOpenMailWeb(
                          loungeOfIdlenessUri);
                      return false;
                    }

                    if (loungeOfIdlenessScheme == 'tel') {
                      await launchUrl(
                        loungeOfIdlenessUri,
                        mode: LaunchMode.externalApplication,
                      );
                      return false;
                    }

                    final String loungeOfIdlenessHost =
                    loungeOfIdlenessUri.host.toLowerCase();
                    final bool loungeOfIdlenessIsSocial =
                        loungeOfIdlenessHost
                            .endsWith('facebook.com') ||
                            loungeOfIdlenessHost
                                .endsWith('instagram.com') ||
                            loungeOfIdlenessHost
                                .endsWith('twitter.com') ||
                            loungeOfIdlenessHost.endsWith('x.com');

                    if (loungeOfIdlenessIsSocial) {
                      await loungeOfIdlenessOpenExternal(
                          loungeOfIdlenessUri);
                      return false;
                    }

                    if (loungeOfIdlenessIsPlatformLink(
                        loungeOfIdlenessUri)) {
                      final Uri loungeOfIdlenessWebUri =
                      loungeOfIdlenessHttpizePlatformUri(
                          loungeOfIdlenessUri);
                      await loungeOfIdlenessOpenExternal(
                          loungeOfIdlenessWebUri);
                      return false;
                    }

                    if (loungeOfIdlenessScheme == 'http' ||
                        loungeOfIdlenessScheme == 'https') {
                      controller.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(
                              loungeOfIdlenessUri.toString()),
                        ),
                      );
                    }

                    return false;
                  },
                  onDownloadStartRequest: (
                      InAppWebViewController controller,
                      DownloadStartRequest req,
                      ) async {
                    await loungeOfIdlenessOpenExternal(req.url);
                  },
                ),
                Visibility(
                  visible: !loungeOfIdlenessVeilVisible,
                  child: const LoungeOfIdlenessWaveLoader(),
                ),
              ],
            ),
          ),
      ],
    );

    if (loungeOfIdlenessUseSafeArea) {
      loungeOfIdlenessContent =
          SafeArea(child: loungeOfIdlenessContent);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: ColoredBox(
            color: Colors.black,
            child: loungeOfIdlenessContent,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// main()
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(
      loungeOfIdlenessFcmBackgroundHandler);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  tz_data.initializeTimeZones();

  final LoungeOfIdlenessDeviceProfile loungeOfIdlenessDeviceProfile =
  LoungeOfIdlenessDeviceProfile();
  final LoungeOfIdlenessAnalyticsSpyService
  loungeOfIdlenessAnalyticsSpyService =
  LoungeOfIdlenessAnalyticsSpyService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoungeOfIdlenessAppBloc>(
          create: (_) => LoungeOfIdlenessAppBloc(
            loungeOfIdlenessAnalyticsSpyService:
            loungeOfIdlenessAnalyticsSpyService,
            loungeOfIdlenessDeviceProfile:
            loungeOfIdlenessDeviceProfile,
          ),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoungeOfIdlenessHall(),
      ),
    ),
  );
}