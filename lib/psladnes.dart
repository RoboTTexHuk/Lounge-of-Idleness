import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart'
    show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Если эти классы есть в main.dart – оставь импорт.
import 'main.dart' show MafiaHarbor, CaptainHarbor, BillHarbor;

// ============================================================================
// Lounge of Idleness инфраструктура и паттерны
// ============================================================================

class LoungeOfIdlenessLogger {
  const LoungeOfIdlenessLogger();

  void loungeOfIdlenessLogInfo(Object message) =>
      debugPrint('[WheelLogger] $message');
  void loungeOfIdlenessLogWarn(Object message) =>
      debugPrint('[WheelLogger/WARN] $message');
  void loungeOfIdlenessLogError(Object message) =>
      debugPrint('[WheelLogger/ERR] $message');
}

class LoungeOfIdlenessVault {
  static final LoungeOfIdlenessVault loungeOfIdlenessInstance =
  LoungeOfIdlenessVault._loungeOfIdlenessInternal();
  LoungeOfIdlenessVault._loungeOfIdlenessInternal();
  factory LoungeOfIdlenessVault() => loungeOfIdlenessInstance;

  final LoungeOfIdlenessLogger loungeOfIdlenessLogger =
  const LoungeOfIdlenessLogger();
}

// ============================================================================
// Константы (статистика/кеш)
// ============================================================================

const String loungeOfIdlenessLoadedOnceKey = 'wheel_loaded_once';
const String loungeOfIdlenessStatEndpoint =
    'https://getgame.portalroullete.bar/stat';
const String loungeOfIdlenessCachedFcmKey = 'wheel_cached_fcm';

// ============================================================================
// Утилиты: LoungeOfIdlenessKit
// ============================================================================

class LoungeOfIdlenessKit {
  static bool loungeOfIdlenessLooksLikeBareMail(Uri uri) {
    final String loungeOfIdlenessScheme = uri.scheme;
    if (loungeOfIdlenessScheme.isNotEmpty) return false;
    final String loungeOfIdlenessRaw = uri.toString();
    return loungeOfIdlenessRaw.contains('@') &&
        !loungeOfIdlenessRaw.contains(' ');
  }

  static Uri loungeOfIdlenessToMailto(Uri uri) {
    final String loungeOfIdlenessFull = uri.toString();
    final List<String> loungeOfIdlenessBits =
    loungeOfIdlenessFull.split('?');
    final String loungeOfIdlenessWho = loungeOfIdlenessBits.first;
    final Map<String, String> loungeOfIdlenessQuery =
    loungeOfIdlenessBits.length > 1
        ? Uri.splitQueryString(loungeOfIdlenessBits[1])
        : <String, String>{};
    return Uri(
      scheme: 'mailto',
      path: loungeOfIdlenessWho,
      queryParameters:
      loungeOfIdlenessQuery.isEmpty ? null : loungeOfIdlenessQuery,
    );
  }

  static Uri loungeOfIdlenessGmailize(Uri loungeOfIdlenessMailUri) {
    final Map<String, String> loungeOfIdlenessQp =
        loungeOfIdlenessMailUri.queryParameters;
    final Map<String, String> loungeOfIdlenessParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (loungeOfIdlenessMailUri.path.isNotEmpty)
        'to': loungeOfIdlenessMailUri.path,
      if ((loungeOfIdlenessQp['subject'] ?? '').isNotEmpty)
        'su': loungeOfIdlenessQp['subject']!,
      if ((loungeOfIdlenessQp['body'] ?? '').isNotEmpty)
        'body': loungeOfIdlenessQp['body']!,
      if ((loungeOfIdlenessQp['cc'] ?? '').isNotEmpty)
        'cc': loungeOfIdlenessQp['cc']!,
      if ((loungeOfIdlenessQp['bcc'] ?? '').isNotEmpty)
        'bcc': loungeOfIdlenessQp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', loungeOfIdlenessParams);
  }

  static String loungeOfIdlenessDigitsOnly(String loungeOfIdlenessSource) =>
      loungeOfIdlenessSource.replaceAll(RegExp(r'[^0-9+]'), '');
}

// ============================================================================
// Сервис открытия ссылок: LoungeOfIdlenessLinker
// ============================================================================

