import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show Platform, HttpHeaders, HttpClient, HttpClientRequest, HttpClientResponse;

import 'package:appsflyer_sdk/appsflyer_sdk.dart' as appsflyer_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
    MethodChannel,
    SystemChrome,
    SystemUiOverlayStyle,
    MethodCall,
    VoidCallback;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:loungeoflendess/psladnes.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz_zone;

import 'ledness.dart';
import 'loader.dart';

// ============================================================================
// Константы
// ============================================================================

const String idleLoadedOnceKey = 'loaded_once';
const String idleStatEndpoint = 'https://sub.sllounge.club/stat';
const String idleCachedFcmKey = 'cached_fcm';
const String idleCachedDeepKey = 'cached_deep_push_uri';

const Set<String> idleBankSchemes = {
  'td',
  'rbc',
  'cibc',
  'scotiabank',
  'bmo',
  'bmodigitalbanking',
  'desjardins',
  'tangerine',
  'nationalbank',
  'simplii',
  'dominotoronto',
};

const Set<String> idleBankDomains = {
  'td.com',
  'tdcanadatrust.com',
  'easyweb.td.com',
  'rbc.com',
  'royalbank.com',
  'online.royalbank.com',
  'cibc.com',
  'cibc.ca',
  'online.cibc.com',
  'scotiabank.com',
  'scotiaonline.scotiabank.com',
  'bmo.com',
  'bmo.ca',
  'bmodigitalbanking.com',
  'desjardins.com',
  'tangerine.ca',
  'nbc.ca',
  'nationalbank.ca',
  'simplii.com',
  'simplii.ca',
  'dominotoronto.com',
  'dominobank.com',
};

// ============================================================================
// Лёгкие сервисы
// ============================================================================

class IdleLoggerService {
  static final IdleLoggerService SharedInstance =
  IdleLoggerService._InternalConstructor();

  IdleLoggerService._InternalConstructor();

  factory IdleLoggerService() => SharedInstance;

  final Connectivity IdleConnectivity = Connectivity();

  void IdleLogInfo(Object message) => print('[I] $message');
  void IdleLogWarn(Object message) => print('[W] $message');
  void IdleLogError(Object message) => print('[E] $message');
}

class IdleNetworkService {
  final IdleLoggerService IdleLogger = IdleLoggerService();

  Future<void> IdlePostJson(
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
      IdleLogger.IdleLogError('postJson error: $error');
    }
  }
}

// ============================================================================
// Утилита: одновременное сохранение JSON в localStorage и SharedPreferences
// ============================================================================

Future<void> IdleSaveJsonToLocalStorageAndPrefs({
  required InAppWebViewController? controller,
  required String key,
  required Map<String, dynamic> data,
}) async {
  final String jsonString = jsonEncode(data);

  // 1) localStorage в WebView
  if (controller != null) {
    try {
      await controller.evaluateJavascript(
        source:
        "localStorage.setItem('$key', JSON.stringify($jsonString));",
      );
    } catch (e, st) {
      IdleLoggerService().IdleLogError(
          'IdleSaveJsonToLocalStorageAndPrefs localStorage error: $e\n$st');
    }
  }

  // 2) SharedPreferences на native-стороне
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonString);
  } catch (e, st) {
    IdleLoggerService().IdleLogError(
        'IdleSaveJsonToLocalStorageAndPrefs prefs error: $e\n$st');
  }
}

// ============================================================================
// Профиль устройства
// ============================================================================

class IdleDeviceProfile {
  String? IdleDeviceId;
  String? IdleSessionId = '';
  String? IdlePlatformName;
  String? IdleOsVersion;
  String? IdleAppVersion;
  String? IdleLanguageCode;
  String? IdleTimezoneName;
  bool IdlePushEnabled = false;

  bool IdleSafeAreaEnabled = false;
  String? IdleSafeAreaColor;
  bool safecasher = true; // будет обновляться с сервера
  String? IdleBaseUserAgent;

  Map<String, dynamic>? IdleLastPushData;

  Map<String, dynamic>? IdleSavels;

  Future<void> IdleInitialize() async {
    final DeviceInfoPlugin idleDeviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo idleAndroidInfo =
      await idleDeviceInfoPlugin.androidInfo;
      IdleDeviceId = idleAndroidInfo.id;
      IdlePlatformName = 'android';
      IdleOsVersion = idleAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo idleIosInfo = await idleDeviceInfoPlugin.iosInfo;
      IdleDeviceId = idleIosInfo.identifierForVendor;
      IdlePlatformName = 'ios';
      IdleOsVersion = idleIosInfo.systemVersion;
    }

    final PackageInfo idlePackageInfo = await PackageInfo.fromPlatform();
    IdleAppVersion = idlePackageInfo.version;
    IdleLanguageCode = Platform.localeName.split('_').first;
    IdleTimezoneName = tz_zone.local.name;
    IdleSessionId = 'test-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> IdleToMap({String? fcmToken}) => <String, dynamic>{
    'fcm_token': fcmToken ?? 'missing_token',
    'device_id': IdleDeviceId ?? 'missing_id',
    'app_name': 'sllounge',
    'instance_id': IdleSessionId ?? 'missing_session',
    'platform': IdlePlatformName ?? 'missing_system',
    'os_version': IdleOsVersion ?? 'missing_build',
    'app_version': "1.4.1" ?? 'missing_app',
    'language': IdleLanguageCode ?? 'en',
    'timezone': IdleTimezoneName ?? 'UTC',
    'push_enabled': IdlePushEnabled,
    'safe_area_native': IdleSafeAreaEnabled,
    'useragent': IdleBaseUserAgent ?? 'unknown_useragent',
    'savels': IdleSavels ?? <String, dynamic>{},
    'fpscashier': safecasher,
  };
}

// ============================================================================
// AppsFlyer Spy
// ============================================================================

class IdleAnalyticsSpyService {
  appsflyer_core.AppsFlyerOptions? IdleAppsFlyerOptions;
  appsflyer_core.AppsflyerSdk? IdleAppsFlyerSdk;

  String IdleAppsFlyerUid = '';
  String IdleAppsFlyerData = '';

  Map<String, dynamic>? IdleAppsFlyerOneLinkData;

  void IdleStartTracking({VoidCallback? onUpdate}) {
    final appsflyer_core.AppsFlyerOptions idleConfig =
    appsflyer_core.AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6759056932',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    IdleAppsFlyerOptions = idleConfig;
    IdleAppsFlyerSdk = appsflyer_core.AppsflyerSdk(idleConfig);

    IdleAppsFlyerSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    IdleAppsFlyerSdk?.startSDK(
      onSuccess: () =>
          IdleLoggerService().IdleLogInfo('RetroCarAnalyticsSpy started'),
      onError: (int code, String msg) =>
          IdleLoggerService().IdleLogError('RetroCarAnalyticsSpy error $code: $msg'),
    );

    IdleAppsFlyerSdk?.onInstallConversionData((dynamic value) {
      IdleAppsFlyerData = value.toString();
      onUpdate?.call();
    });

    IdleAppsFlyerSdk?.getAppsFlyerUID().then((dynamic value) {
      IdleAppsFlyerUid = value.toString();
      onUpdate?.call();
    });
  }

  void IdleSetOneLinkData(Map<String, dynamic> data) {
    IdleAppsFlyerOneLinkData = data;
    IdleLoggerService()
        .IdleLogInfo('IdleAnalyticsSpyService: OneLink data updated: $data');
  }
}

// ============================================================================
// FCM фон
// ============================================================================

@pragma('vm:entry-point')
Future<void> IdleFcmBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  IdleLoggerService().IdleLogInfo('bg-fcm: ${message.messageId}');
  IdleLoggerService().IdleLogInfo('bg-data: ${message.data}');

  final dynamic idleLink = message.data['uri'];
  if (idleLink != null) {
    try {
      final SharedPreferences idlePrefs = await SharedPreferences.getInstance();
      await idlePrefs.setString(
        idleCachedDeepKey,
        idleLink.toString(),
      );
    } catch (e) {
      IdleLoggerService().IdleLogError('bg-fcm save deep failed: $e');
    }
  }
}

// ============================================================================
// FCM Bridge — токен
// ============================================================================

class IdleFcmBridge {
  final IdleLoggerService IdleLogger = IdleLoggerService();

  static const MethodChannel _tokenChannel =
  MethodChannel('com.example.fcm/token');

  String? IdleToken;
  final List<void Function(String)> IdleTokenWaiters =
  <void Function(String)>[];

  String? get IdleFcmToken => IdleToken;

  Timer? _requestTimer;
  int _requestAttempts = 0;
  final int _maxAttempts = 10;

  IdleFcmBridge() {
    _tokenChannel.setMethodCallHandler((MethodCall IdleCall) async {
      if (IdleCall.method == 'setToken') {
        final String IdleTokenString = IdleCall.arguments as String;
        IdleLogger.IdleLogInfo(
            'IdleFcmBridge: got token from native channel = $IdleTokenString');
        if (IdleTokenString.isNotEmpty) {
          IdleSetToken(IdleTokenString);
        }
      }
    });

    IdleRestoreToken();
    _requestNativeToken();
    _startRequestTimer();
  }

  Future<void> _requestNativeToken() async {
    try {
      IdleLogger.IdleLogInfo('IdleFcmBridge: request native getToken()');
      final String? token =
      await _tokenChannel.invokeMethod<String>('getToken');
      if (token != null && token.isNotEmpty) {
        IdleLogger.IdleLogInfo(
            'IdleFcmBridge: native getToken() returns $token');
        IdleSetToken(token);
      } else {
        IdleLogger.IdleLogWarn(
            'IdleFcmBridge: native getToken() returned empty');
      }
    } catch (e) {
      IdleLogger.IdleLogWarn('IdleFcmBridge: getToken invoke error: $e');
    }
  }

  void _startRequestTimer() {
    _requestTimer?.cancel();
    _requestAttempts = 0;

    _requestTimer = Timer.periodic(const Duration(seconds: 5), (Timer t) async {
      if ((IdleToken ?? '').isNotEmpty) {
        IdleLogger.IdleLogInfo(
            'IdleFcmBridge: token already set, stop request timer');
        t.cancel();
        return;
      }

      if (_requestAttempts >= _maxAttempts) {
        IdleLogger.IdleLogWarn(
            'IdleFcmBridge: max getToken attempts reached, stop timer');
        t.cancel();
        return;
      }

      _requestAttempts++;
      IdleLogger.IdleLogInfo(
          'IdleFcmBridge: retry getToken() attempt #$_requestAttempts');
      await _requestNativeToken();
    });
  }

  Future<void> IdleRestoreToken() async {
    try {
      final SharedPreferences idlePrefs = await SharedPreferences.getInstance();
      final String? idleCachedToken =
      idlePrefs.getString(idleCachedFcmKey);
      if (idleCachedToken != null && idleCachedToken.isNotEmpty) {
        IdleLogger.IdleLogInfo(
            'IdleFcmBridge: restored cached token = $idleCachedToken');
        IdleSetToken(idleCachedToken, notify: false);
      }
    } catch (e) {
      IdleLogger.IdleLogError('IdleRestoreToken error: $e');
    }
  }

  Future<void> IdlePersistToken(String newToken) async {
    try {
      final SharedPreferences idlePrefs = await SharedPreferences.getInstance();
      await idlePrefs.setString(idleCachedFcmKey, newToken);
    } catch (e) {
      IdleLogger.IdleLogError('IdlePersistToken error: $e');
    }
  }

  void IdleSetToken(
      String newToken, {
        bool notify = true,
      }) {
    IdleToken = newToken;
    IdlePersistToken(newToken);

    if (notify) {
      for (final void Function(String) idleCallback
      in List<void Function(String)>.from(IdleTokenWaiters)) {
        try {
          idleCallback(newToken);
        } catch (error) {
          IdleLogger.IdleLogWarn('fcm waiter error: $error');
        }
      }
      IdleTokenWaiters.clear();
    }
  }

  Future<void> IdleWaitForToken(
      Function(String token) idleOnToken,
      ) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if ((IdleToken ?? '').isNotEmpty) {
        idleOnToken(IdleToken!);
        return;
      }

      IdleTokenWaiters.add(idleOnToken);
    } catch (error) {
      IdleLogger.IdleLogError('IdleWaitForToken error: $error');
    }
  }

  void dispose() {
    _requestTimer?.cancel();
  }
}

