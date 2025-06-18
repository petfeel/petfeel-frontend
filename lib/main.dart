import 'package:flutter/material.dart';
import 'package:test123/screen/login_page.dart';
import 'package:test123/screen/profile_liston_page.dart';
// import 'package:test123/screen/alarm_setting_page.dart';
// import 'package:test123/screen/login_page.dart';
// import 'package:test123/screen/profile_liston_page.dart';
import 'package:test123/screen/start_page.dart';
import 'package:test123/screen/video_list_page.dart';
import 'package:test123/screen/voice_list_page.dart';
// import 'package:test123/screen/thinq_page.dart';
import 'utils/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:convert';
import 'package:test123/screen/alarm_detail_page.dart';

// 백그라운드에서 알림 처리를 위한 글로벌 변수
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final NotificationService notificationService = NotificationService();

// 백그라운드 알림 처리 함수
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // 백그라운드에서 알림 탭 처리
  // 실제 처리는 앱이 실행될 때 할 것임
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 알림 초기화
  await initializeNotifications();
  
  runApp(const MyApp());
}

// 알림 초기화 함수
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
      // 알림 탭 시 처리
      if (notificationResponse.payload != null) {
        debugPrint('알림 페이로드: ${notificationResponse.payload}');
        // 여기서는 아무것도 하지 않고, 앱이 시작될 때 처리함
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  
  // iOS 관련 코드 주석 처리 (에러 방지)
  // await flutterLocalNotificationsPlugin
  //     .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
  //     ?.requestPermissions(
  //       alert: true,
  //       badge: true,
  //       sound: true,
  //     );
      
  // 알림 채널 생성 (Android)
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'high_importance_channel',
        '높은 심각도 알림',
        description: '심각한 이상행동 감지 시 알림',
        importance: Importance.high,
      ),
    );
    
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'medium_importance_channel',
        '중간 심각도 알림',
        description: '주의가 필요한 이상행동 감지 시 알림',
        importance: Importance.high,
      ),
    );
    
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'low_importance_channel',
        '낮은 심각도 알림',
        description: '경미한 이상행동 감지 시 알림',
        importance: Importance.defaultImportance,
      ),
    );
    
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'normal_channel',
        '일반 알림',
        description: '일반 상태 알림',
        importance: Importance.low,
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // 앱 시작 시 알림 서비스 시작
    notificationService.startListening();
    
    // 알림 탭 처리 확인
    _checkNotificationOpenedApp();
  }
  
  // 알림으로 앱이 시작되었는지 확인
  Future<void> _checkNotificationOpenedApp() async {
    final details = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp && details.notificationResponse?.payload != null) {
      debugPrint('🚀 알림에 의해 앱이 시작됨: ${details.notificationResponse?.payload}');
      // 여기서 알림 처리 로직을 구현하거나, 나중에 앱 내에서 처리
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Monitoring App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'LGSmartUI',
      ),
      home: const StartPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