class LoungeOfIdlenessLinker {
  static Future<bool> loungeOfIdlenessOpen(Uri loungeOfIdlenessUri) async {
    try {
      if (await launchUrl(
        loungeOfIdlenessUri,
        mode: LaunchMode.inAppBrowserView,
      )) {
        return true;
      }
      return await launchUrl(
        loungeOfIdlenessUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (loungeOfIdlenessError) {
      debugPrint(
          'WheelLinker error: $loungeOfIdlenessError; url=$loungeOfIdlenessUri');
      try {
        return await launchUrl(
          loungeOfIdlenessUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }
}

// ============================================================================
// FCM Background Handler
// ============================================================================

@pragma('vm:entry-point')
Future<void> loungeOfIdlenessFcmBackgroundHandler(
    RemoteMessage loungeOfIdlenessMessage) async {
  debugPrint("Spin ID: ${loungeOfIdlenessMessage.messageId}");
  debugPrint("Spin Data: ${loungeOfIdlenessMessage.data}");
}

// ============================================================================
// LoungeOfIdlenessDeviceProfile: информация об устройстве
// ============================================================================

class LoungeOfIdlenessDeviceProfile {
  String? loungeOfIdlenessDeviceId;
  String? loungeOfIdlenessSessionId = 'wheel-one-off';
  String? loungeOfIdlenessPlatformKind;
  String? loungeOfIdlenessOsBuild;
  String? loungeOfIdlenessAppVersion;
  String? loungeOfIdlenessLocaleCode;
  String? loungeOfIdlenessTimezoneName;
  bool loungeOfIdlenessPushEnabled = true;

  Future<void> loungeOfIdlenessInitialize() async {
    final DeviceInfoPlugin loungeOfIdlenessInfoPlugin =
    DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo loungeOfIdlenessAndroidInfo =
      await loungeOfIdlenessInfoPlugin.androidInfo;
      loungeOfIdlenessDeviceId = loungeOfIdlenessAndroidInfo.id;
      loungeOfIdlenessPlatformKind = 'android';
      loungeOfIdlenessOsBuild =
          loungeOfIdlenessAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo loungeOfIdlenessIosInfo =
      await loungeOfIdlenessInfoPlugin.iosInfo;
      loungeOfIdlenessDeviceId =
          loungeOfIdlenessIosInfo.identifierForVendor;
      loungeOfIdlenessPlatformKind = 'ios';
      loungeOfIdlenessOsBuild =
          loungeOfIdlenessIosInfo.systemVersion;
    }

    final PackageInfo loungeOfIdlenessPackageInfo =
    await PackageInfo.fromPlatform();
    loungeOfIdlenessAppVersion = loungeOfIdlenessPackageInfo.version;
    loungeOfIdlenessLocaleCode = Platform.localeName.split('_').first;
    loungeOfIdlenessTimezoneName = timezone.local.name;
    loungeOfIdlenessSessionId =
    'wheel-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final FirebaseMessaging loungeOfIdlenessFm =
          FirebaseMessaging.instance;
      final NotificationSettings loungeOfIdlenessSettings =
      await loungeOfIdlenessFm.getNotificationSettings();
      loungeOfIdlenessPushEnabled =
          loungeOfIdlenessSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              loungeOfIdlenessSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;
    } catch (_) {
      loungeOfIdlenessPushEnabled = false;
    }
  }

  Map<String, dynamic> loungeOfIdlenessAsMap({String? fcmToken}) => {
    'fcm_token': fcmToken ?? 'missing_token',
    'device_id': loungeOfIdlenessDeviceId ?? 'missing_id',
    'app_name': 'joiler',
    'instance_id': loungeOfIdlenessSessionId ?? 'missing_session',
    'platform': loungeOfIdlenessPlatformKind ?? 'missing_system',
    'os_version': loungeOfIdlenessOsBuild ?? 'missing_build',
    'app_version': loungeOfIdlenessAppVersion ?? 'missing_app',
    'language': loungeOfIdlenessLocaleCode ?? 'en',
    'timezone': loungeOfIdlenessTimezoneName ?? 'UTC',
    'push_enabled': loungeOfIdlenessPushEnabled,
  };
}

// ============================================================================
// AppsFlyer шпион: LoungeOfIdlenessSpy
// ============================================================================

class LoungeOfIdlenessSpy {
  AppsFlyerOptions? loungeOfIdlenessOptions;
  AppsflyerSdk? loungeOfIdlenessSdk;

  String loungeOfIdlenessAppsFlyerUid = '';
  String loungeOfIdlenessAppsFlyerData = '';

  void loungeOfIdlenessStart({VoidCallback? onUpdate}) {
    final AppsFlyerOptions loungeOfIdlenessOpts = AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6756072063',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    loungeOfIdlenessOptions = loungeOfIdlenessOpts;
    loungeOfIdlenessSdk = AppsflyerSdk(loungeOfIdlenessOpts);

    loungeOfIdlenessSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    loungeOfIdlenessSdk?.startSDK(
      onSuccess: () => LoungeOfIdlenessVault()
          .loungeOfIdlenessLogger
          .loungeOfIdlenessLogInfo('WheelSpy started'),
      onError: (loungeOfIdlenessCode, loungeOfIdlenessMsg) =>
          LoungeOfIdlenessVault()
              .loungeOfIdlenessLogger
              .loungeOfIdlenessLogError(
              'WheelSpy error $loungeOfIdlenessCode: $loungeOfIdlenessMsg'),
    );

    loungeOfIdlenessSdk?.onInstallConversionData((loungeOfIdlenessValue) {
      loungeOfIdlenessAppsFlyerData = loungeOfIdlenessValue.toString();
      onUpdate?.call();
    });

    loungeOfIdlenessSdk?.getAppsFlyerUID().then((loungeOfIdlenessValue) {
      loungeOfIdlenessAppsFlyerUid =
          loungeOfIdlenessValue.toString();
      onUpdate?.call();
    });
  }
}

// ============================================================================
// Мост для FCM токена: LoungeOfIdlenessFcmBridge
// ============================================================================

class LoungeOfIdlenessFcmBridge {
  final LoungeOfIdlenessLogger loungeOfIdlenessLog =
  const LoungeOfIdlenessLogger();
  String? loungeOfIdlenessToken;
  final List<void Function(String)> loungeOfIdlenessWaiters =
  <void Function(String)>[];

  String? get loungeOfIdlenessFcmToken => loungeOfIdlenessToken;

  LoungeOfIdlenessFcmBridge() {
    const MethodChannel('com.example.fcm/token')
        .setMethodCallHandler((MethodCall loungeOfIdlenessCall) async {
      if (loungeOfIdlenessCall.method == 'setToken') {
        final String loungeOfIdlenessTokenString =
        loungeOfIdlenessCall.arguments as String;
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
      final String? loungeOfIdlenessCached =
      loungeOfIdlenessPrefs.getString(loungeOfIdlenessCachedFcmKey);
      if (loungeOfIdlenessCached != null &&
          loungeOfIdlenessCached.isNotEmpty) {
        loungeOfIdlenessSetToken(
          loungeOfIdlenessCached,
          notify: false,
        );
      }
    } catch (_) {}
  }

  Future<void> loungeOfIdlenessPersistToken(
      String loungeOfIdlenessNewToken) async {
    try {
      final SharedPreferences loungeOfIdlenessPrefs =
      await SharedPreferences.getInstance();
      await loungeOfIdlenessPrefs.setString(
          loungeOfIdlenessCachedFcmKey, loungeOfIdlenessNewToken);
    } catch (_) {}
  }

  void loungeOfIdlenessSetToken(
      String loungeOfIdlenessNewToken, {
        bool notify = true,
      }) {
    loungeOfIdlenessToken = loungeOfIdlenessNewToken;
    loungeOfIdlenessPersistToken(loungeOfIdlenessNewToken);
    if (notify) {
      for (final void Function(String) loungeOfIdlenessCallback
      in List<void Function(String)>.from(
          loungeOfIdlenessWaiters)) {
        try {
          loungeOfIdlenessCallback(loungeOfIdlenessNewToken);
        } catch (loungeOfIdlenessErr) {
          loungeOfIdlenessLog.loungeOfIdlenessLogWarn(
              'fcm waiter error: $loungeOfIdlenessErr');
        }
      }
      loungeOfIdlenessWaiters.clear();
    }
  }

  Future<void> loungeOfIdlenessWaitForToken(
      Function(String loungeOfIdlenessTokenValue)
      loungeOfIdlenessOnToken,
      ) async {
    try {
      final FirebaseMessaging loungeOfIdlenessFm =
          FirebaseMessaging.instance;

      final NotificationSettings loungeOfIdlenessSettings =
      await loungeOfIdlenessFm.getNotificationSettings();
      if (loungeOfIdlenessSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined ||
          loungeOfIdlenessSettings.authorizationStatus ==
              AuthorizationStatus.denied) {
        await loungeOfIdlenessFm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if ((loungeOfIdlenessToken ?? '').isNotEmpty) {
        loungeOfIdlenessOnToken(loungeOfIdlenessToken!);
        return;
      }

      loungeOfIdlenessWaiters.add(loungeOfIdlenessOnToken);
    } catch (loungeOfIdlenessErr) {
      loungeOfIdlenessLog.loungeOfIdlenessLogError(
          'wheelWaitToken error: $loungeOfIdlenessErr');
    }
  }
}

// ============================================================================
// Новый Loader: LoungeOfIdlenessWaveLoader
// синяя надпись "Lounge" волной по буквам по центру экрана
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
    const Color loungeOfIdlenessBackground = Colors.black;
    const Color loungeOfIdlenessPrimaryBlue = Colors.lightBlueAccent;
    const String loungeOfIdlenessTitle = 'Lounge';

    return Scaffold(
      backgroundColor: loungeOfIdlenessBackground,
      body: Center(
        child: AnimatedBuilder(
          animation: loungeOfIdlenessWaveController,
          builder: (BuildContext context, Widget? child) {
            final double loungeOfIdlenessT =
                loungeOfIdlenessWaveController.value * 2 * 3.14159265;

            final List<Widget> loungeOfIdlenessLetters = <Widget>[];
            for (int loungeOfIdlenessIndex = 0;
            loungeOfIdlenessIndex < loungeOfIdlenessTitle.length;
            loungeOfIdlenessIndex++) {
              final String loungeOfIdlenessChar =
              loungeOfIdlenessTitle[loungeOfIdlenessIndex];
              final double loungeOfIdlenessPhase =
                  loungeOfIdlenessT + loungeOfIdlenessIndex * 0.6;
              final double loungeOfIdlenessDy =
                  -6.0 * (1 + (0.5 * (1 + MathUtils.sin(loungeOfIdlenessPhase))));
              final double loungeOfIdlenessOpacity =
                  0.7 + 0.3 * (1 + MathUtils.sin(loungeOfIdlenessPhase)) / 2;

              loungeOfIdlenessLetters.add(
                Transform.translate(
                  offset: Offset(0, loungeOfIdlenessDy),
                  child: Text(
                    loungeOfIdlenessChar,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: loungeOfIdlenessPrimaryBlue
                          .withOpacity(loungeOfIdlenessOpacity),
                      shadows: <Shadow>[
                        Shadow(
                          color: loungeOfIdlenessPrimaryBlue
                              .withOpacity(0.8 * loungeOfIdlenessOpacity),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: loungeOfIdlenessLetters,
            );
          },
        ),
      ),
    );
  }
}

// Вспомогательный утиль для синуса без импорта dart:math здесь
class MathUtils {
  static double sin(double value) => MathUtilsInternal.sin(value);
}

class MathUtilsInternal {
  static double sin(double x) {
    // простая обертка над dart:math sin, чтобы не засорять верхнюю часть файла
    return (x).sin();
  }
}

extension _LoungeOfIdlenessDoubleSin on double {
  double sin() => math.sin(this);
}

// ============================================================================
// Статистика
// ============================================================================

Future<String> loungeOfIdlenessFinalUrl(
    String loungeOfIdlenessStartUrl, {
      int maxHops = 10,
    }) async {
  final HttpClient loungeOfIdlenessClient = HttpClient();

  try {
    Uri loungeOfIdlenessCurrentUri = Uri.parse(loungeOfIdlenessStartUrl);

    for (int loungeOfIdlenessI = 0;
    loungeOfIdlenessI < maxHops;
    loungeOfIdlenessI++) {
      final HttpClientRequest loungeOfIdlenessRequest =
      await loungeOfIdlenessClient.getUrl(loungeOfIdlenessCurrentUri);
      loungeOfIdlenessRequest.followRedirects = false;
      final HttpClientResponse loungeOfIdlenessResponse =
      await loungeOfIdlenessRequest.close();

      if (loungeOfIdlenessResponse.isRedirect) {
        final String? loungeOfIdlenessLoc =
        loungeOfIdlenessResponse.headers
            .value(HttpHeaders.locationHeader);
        if (loungeOfIdlenessLoc == null ||
            loungeOfIdlenessLoc.isEmpty) break;

        final Uri loungeOfIdlenessNextUri =
        Uri.parse(loungeOfIdlenessLoc);
        loungeOfIdlenessCurrentUri = loungeOfIdlenessNextUri.hasScheme
            ? loungeOfIdlenessNextUri
            : loungeOfIdlenessCurrentUri
            .resolveUri(loungeOfIdlenessNextUri);
        continue;
      }

      return loungeOfIdlenessCurrentUri.toString();
    }

    return loungeOfIdlenessCurrentUri.toString();
  } catch (loungeOfIdlenessError) {
    debugPrint('wheelFinalUrl error: $loungeOfIdlenessError');
    return loungeOfIdlenessStartUrl;
  } finally {
    loungeOfIdlenessClient.close(force: true);
  }
}

Future<void> loungeOfIdlenessPostStat({
  required String event,
  required int timeStart,
  required String url,
  required int timeFinish,
  required String appSid,
  int? firstPageTs,
}) async {
  try {
    final String loungeOfIdlenessResolvedUrl =
    await loungeOfIdlenessFinalUrl(url);
    final Map<String, dynamic> loungeOfIdlenessPayload =
    <String, dynamic>{
      'event': event,
      'timestart': timeStart,
      'timefinsh': timeFinish,
      'url': loungeOfIdlenessResolvedUrl,
      'appleID': '6755681349',
      'open_count': '$appSid/$timeStart',
    };

    debugPrint('wheelStat $loungeOfIdlenessPayload');

    final http.Response loungeOfIdlenessResp = await http.post(
      Uri.parse('$loungeOfIdlenessStatEndpoint/$appSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(loungeOfIdlenessPayload),
    );

    debugPrint(
        'wheelStat resp=${loungeOfIdlenessResp.statusCode} body=${loungeOfIdlenessResp.body}');
  } catch (loungeOfIdlenessError) {
    debugPrint('wheelPostStat error: $loungeOfIdlenessError');
  }
}

// ============================================================================
// WebView-экран: LoungeOfIdlenessTableView
// ============================================================================

class LoungeOfIdlenessTableView extends StatefulWidget
    with WidgetsBindingObserver {
  String loungeOfIdlenessStartingUrl;
  LoungeOfIdlenessTableView(this.loungeOfIdlenessStartingUrl, {super.key});

  @override
  State<LoungeOfIdlenessTableView> createState() =>
      _LoungeOfIdlenessTableViewState(loungeOfIdlenessStartingUrl);
}

class _LoungeOfIdlenessTableViewState
    extends State<LoungeOfIdlenessTableView> with WidgetsBindingObserver {
  _LoungeOfIdlenessTableViewState(this.loungeOfIdlenessCurrentUrl);

  final LoungeOfIdlenessVault loungeOfIdlenessVault =
  LoungeOfIdlenessVault();

  late InAppWebViewController loungeOfIdlenessWebViewController;
  String? loungeOfIdlenessPushToken;
  final LoungeOfIdlenessDeviceProfile loungeOfIdlenessDeviceProfile =
  LoungeOfIdlenessDeviceProfile();
  final LoungeOfIdlenessSpy loungeOfIdlenessSpy =
  LoungeOfIdlenessSpy();

  bool loungeOfIdlenessOverlayBusy = false;
  String loungeOfIdlenessCurrentUrl;
  DateTime? loungeOfIdlenessLastPausedAt;

  bool loungeOfIdlenessLoadedOnceSent = false;
  int? loungeOfIdlenessFirstPageTimestamp;
  int loungeOfIdlenessStartLoadTimestamp = 0;

  final Set<String> loungeOfIdlenessExternalHosts = <String>{
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
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

  final Set<String> loungeOfIdlenessExternalSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'bnl',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onBackgroundMessage(
        loungeOfIdlenessFcmBackgroundHandler);

    loungeOfIdlenessFirstPageTimestamp =
        DateTime.now().millisecondsSinceEpoch;

    loungeOfIdlenessInitPushAndGetToken();
    loungeOfIdlenessDeviceProfile.loungeOfIdlenessInitialize();
    loungeOfIdlenessWireForegroundPushHandlers();
    loungeOfIdlenessBindPlatformNotificationTap();
    loungeOfIdlenessSpy.loungeOfIdlenessStart(onUpdate: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState loungeOfIdlenessState) {
    if (loungeOfIdlenessState == AppLifecycleState.paused) {
      loungeOfIdlenessLastPausedAt = DateTime.now();
    }
    if (loungeOfIdlenessState == AppLifecycleState.resumed) {
      if (Platform.isIOS && loungeOfIdlenessLastPausedAt != null) {
        final DateTime loungeOfIdlenessNow = DateTime.now();
        final Duration loungeOfIdlenessDrift =
        loungeOfIdlenessNow.difference(
            loungeOfIdlenessLastPausedAt!);
        if (loungeOfIdlenessDrift > const Duration(minutes: 25)) {
          loungeOfIdlenessForceReloadToLobby();
        }
      }
      loungeOfIdlenessLastPausedAt = null;
    }
  }

  void loungeOfIdlenessForceReloadToLobby() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      // Здесь можно вернуть в лобби (MafiaHarbor / CaptainHarbor / BillHarbor),
      // если нужно.
    });
  }

  // --------------------------------------------------------------------------
  // Push / FCM
  // --------------------------------------------------------------------------

  void loungeOfIdlenessWireForegroundPushHandlers() {
    FirebaseMessaging.onMessage.listen(
            (RemoteMessage loungeOfIdlenessMsg) {
          if (loungeOfIdlenessMsg.data['uri'] != null) {
            loungeOfIdlenessNavigateTo(
                loungeOfIdlenessMsg.data['uri'].toString());
          } else {
            loungeOfIdlenessReturnToCurrentUrl();
          }
        });

    FirebaseMessaging.onMessageOpenedApp.listen(
            (RemoteMessage loungeOfIdlenessMsg) {
          if (loungeOfIdlenessMsg.data['uri'] != null) {
            loungeOfIdlenessNavigateTo(
                loungeOfIdlenessMsg.data['uri'].toString());
          } else {
            loungeOfIdlenessReturnToCurrentUrl();
          }
        });
  }

  void loungeOfIdlenessNavigateTo(String loungeOfIdlenessNewUrl) async {
    await loungeOfIdlenessWebViewController.loadUrl(
      urlRequest: URLRequest(url: WebUri(loungeOfIdlenessNewUrl)),
    );
  }

  void loungeOfIdlenessReturnToCurrentUrl() async {
    Future<void>.delayed(const Duration(seconds: 3), () {
      loungeOfIdlenessWebViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(loungeOfIdlenessCurrentUrl)),
      );
    });
  }

  Future<void> loungeOfIdlenessInitPushAndGetToken() async {
    final FirebaseMessaging loungeOfIdlenessFm =
        FirebaseMessaging.instance;

    final NotificationSettings loungeOfIdlenessSettings =
    await loungeOfIdlenessFm.getNotificationSettings();
    if (loungeOfIdlenessSettings.authorizationStatus ==
        AuthorizationStatus.notDetermined ||
        loungeOfIdlenessSettings.authorizationStatus ==
            AuthorizationStatus.denied) {
      await loungeOfIdlenessFm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    loungeOfIdlenessPushToken =
    await loungeOfIdlenessFm.getToken();

    try {
      final NotificationSettings loungeOfIdlenessUpdatedSettings =
      await loungeOfIdlenessFm.getNotificationSettings();
      loungeOfIdlenessDeviceProfile.loungeOfIdlenessPushEnabled =
          loungeOfIdlenessUpdatedSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              loungeOfIdlenessUpdatedSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;
    } catch (_) {
      loungeOfIdlenessDeviceProfile.loungeOfIdlenessPushEnabled =
      false;
    }
  }

  // --------------------------------------------------------------------------
  // Привязка канала: тап по уведомлению из native
  // --------------------------------------------------------------------------

  void loungeOfIdlenessBindPlatformNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall loungeOfIdlenessCall) async {
      if (loungeOfIdlenessCall.method == "onNotificationTap") {
        final Map<String, dynamic> loungeOfIdlenessPayload =
        Map<String, dynamic>.from(
            loungeOfIdlenessCall.arguments);
        debugPrint(
            "URI from platform tap: ${loungeOfIdlenessPayload['uri']}");
        final String? loungeOfIdlenessUriString =
        loungeOfIdlenessPayload["uri"]?.toString();
        if (loungeOfIdlenessUriString != null &&
            !loungeOfIdlenessUriString.contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder:
                  (BuildContext loungeOfIdlenessContext) =>
                  LoungeOfIdlenessTableView(
                      loungeOfIdlenessUriString),
            ),
                (Route<dynamic> loungeOfIdlenessRoute) => false,
          );
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    loungeOfIdlenessBindPlatformNotificationTap();

    final bool loungeOfIdlenessIsDark =
        MediaQuery.of(context).platformBrightness ==
            Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: loungeOfIdlenessIsDark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            InAppWebView(
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
              ),
              initialUrlRequest: URLRequest(
                url: WebUri(loungeOfIdlenessCurrentUrl),
              ),
              onWebViewCreated:
                  (InAppWebViewController loungeOfIdlenessController) {
                loungeOfIdlenessWebViewController =
                    loungeOfIdlenessController;

                loungeOfIdlenessWebViewController
                    .addJavaScriptHandler(
                  handlerName: 'onServerResponse',
                  callback:
                      (List<dynamic> loungeOfIdlenessArgs) {
                    loungeOfIdlenessVault
                        .loungeOfIdlenessLogger
                        .loungeOfIdlenessLogInfo(
                        "JS Args: $loungeOfIdlenessArgs");
                    try {
                      return loungeOfIdlenessArgs.reduce(
                            (dynamic loungeOfIdlenessV,
                            dynamic loungeOfIdlenessE) =>
                        loungeOfIdlenessV + loungeOfIdlenessE,
                      );
                    } catch (_) {
                      return loungeOfIdlenessArgs.toString();
                    }
                  },
                );
              },
              onLoadStart: (
                  InAppWebViewController loungeOfIdlenessController,
                  Uri? loungeOfIdlenessUri,
                  ) async {
                loungeOfIdlenessStartLoadTimestamp =
                    DateTime.now().millisecondsSinceEpoch;

                if (loungeOfIdlenessUri != null) {
                  if (LoungeOfIdlenessKit
                      .loungeOfIdlenessLooksLikeBareMail(
                      loungeOfIdlenessUri)) {
                    try {
                      await loungeOfIdlenessController
                          .stopLoading();
                    } catch (_) {}
                    final Uri loungeOfIdlenessMailto =
                    LoungeOfIdlenessKit.loungeOfIdlenessToMailto(
                        loungeOfIdlenessUri);
                    await LoungeOfIdlenessLinker
                        .loungeOfIdlenessOpen(
                      LoungeOfIdlenessKit.loungeOfIdlenessGmailize(
                          loungeOfIdlenessMailto),
                    );
                    return;
                  }

                  final String loungeOfIdlenessScheme =
                  loungeOfIdlenessUri.scheme.toLowerCase();
                  if (loungeOfIdlenessScheme != 'http' &&
                      loungeOfIdlenessScheme != 'https') {
                    try {
                      await loungeOfIdlenessController
                          .stopLoading();
                    } catch (_) {}
                  }
                }
              },
              onLoadStop: (
                  InAppWebViewController loungeOfIdlenessController,
                  Uri? loungeOfIdlenessUri,
                  ) async {
                await loungeOfIdlenessController
                    .evaluateJavascript(
                  source: "console.log('Hello from Roulette JS!');",
                );

                setState(() {
                  loungeOfIdlenessCurrentUrl =
                      loungeOfIdlenessUri?.toString() ??
                          loungeOfIdlenessCurrentUrl;
                });

                Future<void>.delayed(
                    const Duration(seconds: 20), () {
                  loungeOfIdlenessSendLoadedOnce();
                });
              },
              shouldOverrideUrlLoading: (
                  InAppWebViewController loungeOfIdlenessController,
                  NavigationAction loungeOfIdlenessNav,
                  ) async {
                final Uri? loungeOfIdlenessUri =
                    loungeOfIdlenessNav.request.url;
                if (loungeOfIdlenessUri == null) {
                  return NavigationActionPolicy.ALLOW;
                }

                if (LoungeOfIdlenessKit
                    .loungeOfIdlenessLooksLikeBareMail(
                    loungeOfIdlenessUri)) {
                  final Uri loungeOfIdlenessMailto =
                  LoungeOfIdlenessKit.loungeOfIdlenessToMailto(
                      loungeOfIdlenessUri);
                  await LoungeOfIdlenessLinker
                      .loungeOfIdlenessOpen(
                    LoungeOfIdlenessKit.loungeOfIdlenessGmailize(
                        loungeOfIdlenessMailto),
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                final String loungeOfIdlenessScheme =
                loungeOfIdlenessUri.scheme.toLowerCase();

                if (loungeOfIdlenessScheme == 'mailto') {
                  await LoungeOfIdlenessLinker.loungeOfIdlenessOpen(
                    LoungeOfIdlenessKit.loungeOfIdlenessGmailize(
                        loungeOfIdlenessUri),
                  );
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
                    loungeOfIdlenessHost.endsWith('facebook.com') ||
                        loungeOfIdlenessHost.endsWith('instagram.com') ||
                        loungeOfIdlenessHost.endsWith('twitter.com') ||
                        loungeOfIdlenessHost.endsWith('x.com');

                if (loungeOfIdlenessIsSocial) {
                  await LoungeOfIdlenessLinker
                      .loungeOfIdlenessOpen(
                      loungeOfIdlenessUri);
                  return NavigationActionPolicy.CANCEL;
                }

                if (loungeOfIdlenessIsExternalDestination(
                    loungeOfIdlenessUri)) {
                  final Uri loungeOfIdlenessMapped =
                  loungeOfIdlenessMapExternalToHttp(
                      loungeOfIdlenessUri);
                  await LoungeOfIdlenessLinker
                      .loungeOfIdlenessOpen(
                      loungeOfIdlenessMapped);
                  return NavigationActionPolicy.CANCEL;
                }

                if (loungeOfIdlenessScheme != 'http' &&
                    loungeOfIdlenessScheme != 'https') {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (
                  InAppWebViewController loungeOfIdlenessController,
                  CreateWindowAction loungeOfIdlenessReq,
                  ) async {
                final Uri? loungeOfIdlenessUrl =
                    loungeOfIdlenessReq.request.url;
                if (loungeOfIdlenessUrl == null) return false;

                if (LoungeOfIdlenessKit
                    .loungeOfIdlenessLooksLikeBareMail(
                    loungeOfIdlenessUrl)) {
                  final Uri loungeOfIdlenessMail =
                  LoungeOfIdlenessKit.loungeOfIdlenessToMailto(
                      loungeOfIdlenessUrl);
                  await LoungeOfIdlenessLinker
                      .loungeOfIdlenessOpen(
                    LoungeOfIdlenessKit.loungeOfIdlenessGmailize(
                        loungeOfIdlenessMail),
                  );
                  return false;
                }

                final String loungeOfIdlenessScheme =
                loungeOfIdlenessUrl.scheme.toLowerCase();

                if (loungeOfIdlenessScheme == 'mailto') {
                  await LoungeOfIdlenessLinker.loungeOfIdlenessOpen(
                    LoungeOfIdlenessKit.loungeOfIdlenessGmailize(
                        loungeOfIdlenessUrl),
                  );
                  return false;
                }

                if (loungeOfIdlenessScheme == 'tel') {
                  await launchUrl(
                    loungeOfIdlenessUrl,
                    mode: LaunchMode.externalApplication,
                  );
                  return false;
                }

                final String loungeOfIdlenessHost =
                loungeOfIdlenessUrl.host.toLowerCase();
                final bool loungeOfIdlenessIsSocial =
                    loungeOfIdlenessHost.endsWith('facebook.com') ||
                        loungeOfIdlenessHost.endsWith('instagram.com') ||
                        loungeOfIdlenessHost.endsWith('twitter.com') ||
                        loungeOfIdlenessHost.endsWith('x.com');

                if (loungeOfIdlenessIsSocial) {
                  await LoungeOfIdlenessLinker
                      .loungeOfIdlenessOpen(
                      loungeOfIdlenessUrl);
                  return false;
                }

                if (loungeOfIdlenessIsExternalDestination(
                    loungeOfIdlenessUrl)) {
                  final Uri loungeOfIdlenessMapped =
                  loungeOfIdlenessMapExternalToHttp(
                      loungeOfIdlenessUrl);
                  await LoungeOfIdlenessLinker
                      .loungeOfIdlenessOpen(
                      loungeOfIdlenessMapped);
                  return false;
                }

                if (loungeOfIdlenessScheme == 'http' ||
                    loungeOfIdlenessScheme == 'https') {
                  loungeOfIdlenessController.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(
                          loungeOfIdlenessUrl.toString()),
                    ),
                  );
                }

                return false;
              },
            ),
            if (loungeOfIdlenessOverlayBusy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black87,
                  child: Center(
                    child: LoungeOfIdlenessWaveLoader(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // Внешние “столы” (протоколы/мессенджеры/соцсети)
  // ========================================================================

  bool loungeOfIdlenessIsExternalDestination(Uri loungeOfIdlenessUri) {
    final String loungeOfIdlenessScheme =
    loungeOfIdlenessUri.scheme.toLowerCase();
    if (loungeOfIdlenessExternalSchemes
        .contains(loungeOfIdlenessScheme)) {
      return true;
    }

    if (loungeOfIdlenessScheme == 'http' ||
        loungeOfIdlenessScheme == 'https') {
      final String loungeOfIdlenessHost =
      loungeOfIdlenessUri.host.toLowerCase();
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

  Uri loungeOfIdlenessMapExternalToHttp(Uri loungeOfIdlenessUri) {
    final String loungeOfIdlenessScheme =
    loungeOfIdlenessUri.scheme.toLowerCase();

    if (loungeOfIdlenessScheme == 'tg' ||
        loungeOfIdlenessScheme == 'telegram') {
      final Map<String, String> loungeOfIdlenessQp =
          loungeOfIdlenessUri.queryParameters;
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
      loungeOfIdlenessUri.path.isNotEmpty
          ? loungeOfIdlenessUri.path
          : '';
      return Uri.https(
        't.me',
        '/$loungeOfIdlenessPath',
        loungeOfIdlenessUri.queryParameters.isEmpty
            ? null
            : loungeOfIdlenessUri.queryParameters,
      );
    }

    if (loungeOfIdlenessScheme == 'whatsapp') {
      final Map<String, String> loungeOfIdlenessQp =
          loungeOfIdlenessUri.queryParameters;
      final String? loungeOfIdlenessPhone =
      loungeOfIdlenessQp['phone'];
      final String? loungeOfIdlenessText =
      loungeOfIdlenessQp['text'];
      if (loungeOfIdlenessPhone != null &&
          loungeOfIdlenessPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${LoungeOfIdlenessKit.loungeOfIdlenessDigitsOnly(loungeOfIdlenessPhone)}',
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

    if (loungeOfIdlenessScheme == 'bnl') {
      final String loungeOfIdlenessNewPath =
      loungeOfIdlenessUri.path.isNotEmpty
          ? loungeOfIdlenessUri.path
          : '';
      return Uri.https(
        'bnl.com',
        '/$loungeOfIdlenessNewPath',
        loungeOfIdlenessUri.queryParameters.isEmpty
            ? null
            : loungeOfIdlenessUri.queryParameters,
      );
    }

    return loungeOfIdlenessUri;
  }

  Future<void> loungeOfIdlenessSendLoadedOnce() async {
    if (loungeOfIdlenessLoadedOnceSent) {
      debugPrint('Wheel Loaded already sent, skip');
      return;
    }

    final int loungeOfIdlenessNow =
        DateTime.now().millisecondsSinceEpoch;

    await loungeOfIdlenessPostStat(
      event: 'Loaded',
      timeStart: loungeOfIdlenessStartLoadTimestamp,
      timeFinish: loungeOfIdlenessNow,
      url: loungeOfIdlenessCurrentUrl,
      appSid: loungeOfIdlenessSpy.loungeOfIdlenessAppsFlyerUid,
      firstPageTs: loungeOfIdlenessFirstPageTimestamp,
    );

    loungeOfIdlenessLoadedOnceSent = true;
  }
}