// ============================================================================
// Splash / Hall
// ============================================================================

class IdleHall extends StatefulWidget {
  const IdleHall({Key? key}) : super(key: key);

  @override
  State<IdleHall> createState() => _IdleHallState();
}

class _IdleHallState extends State<IdleHall> {
  final IdleFcmBridge IdleFcmBridgeInstance = IdleFcmBridge();
  bool IdleNavigatedOnce = false;
  Timer? IdleFallbackTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    IdleFcmBridgeInstance.IdleWaitForToken((String idleToken) {
      IdleGoToHarbor(idleToken);
    });

    IdleFallbackTimer = Timer(
      const Duration(seconds: 8),
          () => IdleGoToHarbor(''),
    );
  }

  void IdleGoToHarbor(String idleSignal) {
    if (IdleNavigatedOnce) return;
    IdleNavigatedOnce = true;
    IdleFallbackTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<Widget>(
        builder: (BuildContext context) =>
            IdleHarbor(IdleSignal: idleSignal),
      ),
    );
  }

  @override
  void dispose() {
    IdleFallbackTimer?.cancel();
    IdleFcmBridgeInstance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: LoungeOfIdlenessWaveLoader()
        ),
      ),
    );
  }
}

// ============================================================================
// ViewModel + Courier
// ============================================================================

class IdleBosunViewModel {
  final IdleDeviceProfile IdleDeviceProfileInstance;
  final IdleAnalyticsSpyService IdleAnalyticsSpyInstance;

  IdleBosunViewModel({
    required this.IdleDeviceProfileInstance,
    required this.IdleAnalyticsSpyInstance,
  });

  Map<String, dynamic> IdleDeviceMap(String? fcmToken) =>
      IdleDeviceProfileInstance.IdleToMap(fcmToken: fcmToken);

  Map<String, dynamic> IdleAppsFlyerPayload(
      String? token, {
        String? deepLink,
      }) {
    final Map<String, dynamic> onelinkData =
        IdleAnalyticsSpyInstance.IdleAppsFlyerOneLinkData ??
            <String, dynamic>{};

    return <String, dynamic>{
      'content': <String, dynamic>{
        'af_data': IdleAnalyticsSpyInstance.IdleAppsFlyerData,
        'af_id': IdleAnalyticsSpyInstance.IdleAppsFlyerUid,
        'fb_app_name': 'sllounge',
        'app_name': 'sllounge',
        'onelink': onelinkData,
        'bundle_identifier': 'com.lougeof.ledes.louge.loungeoflendess',
        'app_version': '1.4.1',
        'apple_id': '6759056932',
        'fcm_token': token ?? 'no_token',
        'device_id': IdleDeviceProfileInstance.IdleDeviceId ?? 'no_device',
        'instance_id':
        IdleDeviceProfileInstance.IdleSessionId ?? 'no_instance',
        'platform': IdleDeviceProfileInstance.IdlePlatformName ?? 'no_type',
        'os_version': IdleDeviceProfileInstance.IdleOsVersion ?? 'no_os',
        'language': IdleDeviceProfileInstance.IdleLanguageCode ?? 'en',
        'timezone': IdleDeviceProfileInstance.IdleTimezoneName ?? 'UTC',
        'push_enabled': IdleDeviceProfileInstance.IdlePushEnabled,
        'useruid': IdleAnalyticsSpyInstance.IdleAppsFlyerUid,
        'safearea': IdleDeviceProfileInstance.IdleSafeAreaEnabled,
        'safearea_color':
        IdleDeviceProfileInstance.IdleSafeAreaColor ?? '',
        'useragent': IdleDeviceProfileInstance.IdleBaseUserAgent ??
            'unknown_useragent',
        'push':
        IdleDeviceProfileInstance.IdleLastPushData ?? <String, dynamic>{},
        'deep': deepLink,
        // *** НОВОЕ: fpscashier уходит в sendRawData ***
        'fpscashier': IdleDeviceProfileInstance.safecasher,
      },
    };
  }
}

class IdleCourierService {
  final IdleBosunViewModel IdleBosun;
  final InAppWebViewController? Function() IdleGetWebViewController;

  IdleCourierService({
    required this.IdleBosun,
    required this.IdleGetWebViewController,
  });

  Future<InAppWebViewController?> _waitForController({
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 200),
  }) async {
    final IdleLoggerService logger = IdleLoggerService();
    final DateTime start = DateTime.now();

    while (DateTime.now().difference(start) < timeout) {
      final InAppWebViewController? c = IdleGetWebViewController();
      if (c != null) {
        return c;
      }
      await Future<void>.delayed(interval);
    }

    logger.IdleLogWarn('_waitForController: timeout, controller is still null');
    return null;
  }

  Future<void> IdlePutDeviceToLocalStorage(String? token) async {
    final InAppWebViewController? idleController = await _waitForController();
    if (idleController == null) return;

    final Map<String, dynamic> idleMap = IdleBosun.IdleDeviceMap(token);
    IdleLoggerService().IdleLogInfo("applocal (${jsonEncode(idleMap)});");

    await IdleSaveJsonToLocalStorageAndPrefs(
      controller: idleController,
      key: 'app_data',
      data: idleMap,
    );
  }

  Future<void> IdleSendRawToPage(
      String? token, {
        String? deepLink,
      }) async {
    final InAppWebViewController? idleController = await _waitForController();
    if (idleController == null) return;

    final Map<String, dynamic> idlePayload =
    IdleBosun.IdleAppsFlyerPayload(token, deepLink: deepLink);

    final String idleJsonString = jsonEncode(idlePayload);

    IdleLoggerService().IdleLogInfo('SendRawData: $idleJsonString');

    final String jsSafeJson = jsonEncode(idleJsonString);
    final String jsCode = 'sendRawData($jsSafeJson);';

    try {
      await idleController.evaluateJavascript(source: jsCode);
    } catch (e, st) {
      IdleLoggerService()
          .IdleLogError('IdleSendRawToPage evaluateJavascript error: $e\n$st');
    }
  }
}

// ============================================================================
// Статистика
// ============================================================================

Future<String> IdleResolveFinalUrl(
    String startUrl, {
      int maxHops = 10,
    }) async {
  final HttpClient idleHttpClient = HttpClient();

  try {
    Uri idleCurrentUri = Uri.parse(startUrl);

    for (int idleIndex = 0; idleIndex < maxHops; idleIndex++) {
      final HttpClientRequest idleRequest =
      await idleHttpClient.getUrl(idleCurrentUri);
      idleRequest.followRedirects = false;
      final HttpClientResponse idleResponse = await idleRequest.close();

      if (idleResponse.isRedirect) {
        final String? idleLocationHeader =
        idleResponse.headers.value(HttpHeaders.locationHeader);
        if (idleLocationHeader == null || idleLocationHeader.isEmpty) {
          break;
        }

        final Uri idleNextUri = Uri.parse(idleLocationHeader);
        idleCurrentUri = idleNextUri.hasScheme
            ? idleNextUri
            : idleCurrentUri.resolveUri(idleNextUri);
        continue;
      }

      return idleCurrentUri.toString();
    }

    return idleCurrentUri.toString();
  } catch (error) {
    print('goldenLuxuryResolveFinalUrl error: $error');
    return startUrl;
  } finally {
    idleHttpClient.close(force: true);
  }
}

Future<void> IdlePostStat({
  required String event,
  required int timeStart,
  required String url,
  required int timeFinish,
  required String appSid,
  int? firstPageLoadTs,
}) async {
  try {
    final String idleResolvedUrl = await IdleResolveFinalUrl(url);

    final Map<String, dynamic> idlePayload = <String, dynamic>{
      'event': event,
      'timestart': timeStart,
      'timefinsh': timeFinish,
      'url': idleResolvedUrl,
      'appleID': '6759056932',
      'open_count': '$appSid/$timeStart',
    };

    print('goldenLuxuryStat $idlePayload');

    final http.Response idleResponse = await http.post(
      Uri.parse('$idleStatEndpoint/$appSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(idlePayload),
    );

    print(
        'goldenLuxuryStat resp=${idleResponse.statusCode} body=${idleResponse.body}');
  } catch (error) {
    print('goldenLuxuryPostStat error: $error');
  }
}

// ============================================================================
// Банковские утилиты
// ============================================================================

bool IdleIsBankScheme(Uri uri) {
  final String scheme = uri.scheme.toLowerCase();
  return idleBankSchemes.contains(scheme);
}

bool IdleIsBankDomain(Uri uri) {
  final String host = uri.host.toLowerCase();
  if (host.isEmpty) return false;

  for (final String bank in idleBankDomains) {
    final String bankHost = bank.toLowerCase();
    if (host == bankHost || host.endsWith('.$bankHost')) {
      return true;
    }
  }
  return false;
}

Future<bool> IdleOpenBank(Uri uri) async {
  try {
    if (IdleIsBankScheme(uri)) {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return ok;
    }

    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        IdleIsBankDomain(uri)) {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return ok;
    }
  } catch (e) {
    print('IdleOpenBank error: $e; url=$uri');
  }
  return false;
}

// ============================================================================
// Главный WebView — Harbor
// ============================================================================

class IdleHarbor extends StatefulWidget {
  final String? IdleSignal;

  const IdleHarbor({super.key, required this.IdleSignal});

  @override
  State<IdleHarbor> createState() => _IdleHarborState();
}

class _IdleHarborState extends State<IdleHarbor>
    with WidgetsBindingObserver {
  InAppWebViewController? IdleWebViewController;

  // Popup (window.open) state
  InAppWebViewController? IdlePopupWebViewController;
  bool _isPopupVisible = false;
  String? _popupUrl;
  CreateWindowAction? _popupCreateAction;

  bool _popupCanGoBack = false;

  // Текущий URL внутри popup
  String? _popupCurrentUrl;

  bool _isOpeningExternalNewTab = false;
  final Set<String> _handledNewTabUrls = <String>{};

  Timer? _parentInstallTimer;
  Timer? _popupInstallTimer;

  final String IdleHomeUrl = 'https://sub.sllounge.club/';

  int IdleWebViewKeyCounter = 0;
  DateTime? IdleSleepAt;
  bool IdleVeilVisible = false;
  double IdleWarmProgress = 0.0;
  late Timer IdleWarmTimer;
  final int IdleWarmSeconds = 6;
  bool IdleCoverVisible = true;

  bool IdleLoadedOnceSent = false;
  int? IdleFirstPageTimestamp;

  IdleCourierService? IdleCourier;
  IdleBosunViewModel? IdleBosunInstance;

  String IdleCurrentUrl = '';
  int IdleStartLoadTimestamp = 0;

  final IdleDeviceProfile IdleDeviceProfileInstance = IdleDeviceProfile();
  final IdleAnalyticsSpyService IdleAnalyticsSpyInstance =
  IdleAnalyticsSpyService();

  final Set<String> IdleSpecialSchemes = <String>{
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

  final Set<String> IdleExternalHosts = <String>{
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

  String? IdleDeepLinkFromPush;

  String? _baseUserAgent;
  String _currentUserAgent = "";
  String? _currentUrl;

  String? _serverUserAgent;

  bool _safeAreaEnabled = false;
  Color _safeAreaBackgroundColor = const Color(0xFF000000);

  bool _startupSendRawDone = false;

  String? _pendingLoadedJs;

  bool _loadedJsExecutedOnce = false;

  bool _isInGoogleAuth = false;

  List<String> _buttonWhitelist = <String>[];
  bool _showBackButton = false;

  bool _backButtonHiddenAfterTap = false;

  // Флаг: сейчас на Google (чтобы не слетал UA random)
  bool _isCurrentlyOnGoogle = false;

  static const MethodChannel _appsFlyerDeepLinkChannel =
  MethodChannel('appsflyer_deeplink_channel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IdleFirstPageTimestamp = DateTime.now().millisecondsSinceEpoch;
    _currentUrl = IdleHomeUrl;

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          IdleCoverVisible = false;
        });
      }
    });

    Future<void>.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() {
        IdleVeilVisible = true;
      });
    });

    _bindPushChannelFromAppDelegate();
    _bindAppsFlyerDeepLinkChannel();
    IdleBootHarbor();
  }

  bool _isAboutBlankUrl(String? value) {
    final String u = (value ?? '').trim().toLowerCase();
    return u.isEmpty || u == 'about:blank' || u.startsWith('about:blank');
  }

  bool _isAboutBlankUri(Uri? uri) => _isAboutBlankUrl(uri?.toString());

  void _bindAppsFlyerDeepLinkChannel() {
    _appsFlyerDeepLinkChannel.setMethodCallHandler(
          (MethodCall call) async {
        if (call.method == 'onDeepLink') {
          try {
            final dynamic args = call.arguments;

            Map<String, dynamic> payload;

            print(" Data Deepl link ${args.toString()}");
            if (args is Map) {
              payload = Map<String, dynamic>.from(args as Map);
            } else if (args is String) {
              payload = jsonDecode(args) as Map<String, dynamic>;
            } else {
              payload = <String, dynamic>{'raw': args.toString()};
            }

            IdleLoggerService().IdleLogInfo(
              'AppsFlyer onDeepLink from iOS: $payload',
            );

            final dynamic raw = payload['raw'];
            if (raw is Map) {
              final Map<String, dynamic> normalized =
              Map<String, dynamic>.from(raw as Map);

              print("One Link Data $normalized");
              IdleAnalyticsSpyInstance.IdleSetOneLinkData(normalized);
            } else {
              IdleAnalyticsSpyInstance.IdleSetOneLinkData(payload);
            }
          } catch (e, st) {
            IdleLoggerService()
                .IdleLogError('Error in onDeepLink handler: $e\n$st');
          }
        }
      },
    );
  }

  void _bindPushChannelFromAppDelegate() {
    const MethodChannel pushChannel = MethodChannel('com.example.fcm/push');

    pushChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'setPushData') {
        try {
          Map<String, dynamic> pushData;
          if (call.arguments is Map) {
            pushData = Map<String, dynamic>.from(call.arguments);
            print("Get Push Data $pushData");
          } else if (call.arguments is String) {
            pushData =
            jsonDecode(call.arguments as String) as Map<String, dynamic>;
          } else {
            pushData = <String, dynamic>{'raw': call.arguments.toString()};
          }

          IdleLoggerService()
              .IdleLogInfo('Got push data from AppDelegate: $pushData');

          IdleDeviceProfileInstance.IdleLastPushData = pushData;

          final dynamic uriRaw = pushData['uri'] ?? pushData['deep_link'];
          if (uriRaw != null && uriRaw.toString().isNotEmpty) {
            final String u = uriRaw.toString();
            IdleDeepLinkFromPush = u;
            await IdleSaveCachedDeep(u);
          }
        } catch (e, st) {
          IdleLoggerService()
              .IdleLogError('setPushData handler error: $e\n$st');
        }
      }
    });
  }

  // ---------------- User-Agent и Google ----------------

  bool _isGoogleUrl(Uri uri) {
    final String full = uri.toString().toLowerCase();
    return full.contains('google.com') ||
        full.contains('accounts.google.') ||
        full.contains('googleusercontent.com') ||
        full.contains('gstatic.com');
  }

  Future<void> _applyGoogleUserAgent() async {
    if (IdleWebViewController == null) return;

    const String googleUa = 'random';

    if (_currentUserAgent == googleUa) {
      IdleLoggerService()
          .IdleLogInfo('[UA] Already set to "random" for Google, skip');
      return;
    }

    IdleLoggerService()
        .IdleLogInfo('[UA] Applying GOOGLE User-Agent: $googleUa');

    try {
      await IdleWebViewController!.setSettings(
        settings: InAppWebViewSettings(userAgent: googleUa),
      );
      _currentUserAgent = googleUa;
      _isCurrentlyOnGoogle = true;
      print('[UA] GOOGLE WEBVIEW USER AGENT: $_currentUserAgent');
    } catch (e) {
      IdleLoggerService()
          .IdleLogError('Error setting Google User-Agent: $e');
    }
  }

  Future<void> _applyGoogleUserAgentForPopup() async {
    if (IdlePopupWebViewController == null) return;

    const String googleUa = 'random';

    IdleLoggerService()
        .IdleLogInfo('[UA] Applying GOOGLE User-Agent to POPUP: $googleUa');

    try {
      await IdlePopupWebViewController!.setSettings(
        settings: InAppWebViewSettings(userAgent: googleUa),
      );
      print('[UA] GOOGLE POPUP USER AGENT: $googleUa');
    } catch (e) {
      IdleLoggerService()
          .IdleLogError('Error setting Google User-Agent for popup: $e');
    }
  }

  Future<void> _updateUserAgentFromServerPayload(
      Map<dynamic, dynamic> root) async {
    String? fullua;
    String? uatail;

    final dynamic content = root['content'];
    if (content is Map) {
      if (content['fullua'] != null &&
          content['fullua'].toString().trim().isNotEmpty) {
        fullua = content['fullua'].toString().trim();
      }
      if (content['uatail'] != null &&
          content['uatail'].toString().trim().isNotEmpty) {
        uatail = content['uatail'].toString().trim();
      }
    }

    if (fullua == null &&
        root['fullua'] != null &&
        root['fullua'].toString().trim().isNotEmpty) {
      fullua = root['fullua'].toString().trim();
    }
    if (uatail == null &&
        root['uatail'] != null &&
        root['uatail'].toString().trim().isNotEmpty) {
      uatail = root['uatail'].toString().trim();
    }

    if (uatail == null) {
      final dynamic adata = root['adata'];
      if (adata is Map &&
          adata['uatail'] != null &&
          adata['uatail'].toString().trim().isNotEmpty) {
        uatail = adata['uatail'].toString().trim();
      }
    }

    await _applyUserAgent(fullua: fullua, uatail: uatail);
  }

  Future<void> _applyUserAgent({String? fullua, String? uatail}) async {
    if (IdleWebViewController == null) return;

    if (_baseUserAgent == null || _baseUserAgent!.trim().isEmpty) {
      try {
        final ua = await IdleWebViewController!.evaluateJavascript(
          source: "navigator.userAgent",
        );
        if (ua is String && ua.trim().isNotEmpty) {
          _baseUserAgent = ua.trim();
          _currentUserAgent = _baseUserAgent!;
          IdleDeviceProfileInstance.IdleBaseUserAgent = _baseUserAgent;
          IdleLoggerService()
              .IdleLogInfo('Base User-Agent detected: $_baseUserAgent');
        }
      } catch (e) {
        IdleLoggerService()
            .IdleLogWarn('Failed to get base userAgent from JS: $e');
      }
    }

    if (_baseUserAgent == null || _baseUserAgent!.trim().isEmpty) {
      IdleLoggerService()
          .IdleLogWarn('Base User-Agent is still null/empty, skip UA update');
      return;
    }

    IdleLoggerService().IdleLogInfo(
        'Server UA payload: fullua="$fullua", uatail="$uatail", base="$_baseUserAgent"');

    String newUa;
    if (fullua != null && fullua.trim().isNotEmpty) {
      newUa = fullua.trim();
    } else if (uatail != null && uatail.trim().isNotEmpty) {
      newUa = "${_baseUserAgent!}/${uatail.trim()}";
    } else {
      newUa = "${_baseUserAgent!}";
    }

    _serverUserAgent = newUa;
    IdleLoggerService()
        .IdleLogInfo('Server UA calculated and stored: $_serverUserAgent');
  }

  Future<void> _applyNormalUserAgentIfNeeded() async {
    if (IdleWebViewController == null) return;

    if (_isCurrentlyOnGoogle) {
      IdleLoggerService().IdleLogInfo(
          '[UA] Currently on Google page, keeping "random" UA');
      return;
    }

    final String targetUa = _serverUserAgent ?? _baseUserAgent ?? 'random';

    if (targetUa == _currentUserAgent) {
      IdleLoggerService()
          .IdleLogInfo('Normal UA unchanged, keeping: $_currentUserAgent');
      return;
    }

    IdleLoggerService()
        .IdleLogInfo('Applying NORMAL WebView User-Agent: $targetUa');

    try {
      await IdleWebViewController!.setSettings(
        settings: InAppWebViewSettings(userAgent: targetUa),
      );
      _currentUserAgent = targetUa;
      print('[UA] NORMAL WEBVIEW USER AGENT: $_currentUserAgent');
    } catch (e) {
      IdleLoggerService()
          .IdleLogError('Error while setting normal User-Agent "$targetUa": $e');
    }
  }

  Future<void> _switchUserAgentForUrl(Uri? uri) async {
    if (uri == null) return;

    if (_isGoogleUrl(uri)) {
      _isCurrentlyOnGoogle = true;
      await _applyGoogleUserAgent();
    } else {
      if (_isCurrentlyOnGoogle) {
        _isCurrentlyOnGoogle = false;
      }
      await _applyNormalUserAgentIfNeeded();
    }
  }

  Future<void> printJsUserAgent() async {
    if (IdleWebViewController == null) return;

    try {
      final ua = await IdleWebViewController!.evaluateJavascript(
        source: "navigator.userAgent",
      );

      if (ua is String) {
        print('[JS UA] navigator.userAgent = $ua');
      } else {
        print('[JS UA] navigator.userAgent (non-string) = $ua');
      }
    } catch (e, st) {
      print('Error reading navigator.userAgent: $e\n$st');
    }
  }

  Future<void> debugPrintCurrentUserAgent() async {
    IdleLoggerService()
        .IdleLogInfo('[STATE UA] _currentUserAgent = $_currentUserAgent');
    await printJsUserAgent();
  }

  // =======================================================================
  // Флаги "загружено один раз" и кеш диплинка
  // =======================================================================

  Future<void> IdleLoadLoadedFlag() async {
    final SharedPreferences idlePrefs = await SharedPreferences.getInstance();
    IdleLoadedOnceSent = idlePrefs.getBool(idleLoadedOnceKey) ?? false;
  }

  Future<void> IdleSaveLoadedFlag() async {
    final SharedPreferences idlePrefs = await SharedPreferences.getInstance();
    await idlePrefs.setBool(idleLoadedOnceKey, true);
    IdleLoadedOnceSent = true;
  }

  Future<void> IdleLoadCachedDeep() async {
    try {
      final SharedPreferences idlePrefs = await SharedPreferences.getInstance();
      final String? idleCached = idlePrefs.getString(idleCachedDeepKey);
      if ((idleCached ?? '').isNotEmpty) {
        IdleDeepLinkFromPush = idleCached;
      }
    } catch (_) {}
  }

  Future<void> IdleSaveCachedDeep(String uri) async {
    try {
      final SharedPreferences idlePrefs = await SharedPreferences.getInstance();
      await idlePrefs.setString(idleCachedDeepKey, uri);
    } catch (_) {}
  }

  Future<void> IdleSendLoadedOnce({
    required String url,
    required int timestart,
  }) async {
    if (IdleLoadedOnceSent) return;

    final int idleNow = DateTime.now().millisecondsSinceEpoch;

    await IdlePostStat(
      event: 'Loaded',
      timeStart: timestart,
      timeFinish: idleNow,
      url: url,
      appSid: IdleAnalyticsSpyInstance.IdleAppsFlyerUid,
      firstPageLoadTs: IdleFirstPageTimestamp,
    );

    await IdleSaveLoadedFlag();
  }

  void IdleBootHarbor() {
    IdleStartWarmProgress();
    IdleWireFcmHandlers();
    IdleAnalyticsSpyInstance.IdleStartTracking(
      onUpdate: () => setState(() {}),
    );
    IdleBindNotificationTap();
    IdlePrepareDeviceProfile();
  }

  void IdleWireFcmHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage idleMessage) async {
      final dynamic idleLink = idleMessage.data['uri'];
      if (idleLink != null) {
        final String idleUri = idleLink.toString();
        IdleDeepLinkFromPush = idleUri;
        await IdleSaveCachedDeep(idleUri);
      } else {
        IdleResetHomeAfterDelay();
      }
    });

    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage idleMessage) async {
      final dynamic idleLink = idleMessage.data['uri'];
      if (idleLink != null) {
        final String idleUri = idleLink.toString();
        IdleDeepLinkFromPush = idleUri;
        await IdleSaveCachedDeep(idleUri);

        IdleNavigateToUri(idleUri);

        await IdlePushDeviceInfo();
        await IdlePushAppsFlyerData();
      } else {
        IdleResetHomeAfterDelay();
      }
    });
  }

  void IdleBindNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNotificationTap') {
        final Map<String, dynamic> idlePayload =
        Map<String, dynamic>.from(call.arguments);
        final String? idleUriRaw = idlePayload['uri']?.toString();

        if (idleUriRaw != null &&
            idleUriRaw.isNotEmpty &&
            !idleUriRaw.contains('Нет URI')) {
          final String idleUri = idleUriRaw;
          IdleDeepLinkFromPush = idleUri;
          await IdleSaveCachedDeep(idleUri);

          if (!context.mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext context) => NcupTableView(idleUri),
            ),
                (Route<dynamic> route) => false,
          );

          await IdlePushDeviceInfo();
          await IdlePushAppsFlyerData();
        }
      }
    });
  }

  Future<void> IdlePrepareDeviceProfile() async {
    try {
      await IdleDeviceProfileInstance.IdleInitialize();

      final FirebaseMessaging idleMessaging = FirebaseMessaging.instance;
      final NotificationSettings idleSettings =
      await idleMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      IdleDeviceProfileInstance.IdlePushEnabled =
          idleSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              idleSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;

      await IdleLoadLoadedFlag();
      await IdleLoadCachedDeep();

      IdleBosunInstance = IdleBosunViewModel(
        IdleDeviceProfileInstance: IdleDeviceProfileInstance,
        IdleAnalyticsSpyInstance: IdleAnalyticsSpyInstance,
      );

      IdleCourier = IdleCourierService(
        IdleBosun: IdleBosunInstance!,
        IdleGetWebViewController: () => IdleWebViewController,
      );
    } catch (error) {
      IdleLoggerService().IdleLogError('prepareDeviceProfile fail: $error');
    }
  }

  void IdleNavigateToUri(String link) async {
    try {
      await IdleWebViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(link)),
      );
    } catch (error) {
      IdleLoggerService().IdleLogError('navigate error: $error');
    }
  }

  void IdleResetHomeAfterDelay() {
    Future<void>.delayed(const Duration(seconds: 3), () {
      try {
        IdleWebViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(IdleHomeUrl)),
        );
      } catch (_) {}
    });
  }

  String? _resolveTokenForShip() {
    if (widget.IdleSignal != null && widget.IdleSignal!.isNotEmpty) {
      return widget.IdleSignal;
    }
    return null;
  }

  Future<void> _sendAllDataToPageTwice() async {
    await IdlePushDeviceInfo();

    Future<void>.delayed(const Duration(seconds: 6), () async {
      await IdlePushDeviceInfo();
      await IdlePushAppsFlyerData();
    });
  }

  Future<void> IdlePushDeviceInfo() async {
    final String? idleToken = _resolveTokenForShip();

    try {
      await IdleCourier?.IdlePutDeviceToLocalStorage(idleToken);
    } catch (error) {
      IdleLoggerService().IdleLogError('pushDeviceInfo error: $error');
    }
  }

  Future<void> IdlePushAppsFlyerData() async {
    final String? idleToken = _resolveTokenForShip();

    try {
      await IdleCourier?.IdleSendRawToPage(
        idleToken,
        deepLink: IdleDeepLinkFromPush,
      );
    } catch (error) {
      IdleLoggerService().IdleLogError('pushAppsFlyerData error: $error');
    }
  }

  void IdleStartWarmProgress() {
    int idleTick = 0;
    IdleWarmProgress = 0.0;

    IdleWarmTimer =
        Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
          if (!mounted) return;

          setState(() {
            idleTick++;
            IdleWarmProgress = idleTick / (IdleWarmSeconds * 10);

            if (IdleWarmProgress >= 1.0) {
              IdleWarmProgress = 1.0;
              IdleWarmTimer.cancel();
            }
          });
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      IdleSleepAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      if (Platform.isIOS && IdleSleepAt != null) {
        final DateTime idleNow = DateTime.now();
        final Duration idleDrift = idleNow.difference(IdleSleepAt!);

        if (idleDrift > const Duration(minutes: 25)) {
          IdleReboardHarbor();
        }
      }
      IdleSleepAt = null;
    }
  }

  void IdleReboardHarbor() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<Widget>(
          builder: (BuildContext context) =>
              IdleHarbor(IdleSignal: widget.IdleSignal),
        ),
            (Route<dynamic> route) => false,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    IdleWarmTimer.cancel();

    _parentInstallTimer?.cancel();
    _popupInstallTimer?.cancel();

    IdleWebViewController = null;
    IdlePopupWebViewController = null;

    super.dispose();
  }

  // ===================== Email / mailto =====================

  bool IdleIsBareEmail(Uri uri) {
    final String idleScheme = uri.scheme;
    if (idleScheme.isNotEmpty) return false;
    final String idleRaw = uri.toString();
    return idleRaw.contains('@') && !idleRaw.contains(' ');
  }

  Uri IdleToMailto(Uri uri) {
    final String idleFull = uri.toString();
    final List<String> idleParts = idleFull.split('?');
    final String idleEmail = idleParts.first;
    final Map<String, String> idleQueryParams = idleParts.length > 1
        ? Uri.splitQueryString(idleParts[1])
        : <String, String>{};

    return Uri(
      scheme: 'mailto',
      path: idleEmail,
      queryParameters: idleQueryParams.isEmpty ? null : idleQueryParams,
    );
  }

  Future<bool> IdleOpenMailExternal(Uri mailto) async {
    try {
      final String scheme = mailto.scheme.toLowerCase();
      final String path = mailto.path.toLowerCase();

      IdleLoggerService().IdleLogInfo(
          'IdleOpenMailExternal: scheme=$scheme path=$path uri=$mailto');

      if (scheme != 'mailto') {
        final bool ok = await launchUrl(
          mailto,
          mode: LaunchMode.externalApplication,
        );
        IdleLoggerService()
            .IdleLogInfo('IdleOpenMailExternal: non-mailto result=$ok');
        return ok;
      }

      final bool can = await canLaunchUrl(mailto);
      IdleLoggerService()
          .IdleLogInfo('IdleOpenMailExternal: canLaunchUrl(mailto) = $can');

      if (can) {
        final bool ok = await launchUrl(
          mailto,
          mode: LaunchMode.externalApplication,
        );
        IdleLoggerService()
            .IdleLogInfo('IdleOpenMailExternal: externalApplication result=$ok');
        if (ok) return true;
      }

      IdleLoggerService().IdleLogWarn(
          'IdleOpenMailExternal: no native handler for mailto, fallback to Gmail Web');
      final Uri gmailUri = IdleGmailizeMailto(mailto);
      final bool webOk = await IdleOpenWeb(gmailUri);
      IdleLoggerService()
          .IdleLogInfo('IdleOpenMailExternal: Gmail Web fallback result=$webOk');
      return webOk;
    } catch (e, st) {
      IdleLoggerService()
          .IdleLogError('IdleOpenMailExternal error: $e\n$st; url=$mailto');
      return false;
    }
  }

  Future<bool> IdleOpenMailWeb(Uri mailto) async {
    final Uri idleGmailUri = IdleGmailizeMailto(mailto);
    return IdleOpenWeb(idleGmailUri);
  }

  Uri IdleGmailizeMailto(Uri mailUri) {
    final Map<String, String> idleQueryParams = mailUri.queryParameters;

    final Map<String, String> idleParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (mailUri.path.isNotEmpty) 'to': mailUri.path,
      if ((idleQueryParams['subject'] ?? '').isNotEmpty)
        'su': idleQueryParams['subject']!,
      if ((idleQueryParams['body'] ?? '').isNotEmpty)
        'body': idleQueryParams['body']!,
      if ((idleQueryParams['cc'] ?? '').isNotEmpty)
        'cc': idleQueryParams['cc']!,
      if ((idleQueryParams['bcc'] ?? '').isNotEmpty)
        'bcc': idleQueryParams['bcc']!,
    };

    return Uri.https('mail.google.com', '/mail/', idleParams);
  }

  bool IdleIsPlatformLink(Uri uri) {
    final String idleScheme = uri.scheme.toLowerCase();
    if (IdleSpecialSchemes.contains(idleScheme)) {
      return true;
    }

    if (idleScheme == 'http' || idleScheme == 'https') {
      final String idleHost = uri.host.toLowerCase();

      if (IdleExternalHosts.contains(idleHost)) {
        return true;
      }

      if (idleHost.endsWith('t.me')) return true;
      if (idleHost.endsWith('wa.me')) return true;
      if (idleHost.endsWith('m.me')) return true;
      if (idleHost.endsWith('signal.me')) return true;
      if (idleHost.endsWith('facebook.com')) return true;
      if (idleHost.endsWith('instagram.com')) return true;
      if (idleHost.endsWith('twitter.com')) return true;
      if (idleHost.endsWith('x.com')) return true;
    }

    return false;
  }

  String IdleDigitsOnly(String source) =>
      source.replaceAll(RegExp(r'[^0-9+]'), '');

  Uri IdleHttpizePlatformUri(Uri uri) {
    final String idleScheme = uri.scheme.toLowerCase();

    if (idleScheme == 'tg' || idleScheme == 'telegram') {
      final Map<String, String> idleQp = uri.queryParameters;
      final String? idleDomain = idleQp['domain'];

      if (idleDomain != null && idleDomain.isNotEmpty) {
        return Uri.https(
          't.me',
          '/$idleDomain',
          <String, String>{
            if (idleQp['start'] != null) 'start': idleQp['start']!,
          },
        );
      }

      final String idlePath = uri.path.isNotEmpty ? uri.path : '';

      return Uri.https(
        't.me',
        '/$idlePath',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    if ((idleScheme == 'http' || idleScheme == 'https') &&
        uri.host.toLowerCase().endsWith('t.me')) {
      return uri;
    }

    if (idleScheme == 'viber') {
      return uri;
    }

    if (idleScheme == 'whatsapp') {
      final Map<String, String> idleQp = uri.queryParameters;
      final String? idlePhone = idleQp['phone'];
      final String? idleText = idleQp['text'];

      if (idlePhone != null && idlePhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${IdleDigitsOnly(idlePhone)}',
          <String, String>{
            if (idleText != null && idleText.isNotEmpty) 'text': idleText,
          },
        );
      }

      return Uri.https(
        'wa.me',
        '/',
        <String, String>{
          if (idleText != null && idleText.isNotEmpty) 'text': idleText,
        },
      );
    }

    if ((idleScheme == 'http' || idleScheme == 'https') &&
        (uri.host.toLowerCase().endsWith('wa.me') ||
            uri.host.toLowerCase().endsWith('whatsapp.com'))) {
      return uri;
    }

    if (idleScheme == 'skype') {
      return uri;
    }

    if (idleScheme == 'fb-messenger') {
      final String idlePath =
      uri.pathSegments.isNotEmpty ? uri.pathSegments.join('/') : '';
      final Map<String, String> idleQp = uri.queryParameters;

      final String idleId = idleQp['id'] ?? idleQp['user'] ?? idlePath;

      if (idleId.isNotEmpty) {
        return Uri.https(
          'm.me',
          '/$idleId',
          uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      }

      return Uri.https(
        'm.me',
        '/',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    if (idleScheme == 'sgnl') {
      final Map<String, String> idleQp = uri.queryParameters;
      final String? idlePhone = idleQp['phone'];
      final String? idleUsername = idleQp['username'];

      if (idlePhone != null && idlePhone.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#p/${IdleDigitsOnly(idlePhone)}',
        );
      }

      if (idleUsername != null && idleUsername.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#u/$idleUsername',
        );
      }

      final String idlePath = uri.pathSegments.join('/');
      if (idlePath.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/$idlePath',
          uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      }

      return uri;
    }

    if (idleScheme == 'tel') {
      return Uri.parse('tel:${IdleDigitsOnly(uri.path)}');
    }

    if (idleScheme == 'mailto') {
      return uri;
    }

    if (idleScheme == 'bnl') {
      final String idleNewPath = uri.path.isNotEmpty ? uri.path : '';
      return Uri.https(
        'bnl.com',
        '/$idleNewPath',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    return uri;
  }

  Future<bool> IdleOpenWeb(Uri uri) async {
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

  Future<bool> IdleOpenExternal(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      return false;
    }
  }

  void IdleHandleServerSavedata(String savedata) {
    print('onServerResponse savedata: $savedata');

    if(savedata=='false'){
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
          LoungeHomePage(),
        ),
      );
    }
  }

  Color _parseHexColor(String hex) {
    String value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) {
      value = 'FF$value';
    }
    final intColor = int.tryParse(value, radix: 16) ?? 0xFF000000;
    return Color(intColor);
  }

  Future<void> _updateAppDataInLocalStorageFromProfile() async {
    final InAppWebViewController? controller = IdleWebViewController;
    if (controller == null) return;

    final String? token = _resolveTokenForShip();
    final Map<String, dynamic> map =
    IdleDeviceProfileInstance.IdleToMap(fcmToken: token);

    IdleLoggerService()
        .IdleLogInfo('updateAppDataFromProfile: ${jsonEncode(map)}');

    await IdleSaveJsonToLocalStorageAndPrefs(
      controller: controller,
      key: 'app_data',
      data: map,
    );
  }

  void _updateExtraDataFromServerPayload(Map<dynamic, dynamic> root) {
    try {
      final dynamic adataRaw = root['adata'];
      if (adataRaw is Map) {
        final Map adata = adataRaw;

        final dynamic buttonswlRaw = adata['buttonswl'];
        if (buttonswlRaw is List) {
          final List<String> list = buttonswlRaw
              .where((e) => e != null)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
          setState(() {
            _buttonWhitelist = list;
          });
          IdleLoggerService()
              .IdleLogInfo('buttonswl updated: $_buttonWhitelist');
          _updateBackButtonVisibility();
        }

        // --------- НОВОЕ: fpscashier из adata → профиль → localStorage ---------
        if (adata.containsKey('fpscashier')) {
          final dynamic fpsRaw = adata['fpscashier'];
          bool? fpsValue;

          if (fpsRaw is bool) {
            fpsValue = fpsRaw;
          } else if (fpsRaw is num) {
            fpsValue = fpsRaw != 0;
          } else if (fpsRaw is String) {
            final String v = fpsRaw.toLowerCase().trim();
            if (v == 'true' || v == '1' || v == 'yes') fpsValue = true;
            if (v == 'false' || v == '0' || v == 'no') fpsValue = false;
          }

          if (fpsValue != null) {
            IdleDeviceProfileInstance.safecasher = fpsValue;
            IdleLoggerService().IdleLogInfo(
                'fpscashier updated from server payload: $fpsValue');
            // Перезаписываем app_data в localStorage + SharedPrefs
            _updateAppDataInLocalStorageFromProfile();
          }
        }
        // -----------------------------------------------------------------------

        // savels (если сервер будет слать именно savels)
        final dynamic savelsRaw = adata['savels'];
        if (savelsRaw is Map) {
          IdleDeviceProfileInstance.IdleSavels =
          Map<String, dynamic>.from(savelsRaw);
          IdleLoggerService().IdleLogInfo(
              'savels stored in profile: ${IdleDeviceProfileInstance.IdleSavels}');
          _updateAppDataInLocalStorageFromProfile();
        }
      }
    } catch (e, st) {
      IdleLoggerService()
          .IdleLogError('Error in _updateExtraDataFromServerPayload: $e\n$st');
    }
  }

  void _updateSafeAreaFromServerPayload(Map<dynamic, dynamic> root) {
    IdleLoggerService()
        .IdleLogInfo('SAFEAREA RAW PAYLOAD: ${jsonEncode(root)}');

    bool? safearea;
    String? bgLightHex;
    String? bgDarkHex;

    final dynamic content = root['content'];
    if (content is Map) {
      if (content['safearea'] != null) {
        final dynamic raw = content['safearea'];
        if (raw is bool) {
          safearea = raw;
        } else if (raw is String) {
          final String v = raw.toLowerCase().trim();
          if (v == 'true' || v == '1' || v == 'yes') safearea = true;
          if (v == 'false' || v == '0' || v == 'no') safearea = false;
        } else if (raw is num) {
          safearea = raw != 0;
        }
      }

      if (content['safearea_color'] != null &&
          content['safearea_color'].toString().trim().isNotEmpty) {
        bgLightHex = content['safearea_color'].toString().trim();
        bgDarkHex = bgLightHex;
      }
    }

    final dynamic adata = root['adata'];
    if (adata is Map) {
      if (safearea == null && adata['safearea'] != null) {
        final dynamic raw = adata['safearea'];
        if (raw is bool) {
          safearea = raw;
        } else if (raw is String) {
          final String v = raw.toLowerCase().trim();
          if (v == 'true' || v == '1' || v == 'yes') safearea = true;
          if (v == 'false' || v == '0' || v == 'no') safearea = false;
        } else if (raw is num) {
          safearea = raw != 0;
        }
      }

      if (adata['bgsareaw'] != null &&
          adata['bgsareaw'].toString().trim().isNotEmpty) {
        bgLightHex = adata['bgsareaw'].toString().trim();
      }
      if (adata['bgsareab'] != null &&
          adata['bgsareab'].toString().trim().isNotEmpty) {
        bgDarkHex = adata['bgsareab'].toString().trim();
      }
    }

    if (safearea == null && root['safearea'] != null) {
      final dynamic raw = root['safearea'];
      if (raw is bool) {
        safearea = raw;
      } else if (raw is String) {
        final String v = raw.toLowerCase().trim();
        if (v == 'true' || v == '1' || v == 'yes') safearea = true;
        if (v == 'false' || v == '0' || v == 'no') safearea = false;
      } else if (raw is num) {
        safearea = raw != 0;
      }
    }

    IdleLoggerService().IdleLogInfo(
        'SAFEAREA PARSED: enabled=$safearea, light=$bgLightHex, dark=$bgDarkHex');

    if (safearea == null) {
      return;
    }

    final Brightness platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    String? chosenHex;
    if (platformBrightness == Brightness.light) {
      chosenHex = bgLightHex ?? bgDarkHex;
    } else {
      chosenHex = bgDarkHex ?? bgLightHex;
    }

    final bool enabled = safearea;
    Color background =
    enabled ? const Color(0xFF1A1A22) : const Color(0xFF000000);

    if (enabled && chosenHex != null && chosenHex.isNotEmpty) {
      background = _parseHexColor(chosenHex);
    }

    setState(() {
      _safeAreaEnabled = enabled;
      _safeAreaBackgroundColor = background;
      IdleDeviceProfileInstance.IdleSafeAreaEnabled = enabled;
      IdleDeviceProfileInstance.IdleSafeAreaColor =
      enabled ? (chosenHex ?? '#1A1A22') : '';
    });

    IdleLoggerService().IdleLogInfo(
        'SAFEAREA STATE UPDATED: enabled=$_safeAreaEnabled, color=$_safeAreaBackgroundColor (brightness=$platformBrightness)');
  }

  // ============================================================
  // back button whitelist
  // ============================================================

  bool _matchesButtonWhitelist(String url) {
    if (url.isEmpty) return false;
    if (_buttonWhitelist.isEmpty) return false;
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }

    final String host = uri.host.toLowerCase();
    final String full = uri.toString();

    for (final String item in _buttonWhitelist) {
      final String trimmed = item.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        if (full.startsWith(trimmed)) return true;
      } else {
        final String domain = trimmed.toLowerCase();
        if (host == domain || host.endsWith('.$domain')) return true;
      }
    }

    return false;
  }

  Future<void> _updateBackButtonVisibility() async {
    final String current = _currentUrl ?? IdleCurrentUrl;
    final bool shouldShow = _matchesButtonWhitelist(current);

    if (_backButtonHiddenAfterTap) {
      _backButtonHiddenAfterTap = false;
    }

    if (shouldShow != _showBackButton) {
      if (mounted) {
        setState(() {
          _showBackButton = shouldShow;
        });
      } else {
        _showBackButton = shouldShow;
      }
    }
  }

  Future<void> _handleBackButtonPressed() async {
    if (mounted) {
      setState(() {
        _backButtonHiddenAfterTap = true;
        _showBackButton = false;
      });
    } else {
      _backButtonHiddenAfterTap = true;
      _showBackButton = false;
    }

    if (_isPopupVisible) {
      await _handlePopupBackPressed();
      return;
    }

    if (IdleWebViewController == null) return;
    try {
      if (await IdleWebViewController!.canGoBack()) {
        await IdleWebViewController!.goBack();
      } else {
        await IdleWebViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(IdleHomeUrl)),
        );
      }
    } catch (e, st) {
      IdleLoggerService()
          .IdleLogError('Error on back button pressed: $e\n$st');
    }
  }

  // ============================================================
  // ============== window.open / popup / newTab JSON ===========
  // ============================================================

  InAppWebViewSettings _mainWebViewSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      isInspectable: true,
      disableDefaultErrorPage: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowsPictureInPictureMediaPlayback: true,
      useOnDownloadStart: true,
      javaScriptCanOpenWindowsAutomatically: true,
      useShouldOverrideUrlLoading: true,
      supportMultipleWindows: true,
      transparentBackground: true,
      thirdPartyCookiesEnabled: true,
      sharedCookiesEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      allowsBackForwardNavigationGestures: true,
    );
  }

  InAppWebViewSettings _popupWebViewSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      isInspectable: true,
      disableDefaultErrorPage: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowsPictureInPictureMediaPlayback: true,
      useOnDownloadStart: true,
      javaScriptCanOpenWindowsAutomatically: true,
      useShouldOverrideUrlLoading: true,
      supportMultipleWindows: true,
      transparentBackground: false,
      thirdPartyCookiesEnabled: true,
      sharedCookiesEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      allowsBackForwardNavigationGestures: true,
    );
  }

  Future<void> _safeEvaluateJavascript(
      InAppWebViewController? controller, {
        required String source,
        String debugName = 'js',
      }) async {
    if (controller == null) return;
    if (!mounted) return;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      await controller.evaluateJavascript(source: source);
    } catch (e) {
      print('WERLOG: safeEvaluateJavascript error [$debugName]: $e');
    }
  }

  Future<void> _installJsErrorLogger(InAppWebViewController controller) async {
    await _safeEvaluateJavascript(
      controller,
      debugName: 'installJsErrorLogger',
      source: r'''
        (function() {
          if (window.__ncupJsLoggerInstalled) return;
          window.__ncupJsLoggerInstalled = true;

          function serializeError(err) {
            try {
              if (!err) return null;
              var plain = {};
              Object.getOwnPropertyNames(err).forEach(function(key) {
                plain[key] = err[key];
              });
              return plain;
            } catch (_) {
              return { message: String(err) };
            }
          }

          window.onerror = function(message, source, lineno, colno, error) {
            try {
              var payload = {
                type: 'onerror',
                message: String(message || ''),
                source: String(source || ''),
                lineno: lineno || 0,
                colno: colno || 0,
                error: serializeError(error)
              };
              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                window.flutter_inappwebview.callHandler('NcupJSLogger', payload);
              }
            } catch (e) {
              console.log('NcupJSLogger onerror inner fail', e);
            }
          };

          window.addEventListener('unhandledrejection', function(event) {
            try {
              var reason = event.reason;
              var payload = {
                type: 'unhandledrejection',
                reason: serializeError(reason) || { message: String(reason || '') }
              };
              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                window.flutter_inappwebview.callHandler('NcupPostMessage', payload);
              }
            } catch (e) {
              console.log('NcupJSLogger unhandledrejection inner fail', e);
            }
          });
        })();
      ''',
    );
  }

  Future<void> _installPostMessageBridge(
      InAppWebViewController controller, {
        required String label,
      }) async {
    await _safeEvaluateJavascript(
      controller,
      debugName: 'installPostMessageBridge-$label',
      source: '''
        (function() {
          if (window.__ncupPostMessageBridgeInstalled_$label) return;
          window.__ncupPostMessageBridgeInstalled_$label = true;

          window.addEventListener('message', function(event) {
            try {
              var dataRaw = event.data;
              var dataString;
              try {
                dataString = JSON.stringify(dataRaw);
              } catch (e) {
                dataString = String(dataRaw);
              }

              var payload = {
                label: '$label',
                origin: String(event.origin || ''),
                data: dataString,
                href: String(window.location.href || '')
              };

              console.log('[NCUP postMessage $label]', payload);

              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                window.flutter_inappwebview.callHandler('NcupPostMessage', payload);
              }

              try {
                var parsed = dataRaw;
                if (typeof parsed === 'string') {
                  parsed = JSON.parse(parsed);
                }
                if (parsed && parsed.type === 'newTab' && parsed.url) {
                  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                    window.flutter_inappwebview.callHandler('NcupCheckoutAction', parsed);
                  }
                }
              } catch (_) {}
            } catch (e) {
              console.log('NcupPostMessage bridge error', e);
            }
          });
        })();
      ''',
    );
  }

  Future<void> _installCheckoutInterceptor(
      InAppWebViewController controller,
      ) async {
    await _safeEvaluateJavascript(
      controller,
      debugName: 'installCheckoutInterceptor',
      source: r'''
        (function() {
          if (window.__ncupCheckoutInterceptorInstalled) return;
          window.__ncupCheckoutInterceptorInstalled = true;

          function sendToFlutter(data) {
            try {
              if (!data || typeof data !== 'object') return;
              if (data.type === 'newTab' && data.url) {
                console.log('[NCUP checkout interceptor] newTab:', data.url);
                if (
                  window.flutter_inappwebview &&
                  window.flutter_inappwebview.callHandler
                ) {
                  window.flutter_inappwebview.callHandler(
                    'NcupCheckoutAction',
                    data
                  );
                }
              }
            } catch (e) {
              console.log('[NCUP checkout interceptor] send error', e);
            }
          }

          function tryParseMaybeJson(value) {
            try {
              if (!value) return null;
              if (typeof value === 'object') {
                return value;
              }
              if (typeof value === 'string') {
                return JSON.parse(value);
              }
              return null;
            } catch (e) {
              return null;
            }
          }

          function tryHandlePayload(payload) {
            try {
              var data = tryParseMaybeJson(payload);
              if (!data) return;

              if (Array.isArray(data)) {
                data.forEach(function(item) {
                  if (item && item.type === 'newTab' && item.url) {
                    sendToFlutter(item);
                  }
                });
                return;
              }

              if (data.type === 'newTab' && data.url) {
                sendToFlutter(data);
                return;
              }

              if (data.savedata) {
                var saved = tryParseMaybeJson(data.savedata);
                if (saved && saved.type === 'newTab' && saved.url) {
                  sendToFlutter(saved);
                  return;
                }
              }

              if (data.data) {
                var nested = tryParseMaybeJson(data.data);
                if (nested && nested.type === 'newTab' && nested.url) {
                  sendToFlutter(nested);
                  return;
                }
              }

              if (data.content) {
                var content = tryParseMaybeJson(data.content);
                if (content && content.type === 'newTab' && content.url) {
                  sendToFlutter(content);
                  return;
                }
              }
            } catch (e) {
              console.log('[NCUP checkout interceptor] handle error', e);
            }
          }

          var originalFetch = window.fetch;
          if (originalFetch) {
            window.fetch = function() {
              return originalFetch.apply(this, arguments).then(function(response) {
                try {
                  var cloned = response.clone();
                  cloned.text().then(function(text) {
                    tryHandlePayload(text);
                  }).catch(function() {});
                } catch (e) {}
                return response;
              });
            };
          }

          var OriginalXHR = window.XMLHttpRequest;
          if (OriginalXHR) {
            window.XMLHttpRequest = function() {
              var xhr = new OriginalXHR();
              var originalOpen = xhr.open;
              var originalSend = xhr.send;

              xhr.open = function() {
                return originalOpen.apply(xhr, arguments);
              };

              xhr.send = function() {
                xhr.addEventListener('load', function() {
                  try {
                    tryHandlePayload(xhr.responseText);
                  } catch (e) {}
                });
                return originalSend.apply(xhr, arguments);
              };

              return xhr;
            };
          }

          var originalOpen = window.open;
          window.open = function(url, target, features) {
            try {
              console.log('[NCUP window.open intercepted]', url, target, features);
            } catch (e) {}

            if (originalOpen) {
              return originalOpen.apply(window, arguments);
            }
            return null;
          };
        })();
      ''',
    );
  }

  Future<void> _installLocalStorageHook(
      InAppWebViewController controller) async {
    await _safeEvaluateJavascript(
      controller,
      debugName: 'installLocalStorageHook',
      source: r'''
        (function() {
          if (window.__ncupLocalStorageHookInstalled) return;
          window.__ncupLocalStorageHookInstalled = true;

          try {
            var originalSetItem = window.localStorage.setItem;
            window.localStorage.setItem = function(key, value) {
              try {
                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                  window.flutter_inappwebview.callHandler('NcupLocalStorageSetItem', {
                    key: String(key),
                    value: String(value)
                  });
                }
              } catch (e) {
                console.log('Ncup localStorage hook error', e);
              }
              return originalSetItem.apply(this, arguments);
            };
          } catch (e) {
            console.log('Ncup localStorage hook init error', e);
          }
        })();
      ''',
    );
  }

  Future<void> _safeInstallAll(
      InAppWebViewController? controller, {
        required String label,
      }) async {
    if (controller == null) return;
    if (!mounted) return;

    try {
      await Future<void>.delayed(
        label == 'popup'
            ? const Duration(milliseconds: 550)
            : const Duration(milliseconds: 250),
      );
      if (!mounted) return;
      await _installJsErrorLogger(controller);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      await _installPostMessageBridge(controller, label: label);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      await _installCheckoutInterceptor(controller);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      await _installLocalStorageHook(controller);
    } catch (e) {
      print('WERLOG: safeInstallAll error label=$label error=$e');
    }
  }

  void _scheduleSafeInstall(
      InAppWebViewController controller, {
        required String label,
      }) {
    if (label == 'popup') {
      _popupInstallTimer?.cancel();
      _popupInstallTimer =
          Timer(const Duration(milliseconds: 450), () async {
            if (!mounted) return;
            await _safeInstallAll(controller, label: label);
          });
    } else {
      _parentInstallTimer?.cancel();
      _parentInstallTimer =
          Timer(const Duration(milliseconds: 250), () async {
            if (!mounted) return;
            await _safeInstallAll(controller, label: label);
          });
    }
  }

  Map<String, dynamic>? _tryDecodeMap(dynamic value) {
    try {
      if (value == null) return null;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _openExternalForJsonNewTab(Uri uri) async {
    if (_isAboutBlankUri(uri)) return false;

    final String url = uri.toString();

    if (_handledNewTabUrls.contains(url)) {
      print('WERLOG: duplicate JSON newTab ignored url=$url');
      return true;
    }

    _handledNewTabUrls.add(url);

    if (_isOpeningExternalNewTab) {
      print('WERLOG: external newTab already opening, ignored url=$url');
      return false;
    }

    _isOpeningExternalNewTab = true;

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      print('WERLOG: JSON newTab external launched=$launched url=$url');
      return launched;
    } catch (e) {
      print('WERLOG: JSON newTab external error=$e url=$url');
      return false;
    } finally {
      Future<void>.delayed(const Duration(seconds: 2), () {
        _isOpeningExternalNewTab = false;
      });
    }
  }

  Future<bool> _handleCheckoutAction(dynamic rawPayload) async {
    try {
      Map<String, dynamic>? data = _tryDecodeMap(rawPayload);
      if (data == null) return false;

      if (data.containsKey('savedata')) {
        final Map<String, dynamic>? savedataMap =
        _tryDecodeMap(data['savedata']);
        if (savedataMap != null) {
          data = savedataMap;
        }
      }

      if (data.containsKey('data')) {
        final Map<String, dynamic>? dataMap = _tryDecodeMap(data['data']);
        if (dataMap != null &&
            dataMap['type']?.toString() == 'newTab' &&
            (dataMap['url']?.toString() ?? '').isNotEmpty) {
          data = dataMap;
        }
      }

      if (data.containsKey('content')) {
        final Map<String, dynamic>? contentMap =
        _tryDecodeMap(data['content']);
        if (contentMap != null &&
            contentMap['type']?.toString() == 'newTab' &&
            (contentMap['url']?.toString() ?? '').isNotEmpty) {
          data = contentMap;
        }
      }

      final String type = data['type']?.toString() ?? '';
      final String url = data['url']?.toString() ?? '';

      if (type == 'newTab' && url.isNotEmpty) {
        final Uri? uri = Uri.tryParse(url);
        if (uri == null || _isAboutBlankUri(uri)) {
          print('WERLOG: invalid JSON newTab uri=$url');
          return false;
        }

        print('WERLOG: handle JSON newTab url=$url');
        await _openExternalForJsonNewTab(uri);
        return true;
      }

      return false;
    } catch (e) {
      print('WERLOG: handleCheckoutAction error: $e');
      return false;
    }
  }

  Future<bool> _onCreateWindowHandler(
      InAppWebViewController controller,
      CreateWindowAction request,
      ) async {
    final Uri? idleUri = request.request.url;
    final String urlString = idleUri?.toString() ?? '';

    print(
      'WERLOG: MAIN onCreateWindow '
          'windowId=${request.windowId} '
          'url=$urlString '
          'isDialog=${request.isDialog} '
          'hasGesture=${request.hasGesture}',
    );

    if (idleUri != null) {
      _currentUrl = idleUri.toString();
      await _updateBackButtonVisibility();

      if (_isGoogleUrl(idleUri)) {
        // popup откроется, UA для popup установится в onWebViewCreated popup
      }

      if (IdleIsBankScheme(idleUri) ||
          ((idleUri.scheme == 'http' || idleUri.scheme == 'https') &&
              IdleIsBankDomain(idleUri))) {
        await IdleOpenBank(idleUri);
        return false;
      }

      if (IdleIsBareEmail(idleUri)) {
        final Uri idleMailto = IdleToMailto(idleUri);
        await IdleOpenMailExternal(idleMailto);
        return false;
      }

      final String idleScheme = idleUri.scheme.toLowerCase();

      if (idleScheme == 'mailto') {
        await IdleOpenMailExternal(idleUri);
        return false;
      }

      if (idleScheme == 'tel') {
        await launchUrl(idleUri, mode: LaunchMode.externalApplication);
        return false;
      }

      final String host = idleUri.host.toLowerCase();
      final bool idleIsSocial = host.endsWith('facebook.com') ||
          host.endsWith('instagram.com') ||
          host.endsWith('twitter.com') ||
          host.endsWith('x.com');

      if (idleIsSocial) {
        await IdleOpenExternal(idleUri);
        return false;
      }

      if (IdleIsPlatformLink(idleUri)) {
        final Uri idleWebUri = IdleHttpizePlatformUri(idleUri);
        await IdleOpenExternal(idleWebUri);
        return false;
      }
    }

    if (!mounted) return false;

    setState(() {
      _popupCreateAction = request;
      _popupUrl = urlString.isNotEmpty && !_isAboutBlankUrl(urlString)
          ? urlString
          : null;
      _popupCurrentUrl = _popupUrl;
      _isPopupVisible = true;
      _popupCanGoBack = false;
    });

    return true;
  }

  Future<bool> _onPopupCreateWindowHandler(
      InAppWebViewController controller,
      CreateWindowAction createWindowAction,
      ) async {
    final Uri? uri = createWindowAction.request.url;
    final String urlString = uri?.toString() ?? '';

    print(
      'WERLOG: POPUP onCreateWindow '
          'windowId=${createWindowAction.windowId} '
          'url=$urlString',
    );

    if (!mounted) return false;

    if (createWindowAction.windowId != null) {
      setState(() {
        _popupCreateAction = createWindowAction;
        _popupUrl = urlString.isNotEmpty && !_isAboutBlankUrl(urlString)
            ? urlString
            : _popupUrl;
        _popupCurrentUrl = _popupUrl;
        _isPopupVisible = true;
      });
      return true;
    }

    if (urlString.isNotEmpty && !_isAboutBlankUrl(urlString)) {
      try {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(urlString)),
        );
      } catch (e) {
        print('WERLOG: popup inner window.open load error: $e url=$urlString');
      }
    }

    return false;
  }

  void _closePopup() {
    setState(() {
      _isPopupVisible = false;
      _popupUrl = null;
      _popupCurrentUrl = null;
      _popupCreateAction = null;
      _popupCanGoBack = false;
      IdlePopupWebViewController = null;
    });
  }

  Future<void> _closePopupAndNotifyParent({
    String reason = 'closed_by_user',
  }) async {
    try {
      await IdleWebViewController?.evaluateJavascript(
        source: '''
          try {
            window.dispatchEvent(new MessageEvent('message', {
              data: ${jsonEncode({
          'type': 'ncup_popup_closed',
          'reason': reason,
        })},
              origin: window.location.origin
            }));
          } catch(e) {
            console.log('ncup popup close notify failed', e);
          }
        ''',
      );
    } catch (e) {
      print('WERLOG: closePopup notify parent error: $e');
    }
    _closePopup();
  }

  Future<void> _refreshPopupCanGoBack() async {
    final InAppWebViewController? c = IdlePopupWebViewController;
    if (c == null) {
      if (_popupCanGoBack && mounted) {
        setState(() {
          _popupCanGoBack = false;
        });
      }
      return;
    }
    try {
      final bool can = await c.canGoBack();
      if (!mounted) return;
      if (can != _popupCanGoBack) {
        setState(() {
          _popupCanGoBack = can;
        });
      }
    } catch (e) {
      print('WERLOG: _refreshPopupCanGoBack error: $e');
    }
  }

  Future<void> _handlePopupBackPressed() async {
    final InAppWebViewController? c = IdlePopupWebViewController;
    if (c == null) {
      _closePopup();
      return;
    }
    try {
      if (await c.canGoBack()) {
        await c.goBack();
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          _refreshPopupCanGoBack();
        });
      } else {
        await _closePopupAndNotifyParent(reason: 'popup_back_no_history');
      }
    } catch (e) {
      print('WERLOG: _handlePopupBackPressed error: $e');
      _closePopup();
    }
  }

  bool _isCurrentPopupInWhitelist() {
    if (!_isPopupVisible) return false;
    final String popupUrlForCheck = _popupCurrentUrl ?? _popupUrl ?? '';
    return _matchesButtonWhitelist(popupUrlForCheck);
  }

  Widget _buildPopupWebView() {
    final bool popupInWhitelist = _isCurrentPopupInWhitelist();

    final bool showBackArrow = !popupInWhitelist && _popupCanGoBack;
    final bool showCloseButton = !popupInWhitelist && !_popupCanGoBack;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.96),
        child: Column(
          children: [
            if (!popupInWhitelist) ...[
              SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.black,
                  child: Row(
                    children: [
                      if (showBackArrow)
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: _handlePopupBackPressed,
                        )
                      else if (showCloseButton)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            _closePopupAndNotifyParent(reason: 'close_button');
                          },
                        ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
            ],
            Expanded(
              child: InAppWebView(
                windowId: _popupCreateAction?.windowId,
                initialUrlRequest:
                (_popupCreateAction?.windowId == null) && _popupUrl != null
                    ? URLRequest(url: WebUri(_popupUrl!))
                    : null,
                initialSettings: _popupWebViewSettings(),
                onWebViewCreated:
                    (InAppWebViewController popupController) async {
                  IdlePopupWebViewController = popupController;

                  print(
                    'WERLOG: popup created '
                        'windowId=${_popupCreateAction?.windowId} '
                        'initialUrl=${_popupUrl ?? _popupCreateAction?.request.url}',
                  );

                  final String popupInitUrl =
                      _popupUrl ??
                          _popupCreateAction?.request.url?.toString() ?? '';
                  if (popupInitUrl.isNotEmpty) {
                    final Uri? popupUri = Uri.tryParse(popupInitUrl);
                    if (popupUri != null && _isGoogleUrl(popupUri)) {
                      await _applyGoogleUserAgentForPopup();
                    }
                  }

                  popupController.addJavaScriptHandler(
                    handlerName: 'NcupLocalStorageSetItem',
                    callback: (List<dynamic> args) async {
                      try {
                        if (args.isEmpty) return null;
                        final dynamic raw = args.first;
                        if (raw is Map) {
                          final String key = raw['key']?.toString() ?? '';
                          final String value = raw['value']?.toString() ?? '';
                          if (key.isNotEmpty) {
                            final SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                            await prefs.setString(key, value);
                            IdleLoggerService().IdleLogInfo(
                                'NcupLocalStorageSetItem (popup): saved key="$key" len=${value.length}');
                          }
                        }
                      } catch (e, st) {
                        IdleLoggerService().IdleLogError(
                            'NcupLocalStorageSetItem popup handler error: $e\n$st');
                      }
                      return null;
                    },
                  );

                  popupController.addJavaScriptHandler(
                    handlerName: 'NcupCheckoutAction',
                    callback: (List<dynamic> args) async {
                      print('WERLOG: POPUP NcupCheckoutAction args=$args');
                      if (args.isNotEmpty) {
                        await _handleCheckoutAction(args.first);
                      }
                      return null;
                    },
                  );

                  popupController.addJavaScriptHandler(
                    handlerName: 'NcupPostMessage',
                    callback: (List<dynamic> args) async {
                      print('WERLOG: POPUP NcupPostMessage args=$args');
                      if (args.isNotEmpty) {
                        final dynamic first = args.first;
                        if (first is Map && first['data'] != null) {
                          await _handleCheckoutAction(first['data']);
                        } else {
                          await _handleCheckoutAction(first);
                        }
                      }
                      return null;
                    },
                  );

                  popupController.addJavaScriptHandler(
                    handlerName: 'NcupJSLogger',
                    callback: (List<dynamic> args) {
                      print('WERLOG: POPUP JS error payload: $args');
                      return null;
                    },
                  );
                },
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onLoadStart: (controller, uri) async {
                  print('WERLOG: popup onLoadStart url=$uri');
                  if (uri != null && !_isAboutBlankUri(uri)) {
                    if (_isGoogleUrl(uri)) {
                      await _applyGoogleUserAgentForPopup();
                    }

                    if (mounted) {
                      setState(() {
                        _popupCurrentUrl = uri.toString();
                        if (_backButtonHiddenAfterTap) {
                          _backButtonHiddenAfterTap = false;
                        }
                      });
                    }
                  }
                  _refreshPopupCanGoBack();
                },
                onLoadStop: (controller, uri) async {
                  print('WERLOG: popup onLoadStop url=$uri');
                  if (uri != null && !_isAboutBlankUri(uri)) {
                    if (mounted) {
                      setState(() {
                        _popupCurrentUrl = uri.toString();
                      });
                    }
                  }
                  if (!_isAboutBlankUri(uri)) {
                    _scheduleSafeInstall(controller, label: 'popup');
                  }
                  _refreshPopupCanGoBack();
                },
                onUpdateVisitedHistory: (controller, url, isReload) async {
                  if (url != null && !_isAboutBlankUri(url)) {
                    if (mounted) {
                      setState(() {
                        _popupCurrentUrl = url.toString();
                        if (_backButtonHiddenAfterTap) {
                          _backButtonHiddenAfterTap = false;
                        }
                      });
                    }
                  }
                  _refreshPopupCanGoBack();
                },
                onCreateWindow: _onPopupCreateWindowHandler,
                shouldOverrideUrlLoading: (
                    InAppWebViewController controller,
                    NavigationAction navigationAction,
                    ) async {
                  final Uri? uri = navigationAction.request.url;
                  if (uri == null) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  if (_isAboutBlankUri(uri)) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  if (_isGoogleUrl(uri)) {
                    await _applyGoogleUserAgentForPopup();
                    return NavigationActionPolicy.ALLOW;
                  }

                  final String scheme = uri.scheme.toLowerCase();

                  if (IdleIsBareEmail(uri)) {
                    final Uri mailto = IdleToMailto(uri);
                    await IdleOpenMailExternal(mailto);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (scheme == 'mailto') {
                    await IdleOpenMailExternal(uri);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (scheme == 'tel') {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (IdleIsBankScheme(uri) ||
                      ((scheme == 'http' || scheme == 'https') &&
                          IdleIsBankDomain(uri))) {
                    await IdleOpenBank(uri);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (scheme != 'http' && scheme != 'https') {
                    print(
                      'WERLOG: popup blocked non-http/https scheme=$scheme url=$uri',
                    );
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onCloseWindow: (controller) {
                  print('WERLOG: popup onCloseWindow');
                  _closePopup();
                },
                onLoadError: (controller, uri, code, message) async {
                  print(
                    'WERLOG: popup onLoadError url=$uri code=$code msg=$message',
                  );
                },
                onReceivedError: (controller, request, error) async {
                  print(
                    'WERLOG: popup onReceivedError '
                        'url=${request.url} '
                        'type=${error.type} '
                        'desc=${error.description}',
                  );
                },
                onReceivedHttpError:
                    (controller, request, errorResponse) async {
                  print(
                    'WERLOG: popup onReceivedHttpError '
                        'url=${request.url} '
                        'status=${errorResponse.statusCode} '
                        'reason=${errorResponse.reasonPhrase}',
                  );
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print(
                    'WERLOG: popup console: '
                        '${consoleMessage.messageLevel} ${consoleMessage.message}',
                  );
                },
                onDownloadStartRequest: (controller, req) async {
                  print(
                      'WERLOG: popup download for url=${req.url}, opening external');
                  await IdleOpenExternal(req.url);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    IdleBindNotificationTap();

    final Color bgColor =
    _safeAreaEnabled ? _safeAreaBackgroundColor : Colors.black;

    final Widget webView = Stack(
      children: <Widget>[
        if (IdleCoverVisible)
          const Center(child:LoungeOfIdlenessWaveLoader())
        else
          Container(
            color: bgColor,
            child: Stack(
              children: <Widget>[
                InAppWebView(
                  key: ValueKey<int>(IdleWebViewKeyCounter),
                  initialSettings: _mainWebViewSettings(),
                  initialUrlRequest: URLRequest(
                    url: WebUri(IdleHomeUrl),
                  ),
                  onWebViewCreated:
                      (InAppWebViewController controller) async {
                    IdleWebViewController = controller;
                    _currentUrl = IdleHomeUrl;

                    IdleBosunInstance ??= IdleBosunViewModel(
                      IdleDeviceProfileInstance: IdleDeviceProfileInstance,
                      IdleAnalyticsSpyInstance: IdleAnalyticsSpyInstance,
                    );

                    IdleCourier ??= IdleCourierService(
                      IdleBosun: IdleBosunInstance!,
                      IdleGetWebViewController: () => IdleWebViewController,
                    );

                    try {
                      final ua = await controller.evaluateJavascript(
                        source: "navigator.userAgent",
                      );
                      if (ua is String && ua.trim().isNotEmpty) {
                        _baseUserAgent = ua.trim();
                        _currentUserAgent = _baseUserAgent!;
                        IdleDeviceProfileInstance.IdleBaseUserAgent =
                            _baseUserAgent;
                        IdleLoggerService().IdleLogInfo(
                            'Initial WebView User-Agent: $_baseUserAgent');
                        print(
                            '[UA] INITIAL WEBVIEW USER AGENT: $_baseUserAgent');
                      }
                    } catch (e) {
                      IdleLoggerService().IdleLogWarn(
                          'Failed to read navigator.userAgent on create: $e');
                    }

                    await _applyNormalUserAgentIfNeeded();

                    controller.addJavaScriptHandler(
                      handlerName: 'NcupLocalStorageSetItem',
                      callback: (List<dynamic> args) async {
                        try {
                          if (args.isEmpty) return null;
                          final dynamic raw = args.first;
                          if (raw is Map) {
                            final String key = raw['key']?.toString() ?? '';
                            final String value =
                                raw['value']?.toString() ?? '';
                            if (key.isNotEmpty) {
                              final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                              await prefs.setString(key, value);
                              IdleLoggerService().IdleLogInfo(
                                  'NcupLocalStorageSetItem (main): saved key="$key" len=${value.length}');
                            }
                          }
                        } catch (e, st) {
                          IdleLoggerService().IdleLogError(
                              'NcupLocalStorageSetItem main handler error: $e\n$st');
                        }
                        return null;
                      },
                    );

                    controller.addJavaScriptHandler(
                      handlerName: 'onServerResponse',
                      callback: (List<dynamic> args) async {
                        if (args.isEmpty) return null;

                        print("Get Data server $args");

                        try {
                          dynamic first = args[0];

                          if (first is List && first.isNotEmpty) {
                            first = first.first;
                          }

                          final bool handled =
                          await _handleCheckoutAction(first);
                          if (handled) {}

                          if (first is Map) {
                            final Map<dynamic, dynamic> root = first;

                            if (root['savedata'] != null) {
                              IdleHandleServerSavedata(
                                  root['savedata'].toString());
                              await _handleCheckoutAction(root['savedata']);
                            }

                            _updateExtraDataFromServerPayload(root);
                            _updateSafeAreaFromServerPayload(root);
                            await _updateUserAgentFromServerPayload(root);

                            await _applyNormalUserAgentIfNeeded();

                            try {
                              if (!_loadedJsExecutedOnce) {
                                final dynamic adataRaw = root['adata'];
                                if (adataRaw is Map) {
                                  final Map adata = adataRaw;
                                  final dynamic loadedJsRaw =
                                  adata['loadedjs'];
                                  if (loadedJsRaw != null) {
                                    final String loadedJs =
                                    loadedJsRaw.toString().trim();
                                    if (loadedJs.isNotEmpty) {
                                      _pendingLoadedJs = loadedJs;
                                      IdleLoggerService().IdleLogInfo(
                                        'loadedjs received, will execute ONCE after 6 seconds',
                                      );

                                      Future<void>.delayed(
                                        const Duration(seconds: 6),
                                            () async {
                                          if (!mounted) return;
                                          if (_loadedJsExecutedOnce) {
                                            IdleLoggerService()
                                                .IdleLogInfo(
                                                'Skipping loadedjs: already executed once');
                                            return;
                                          }
                                          if (IdleWebViewController ==
                                              null) {
                                            IdleLoggerService()
                                                .IdleLogWarn(
                                                'Skipping loadedjs execution: controller is null');
                                            return;
                                          }
                                          final String? jsToRun =
                                              _pendingLoadedJs;
                                          if (jsToRun == null ||
                                              jsToRun.isEmpty) {
                                            return;
                                          }
                                          IdleLoggerService().IdleLogInfo(
                                              'Executing loadedjs from server payload (ONCE, delayed 6s)');
                                          try {
                                            await IdleWebViewController
                                                ?.evaluateJavascript(
                                              source: jsToRun,
                                            );
                                            _loadedJsExecutedOnce = true;
                                          } catch (e, st) {
                                            IdleLoggerService().IdleLogError(
                                                'Error executing delayed loadedjs: $e\n$st');
                                          }
                                        },
                                      );
                                    }
                                  }
                                }
                              } else {
                                IdleLoggerService().IdleLogInfo(
                                    'loadedjs ignored: already executed once earlier');
                              }
                            } catch (e, st) {
                              IdleLoggerService().IdleLogError(
                                  'Error scheduling loadedjs: $e\n$st');
                            }
                          }
                        } catch (e, st) {
                          print('onServerResponse error: $e\n$st');
                        }

                        return null;
                      },
                    );

                    controller.addJavaScriptHandler(
                      handlerName: 'NcupCheckoutAction',
                      callback: (List<dynamic> args) async {
                        try {
                          print('WERLOG: MAIN NcupCheckoutAction args=$args');
                          if (args.isNotEmpty) {
                            await _handleCheckoutAction(args.first);
                          }
                        } catch (e) {
                          print(
                              'WERLOG: MAIN NcupCheckoutAction error: $e');
                        }
                        return null;
                      },
                    );

                    controller.addJavaScriptHandler(
                      handlerName: 'NcupJSLogger',
                      callback: (List<dynamic> args) {
                        try {
                          final dynamic payload =
                          args.isNotEmpty ? args.first : null;
                          print('WERLOG: MAIN JS error payload: $payload');
                        } catch (e) {
                          print('WERLOG: NcupJSLogger handler error: $e');
                        }
                        return null;
                      },
                    );

                    controller.addJavaScriptHandler(
                      handlerName: 'NcupPostMessage',
                      callback: (List<dynamic> args) async {
                        try {
                          print('WERLOG: MAIN NcupPostMessage args=$args');
                          if (args.isNotEmpty) {
                            final dynamic first = args.first;
                            if (first is Map && first['data'] != null) {
                              await _handleCheckoutAction(first['data']);
                            } else {
                              await _handleCheckoutAction(first);
                            }
                          }
                        } catch (e) {
                          print(
                              'WERLOG: NcupPostMessage handler error: $e');
                        }
                        return null;
                      },
                    );
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onLoadStart:
                      (InAppWebViewController controller, Uri? uri) async {
                    setState(() {
                      IdleStartLoadTimestamp =
                          DateTime.now().millisecondsSinceEpoch;
                    });

                    final Uri? idleViewUri = uri;
                    if (idleViewUri != null) {
                      _currentUrl = idleViewUri.toString();

                      await _switchUserAgentForUrl(idleViewUri);

                      await _updateBackButtonVisibility();

                      if (IdleIsBareEmail(idleViewUri)) {
                        try {
                          await controller.stopLoading();
                        } catch (_) {}
                        final Uri idleMailto = IdleToMailto(idleViewUri);
                        await IdleOpenMailExternal(idleMailto);
                        return;
                      }

                      final String idleScheme =
                      idleViewUri.scheme.toLowerCase();

                      if (idleScheme == 'mailto') {
                        try {
                          await controller.stopLoading();
                        } catch (_) {}
                        await IdleOpenMailExternal(idleViewUri);
                        return;
                      }

                      if (IdleIsBankScheme(idleViewUri)) {
                        try {
                          await controller.stopLoading();
                        } catch (_) {}
                        await IdleOpenBank(idleViewUri);
                        return;
                      }

                      if (idleScheme != 'http' && idleScheme != 'https') {
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
                    final int idleNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String idleEvent =
                        'InAppWebViewError(code=$code, message=$message)';

                    await IdlePostStat(
                      event: idleEvent,
                      timeStart: idleNow,
                      timeFinish: idleNow,
                      url: uri?.toString() ?? '',
                      appSid: IdleAnalyticsSpyInstance.IdleAppsFlyerUid,
                      firstPageLoadTs: IdleFirstPageTimestamp,
                    );
                  },
                  onReceivedError: (
                      InAppWebViewController controller,
                      WebResourceRequest request,
                      WebResourceError error,
                      ) async {
                    final int idleNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String idleDescription =
                    (error.description ?? '').toString();
                    final String idleEvent =
                        'WebResourceError(code=$error, message=$idleDescription)';

                    await IdlePostStat(
                      event: idleEvent,
                      timeStart: idleNow,
                      timeFinish: idleNow,
                      url: request.url?.toString() ?? '',
                      appSid: IdleAnalyticsSpyInstance.IdleAppsFlyerUid,
                      firstPageLoadTs: IdleFirstPageTimestamp,
                    );
                  },
                  onLoadStop:
                      (InAppWebViewController controller, Uri? uri) async {
                    setState(() {
                      IdleCurrentUrl = uri.toString();
                      _currentUrl = IdleCurrentUrl;
                    });

                    if (uri != null) {
                      await _switchUserAgentForUrl(uri);
                    }

                    if (!_isAboutBlankUri(uri)) {
                      _scheduleSafeInstall(controller, label: 'parent');
                    }

                    await debugPrintCurrentUserAgent();

                    await _sendAllDataToPageTwice();
                    await _updateBackButtonVisibility();

                    Future<void>.delayed(
                      const Duration(seconds: 20),
                          () {
                        IdleSendLoadedOnce(
                          url: IdleCurrentUrl.toString(),
                          timestart: IdleStartLoadTimestamp,
                        );
                      },
                    );
                  },
                  onUpdateVisitedHistory:
                      (controller, url, isReload) async {
                    if (url != null && !_isAboutBlankUri(url)) {
                      _currentUrl = url.toString();
                      await _updateBackButtonVisibility();
                      await _switchUserAgentForUrl(url);
                    }
                  },
                  shouldOverrideUrlLoading: (InAppWebViewController controller,
                      NavigationAction action) async {
                    final Uri? idleUri = action.request.url;
                    if (idleUri == null) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    _currentUrl = idleUri.toString();
                    await _updateBackButtonVisibility();

                    if (_isAboutBlankUri(idleUri)) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    if (_isGoogleUrl(idleUri)) {
                      _isCurrentlyOnGoogle = true;
                      await _applyGoogleUserAgent();
                      return NavigationActionPolicy.ALLOW;
                    } else {
                      if (_isCurrentlyOnGoogle) {
                        _isCurrentlyOnGoogle = false;
                      }
                      await _applyNormalUserAgentIfNeeded();
                    }

                    if (IdleIsBareEmail(idleUri)) {
                      final Uri idleMailto = IdleToMailto(idleUri);
                      await IdleOpenMailExternal(idleMailto);
                      return NavigationActionPolicy.CANCEL;
                    }

                    final String idleScheme = idleUri.scheme.toLowerCase();

                    if (idleScheme == 'mailto') {
                      await IdleOpenMailExternal(idleUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (IdleIsBankScheme(idleUri)) {
                      await IdleOpenBank(idleUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if ((idleScheme == 'http' || idleScheme == 'https') &&
                        IdleIsBankDomain(idleUri)) {
                      await IdleOpenBank(idleUri);

                      if (_isAdobeRedirect(idleUri)) {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  IdleAdobeRedirectScreen(uri: idleUri),
                            ),
                          );
                        }
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (idleScheme == 'tel') {
                      await launchUrl(
                        idleUri,
                        mode: LaunchMode.externalApplication,
                      );
                      return NavigationActionPolicy.CANCEL;
                    }

                    final String host = idleUri.host.toLowerCase();
                    final bool idleIsSocial =
                        host.endsWith('facebook.com') ||
                            host.endsWith('instagram.com') ||
                            host.endsWith('twitter.com') ||
                            host.endsWith('x.com');

                    if (idleIsSocial) {
                      await IdleOpenExternal(idleUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (IdleIsPlatformLink(idleUri)) {
                      final Uri idleWebUri =
                      IdleHttpizePlatformUri(idleUri);
                      await IdleOpenExternal(idleWebUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (idleScheme != 'http' && idleScheme != 'https') {
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onCreateWindow: _onCreateWindowHandler,
                  onCloseWindow: (controller) {
                    print('WERLOG: MAIN onCloseWindow');
                  },
                  onDownloadStartRequest: (
                      InAppWebViewController controller,
                      DownloadStartRequest req,
                      ) async {
                    await IdleOpenExternal(req.url);
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    print(
                      'WERLOG: MAIN console: '
                          '${consoleMessage.messageLevel} ${consoleMessage.message}',
                    );
                  },
                ),
                Visibility(
                  visible: !IdleVeilVisible,
                  child: const Center(child: LoungeOfIdlenessWaveLoader()),
                ),

                if (_isPopupVisible &&
                    (_popupUrl != null || _popupCreateAction != null))
                  _buildPopupWebView(),
              ],
            ),
          ),
      ],
    );

    final bool popupInWhitelist = _isCurrentPopupInWhitelist();

    final bool whitelistMatch =
        (!_isPopupVisible && _showBackButton) || popupInWhitelist;

    final bool shouldShowTopBackBar =
        whitelistMatch && !_backButtonHiddenAfterTap;

    final Color topBarColor =
    _safeAreaEnabled ? _safeAreaBackgroundColor : Colors.black;

    final Widget topBackBar = shouldShowTopBackBar
        ? Container(
      color: topBarColor,
      padding: const EdgeInsets.only(left: 4, right: 4),
      height: 48,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBackButtonPressed,
          ),
        ],
      ),
    )
        : const SizedBox.shrink();

    final Widget fullScreen = Column(
      children: [
        topBackBar,
        Expanded(child: webView),
      ],
    );

    final Widget body = _safeAreaEnabled
        ? SafeArea(
      child: fullScreen,
    )
        : fullScreen;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SizedBox.expand(
          child: ColoredBox(
            color: bgColor,
            child: body,
          ),
        ),
      ),
    );
  }

  bool _isAdobeRedirect(Uri uri) {
    final String host = uri.host.toLowerCase();
    return host == 'c00.adobe.com';
  }
}

// ---------------------- Экран для c00.adobe.com ----------------------

class IdleAdobeRedirectScreen extends StatelessWidget {
  final Uri uri;

  const IdleAdobeRedirectScreen({super.key, required this.uri});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF111111),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Go to the App Store and download the app.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(height: 40),
            ],
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
  FirebaseMessaging.onBackgroundMessage(IdleFcmBackgroundHandler);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  tz_data.initializeTimeZones();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IdleHall(),
    ),
  );
}