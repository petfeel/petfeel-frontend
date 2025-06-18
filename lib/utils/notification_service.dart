import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'api_endpoints.dart';

class NotificationService {
  // 싱글톤 패턴 구현
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _initNotifications();
    setupService();
  }

  // 알림 스트림 컨트롤러
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // WebSocket 연결
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;
  int _clientId = DateTime.now().millisecondsSinceEpoch % 10000; // 임의의 클라이언트 ID

  // 로컬 알림을 위한 플러그인
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // 최신 알림 ID
  int _lastEventId = 0;
  bool _isConnected = false;
  
  // HTTP 폴링 관련
  DateTime? _lastPollingTime;
  Timer? _pollingTimer;
  bool _isCheckingEvents = false; // HTTP 폴링 중복 실행 방지 플래그
  
  // 연결 상태 관리
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  Timer? _pingTimer;
  DateTime? _lastPongTime;
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _pongTimeout = Duration(seconds: 10);
  
  // 읽지 않은 알림 개수 관리
  int _unreadCount = 0;
  final _notificationsKey = 'saved_notifications';
  final _unreadCountKey = 'unread_notifications_count';
  
  // 읽지 않은 알림 개수 스트림
  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  
  // 읽지 않은 알림 개수 getter
  Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    await setUnreadFromServer(prefs.getInt(_unreadCountKey) ?? 0);
    return _unreadCount;
  }
  
  // 로컬 알림 초기화
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS = 
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    // 마지막으로 받은 이벤트 ID 로드
    final prefs = await SharedPreferences.getInstance();
    _lastEventId = prefs.getInt('lastEventId') ?? 0;
    
    // 읽지 않은 알림 개수 로드
    await _loadUnreadCount();
    
    // 저장된 알림 로드
    await loadSavedNotifications();
  }
  
  // 읽지 않은 알림 개수 로드
  Future<void> _loadUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    await setUnreadFromServer(prefs.getInt(_unreadCountKey) ?? 0);
  }

  Future<void> incrementUnread() async {
    _unreadCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, _unreadCount);
    _unreadCountController.add(_unreadCount);
  }

  Future<void> setUnreadFromServer(int value) async {
    _unreadCount = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, value);
    _unreadCountController.add(value);
  }
  
  // 저장된 알림 로드 (public 메서드로 변경)
  Future<List<Map<String, dynamic>>> loadSavedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString(_notificationsKey);
    
    if (notificationsJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = json.decode(notificationsJson);
      debugPrint('🔄 저장된 알림 로드: ${decoded.length}개');

      await setUnreadFromServer(
          decoded.where((n) => !(n['read'] ?? false)).length);

      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('저장된 알림 로드 중 오류: $e');
      return [];
    }
  }
  
  // 알림 저장
  Future<void> saveNotification(Map<String, dynamic> notification) async {
    try {
      // ID가 32비트 정수 범위를 벗어나는 경우 안전한 ID로 변경
      if (notification.containsKey('id')) {
        final dynamic id = notification['id'];
        if (id is int && id > 2147483647) {
          notification['id'] = _generateNotificationId();
        }
      } else {
        notification['id'] = _generateNotificationId();
      }
      
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> notifications = await loadSavedNotifications();
      
      // 중복 방지
      final existingIndex = notifications.indexWhere((n) => 
        n['id'] == notification['id'] || 
        n['event_id'] == notification['event_id']);
      
      debugPrint('💾 알림 저장: ID=${notification['id']}, existingIndex=$existingIndex');
      
      if (existingIndex >= 0) {
        notifications[existingIndex] = notification;

        await setUnreadFromServer(
            notifications.where((n) => !(n['read'] ?? false)).length);
      } else {
        // 새 알림은 앞에 추가
        notifications.insert(0, notification);
        await incrementUnread();
      }
      
      // 알림 저장
      final jsonString = json.encode(notifications);
      await prefs.setString(_notificationsKey, jsonString);
      debugPrint('✅ 알림 저장 완료 (총 ${notifications.length}개)');
    } catch (e) {
      debugPrint('알림 저장 중 오류: $e');
    }
  }
  
  // 내부용 메서드 (이전 버전과의 호환성 유지)
  Future<void> _saveNotification(Map<String, dynamic> notification) => saveNotification(notification);
  
  // 알림 읽음 표시
  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await setUnreadFromServer(0);
      
      // 알림 목록에도 읽음 상태 업데이트
      final List<Map<String, dynamic>> notifications = await loadSavedNotifications();
      for (var notification in notifications) {
        notification['read'] = true;
      }
      await prefs.setString(_notificationsKey, json.encode(notifications));
    } catch (e) {
      debugPrint('알림 읽음 표시 중 오류: $e');
    }
  }

  // 알림 설정 상태 가져오기
  Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'main': prefs.getBool('toggleMain') ?? true,
      'stage0': prefs.getBool('toggle0') ?? true,
      'stage1': prefs.getBool('toggle1') ?? true,
      'stage2': prefs.getBool('toggle2') ?? true,
      'stage3': prefs.getBool('toggle3') ?? true,
    };
  }

  // 알림 수신 시작 - WebSocket 연결 및 기존 알림 로드
  void startListening() {
    // 기존 알림 로드
    loadInitialNotifications();
    
    // WebSocket 연결
    _connectWebSocket();
    
    // HTTP 폴백 - 주기적으로 새 알림 확인
    _startPollingFallback();
    
    debugPrint('🔔 알림 수신 준비 완료');
  }
  
  // UTF-8 인코딩 오류 수정 함수 (한글 처리)
  String _fixUtf8Encoding(String text) {
    try {
      if (text.isEmpty) return '';
      
      // 이미 정상적인 문자열이면 그대로 반환
      if (_isValidUtf8String(text)) {
        // 잔여 텍스트 제거 (특수 문자 및 이상한 문자열 패턴)
        text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
        
        // 중복된 공백 제거
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        return text;
      }
      
      // UTF-8 바이트로 변환 후 다시 디코딩
      List<int> bytes = utf8.encode(text);
      String decoded = utf8.decode(bytes, allowMalformed: true);
      
      // 잔여 텍스트 제거 (특수 문자 및 이상한 문자열 패턴)
      decoded = decoded.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
      
      // 중복된 공백 제거
      decoded = decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      return decoded;
    } catch (e) {
      debugPrint('UTF-8 인코딩 수정 중 오류: $e');
      
      // 실패 시 원본에서 잔여 텍스트 제거 시도
      try {
        // 특수 문자 제거
        String cleaned = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
        // 중복된 공백 제거
        cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
        return cleaned;
      } catch (_) {
        return text; // 모든 시도 실패 시 원본 반환
      }
    }
  }
  
  // 유효한 UTF-8 문자열인지 확인
  bool _isValidUtf8String(String text) {
    try {
      // 이 과정에서 오류가 발생하지 않으면 유효한 UTF-8
      final decoded = utf8.decode(utf8.encode(text));
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // 주기적인 HTTP 폴링 (주요 메커니즘)
  void _startPollingFallback() {
    _pollingTimer?.cancel();
    
    // 첫 번째 폴링은 즉시 실행
    _checkNewEventsViaHttp();
    
    // 2초마다 서버에서 새 알림 확인 (더 짧은 간격으로 설정)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isConnected) { // WebSocket이 연결되지 않은 경우에만 폴링 강화
        _checkNewEventsViaHttp();
      } else {
        // WebSocket이 연결된 경우 10초마다 폴링
        if (DateTime.now().second % 10 == 0) {
          _checkNewEventsViaHttp();
        }
      }
    });
  }
  
  // HTTP를 통해 새 이벤트 확인
  Future<void> _checkNewEventsViaHttp() async {
    try {
      if (_isCheckingEvents) return; // 이미 확인 중이면 중복 요청 방지
      _isCheckingEvents = true;
      
      // 마지막으로 확인한 이벤트 ID 가져오기
      final prefs = await SharedPreferences.getInstance();
      final lastEventId = prefs.getInt('last_event_id') ?? 0;
      
      // 새 이벤트 확인 URL - DB 테이블 재생성 후에는 since_id 파라미터 없이 모든 이벤트 가져오기
      // final url = '${ApiEndpoints.getEvents}?since_id=$lastEventId';
      final url = ApiEndpoints.getEvents; // 모든 이벤트 가져오기
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ HTTP 폴링 타임아웃');
          return http.Response('{"error": "timeout"}', 408);
        },
      );
      
      if (response.statusCode == 200) {
        // UTF-8로 디코딩하여 인코딩 문제 해결
        final List<dynamic> events = json.decode(utf8.decode(response.bodyBytes));
        
        if (events.isNotEmpty) {
          debugPrint('📬 HTTP 폴링으로 ${events.length}개의 이벤트 발견');
          
          // 이벤트를 알림으로 변환하여 처리
          for (final event in events) {
            try {
              final Map<String, dynamic> stringKeyedEvent = 
                  _convertToStringKeyMap(event);
              
              // 이벤트 ID 업데이트
              final int eventId = stringKeyedEvent['id'] ?? 0;
              if (eventId > lastEventId) {
                await prefs.setInt('last_event_id', eventId);
              }
              
              // 알림 처리
              final notification = await _processEventToNotification(stringKeyedEvent);
              if (notification != null) {
                // 이미 저장된 알림인지 확인
                final savedNotifications = await loadSavedNotifications();
                final bool isDuplicate = savedNotifications.any((n) => 
                    n['id'] == notification['id'] || 
                    n['event_id'] == notification['event_id']);
                
                if (!isDuplicate) {
                  // 스트림에 즉시 전달
                  _notificationController.add(notification);
                  
                  // 알림 저장 및 로컬 알림 표시
                  await saveNotification(notification);
                  await _showLocalNotification(notification);
                  
                  // 읽지 않은 알림 개수 업데이트
                }
              }
            } catch (e) {
              debugPrint('⚠️ HTTP 이벤트 처리 중 오류: $e');
            }
          }
        }
      } else {
        debugPrint('⚠️ HTTP 폴링 응답 오류: ${response.statusCode}');
      }
      
      _isCheckingEvents = false;
      _lastPollingTime = DateTime.now();
    } catch (e) {
      debugPrint('⚠️ HTTP 폴링 중 오류: $e');
      _isCheckingEvents = false;
    }
  }
  
  // 이벤트를 알림으로 처리
  Future<Map<String, dynamic>?> _processEventToNotification(Map<String, dynamic> event) async {
    try {
      // 이벤트 ID 확인
      final int eventId = event['event_id'] ?? event['id'] ?? 0;
      if (eventId <= 0) {
        debugPrint('⚠️ 유효하지 않은 이벤트 ID: $eventId');
        return null;
      }
      // ② 이미 저장된 알림이 있으면 read 상태 가져오기
      bool wasRead = false;
      try {
        final saved = await loadSavedNotifications();
        final existing = saved.firstWhere(
              (n) => (n['event_id'] ?? n['id'] ?? 0) == eventId,
          orElse: () => {},
        );
        if (existing.isNotEmpty) {
          wasRead = existing['read'] ?? false;
        }
      } catch (_) {
        // 무시하고 기본값 false 사용
      }
      // 기본 알림 데이터 구성
      final Map<String, dynamic> notification = {
        'id': event['id'] ?? 0,
        'event_id': eventId,
        'pet_id': event['pet_id'] ?? 0,
        'stage': event['stage']?.toString() ?? '0',
        'time': event['time'] ?? event['created_at'] ?? DateTime.now().toIso8601String(),
        'read': wasRead,
      };
      
      // 메시지 처리 - 1. 이후부터 2. 이전까지 추출 (behavior_report에서)
      String behaviorReport = event['behavior_report'] ?? '';
      String message = event['message'] ?? '';
      String behaviorDescription = event['behavior_description'] ?? '';
      String actionPlan = event['action_plan'] ?? '';
      String videoName = event['video_name'] ?? '';
      
      // 텍스트 인코딩 문제 해결
      behaviorReport = _fixUtf8Encoding(behaviorReport);
      message = _fixUtf8Encoding(message);
      behaviorDescription = _fixUtf8Encoding(behaviorDescription);
      actionPlan = _fixUtf8Encoding(actionPlan);
      
      // 요약 메시지 추출
      if (behaviorReport.contains("1. ") && behaviorReport.contains("2. ")) {
        int start = behaviorReport.indexOf("1. ") + 3;
        int end = behaviorReport.indexOf("2. ");
        if (start < end) {
          message = behaviorReport.substring(start, end).trim();
        }
      } else if (behaviorDescription.isNotEmpty) {
        message = behaviorDescription;
      } else if (message.isEmpty) {
        message = '반려동물의 행동이 감지되었습니다.';
      }
      
      // 알림 데이터 완성
      notification['message'] = message;
      notification['behavior_report'] = behaviorReport;
      notification['behavior_description'] = behaviorDescription;
      notification['action_plan'] = actionPlan;
      notification['video_name'] = videoName;
      
      return notification;
    } catch (e) {
      debugPrint('⚠️ 알림 처리 중 오류: $e');
      return null;
    }
  }
  
  // 32비트 정수 범위 내의 알림 ID 생성
  int _generateNotificationId() {
    // 현재 타임스탬프에서 마지막 9자리만 사용하여 정수 범위 내에 유지
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return timestamp % 2000000000; // 안전하게 2 billion 이내로 제한
  }
  
  // WebSocket 연결
  Future<void> _connectWebSocket() async {
    if (_isConnecting || _isConnected) return;

    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getInt('client_id') ?? 
          DateTime.now().millisecondsSinceEpoch % 10000;
      
      debugPrint('📡 WebSocket 연결 시도: client_id=$clientId');
      
      // WebSocket 주소 설정
      String wsUrl = '${ApiEndpoints.webSocketBase}/notifications/ws/$clientId';
      
      debugPrint('🔌 WebSocket URL: $wsUrl');
      
      // 연결 시도 (타임아웃 증가)
      _webSocketChannel = await IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        pingInterval: _pingInterval,
        connectTimeout: const Duration(seconds: 30), // 타임아웃 더 증가
        headers: {
          'Connection': 'Upgrade',
          'Upgrade': 'websocket',
          'Cache-Control': 'no-cache',
        },
      );
      
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      debugPrint('✅ WebSocket 연결 성공');
      
      // 메시지 수신 처리
      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (data) async {
          try {
            debugPrint('📩 WebSocket 메시지 수신: $data');
            
            // 문자열인 경우만 처리 (안전성)
            if (data is String) {
              // UTF-8 인코딩 문제 수정
              String fixedMessage = _fixUtf8Encoding(data);
              
              // 수정된 메시지로 JSON 파싱
              final Map<dynamic, dynamic> message = json.decode(fixedMessage);
              
              // 핑 메시지 처리
              if (message is Map && message['type'] == 'ping') {
                _handlePing(message);
                return;
              }
              
              // 알림 메시지 처리
              if (message is Map && message['type'] == 'notification') {
                // dynamic Map을 String Map으로 변환
                final Map<String, dynamic> stringKeyedMap = 
                    _convertToStringKeyMap(message);
                    
                // 알림 처리
                final notification = await _processEventToNotification(stringKeyedMap);
                if (notification != null) {
                  // 이미 저장된 알림인지 확인
                  final savedNotifications = await loadSavedNotifications();
                  final int eventId = notification['event_id'] ?? notification['id'] ?? 0;
                  
                  final bool isDuplicate = savedNotifications.any((n) => 
                      (n['id'] == notification['id'] && notification['id'] != null) || 
                      (n['event_id'] == eventId && eventId > 0));
                  
                  if (!isDuplicate) {
                    debugPrint('📢 새 알림 처리: $notification');
                    
                    // 스트림에 즉시 전달
                    _notificationController.add(notification);
                    
                    // 알림 저장 및 로컬 알림 표시는 약간의 지연 후 실행
                    await Future.delayed(const Duration(milliseconds: 100));
                    await saveNotification(notification);
                    await _showLocalNotification(notification);

                    // 서버에서 최신 데이터 가져오기 (추가 업데이트를 위해)
                    Future.delayed(const Duration(seconds: 1), () {
                      refreshNotifications();
                    });
                  } else {
                    debugPrint('🔄 중복 알림 무시: event_id=$eventId');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ WebSocket 메시지 처리 중 오류: $e');
          }
        },
        onDone: () {
          debugPrint('🔌 WebSocket 연결 종료됨');
          _isConnected = false;
          _isConnecting = false;
          _cleanupWebSocketResources();
          
          // 재연결 시도 (더 짧은 간격으로)
          if (_reconnectAttempts < _maxReconnectAttempts) {
            Future.delayed(const Duration(seconds: 2), () {
              if (!_isConnected && !_isConnecting) {
                debugPrint('🔄 WebSocket 재연결 시도...');
                _connectWebSocket();
              }
            });
          }
        },
        onError: (error) {
          debugPrint('⚠️ WebSocket 오류: $error');
          _isConnected = false;
          _isConnecting = false;
          _cleanupWebSocketResources();
          _reconnectAttempts++;
          
          // 오류 발생 시 HTTP 폴링 강화
          _startPollingFallback();
          
          // 즉시 재연결 시도
          Future.delayed(const Duration(seconds: 2), () {
            if (!_isConnected && !_isConnecting && _reconnectAttempts < _maxReconnectAttempts) {
              _connectWebSocket();
            }
          });
        },
        cancelOnError: false,
      );
      
      // 핑/퐁 설정
      _setupPongTimer();
      
      // 연결 성공 시 핑 메시지 즉시 전송
      _sendPingMessage();
    } catch (e) {
      debugPrint('⚠️ WebSocket 연결 실패: $e');
      _isConnected = false;
      _isConnecting = false;
      _reconnectAttempts++;
      
      // 연결 실패 시 HTTP 폴링 강화
      _startPollingFallback();
      
      // 일정 시간 후 재시도
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isConnected && !_isConnecting && _reconnectAttempts < _maxReconnectAttempts) {
          _connectWebSocket();
        }
      });
    }
  }
  
  // 핑 메시지 전송
  void _sendPingMessage() {
    try {
      if (_webSocketChannel == null || !_isConnected) return;
      
      final pingData = {
        'type': 'ping',
        'time': DateTime.now().millisecondsSinceEpoch,
        'client_id': _clientId,
      };
      _webSocketChannel?.sink.add(json.encode(pingData));
      debugPrint('📤 Ping 메시지 전송');
    } catch (e) {
      debugPrint('⚠️ Ping 전송 실패: $e');
    }
  }
  
  // 핑 메시지 처리 (서버로부터 핑 수신 시)
  void _handlePing(Map<dynamic, dynamic> pingData) {
    try {
      // Map<dynamic, dynamic>을 Map<String, dynamic>으로 변환
      final Map<String, dynamic> stringKeyedPing = _convertToStringKeyMap(pingData);
      
      // 핑에 대한 퐁 응답
      final pongData = {
        'type': 'pong',
        'time': DateTime.now().millisecondsSinceEpoch,
        'client_id': _clientId,
      };
      _webSocketChannel?.sink.add(json.encode(pongData));
      debugPrint('📤 Pong 메시지 전송');
      
      // 마지막 Pong 시간 업데이트
      _lastPongTime = DateTime.now();
    } catch (e) {
      debugPrint('⚠️ Ping 응답 실패: $e');
    }
  }
  
  // 주기적으로 Ping 메시지 전송
  void _setupPongTimer() {
    _pingTimer?.cancel();
    _lastPongTime = DateTime.now();
    
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      try {
        if (_webSocketChannel == null || !_isConnected) {
          _pingTimer?.cancel();
          return;
        }
        
        // 마지막 Pong 시간 확인 (Pong 타임아웃 감지)
        if (_lastPongTime != null) {
          final now = DateTime.now();
          final elapsed = now.difference(_lastPongTime!);
          
          // Pong 타임아웃 - 서버가 응답하지 않음
          if (elapsed > _pongTimeout) {
            debugPrint('⚠️ Pong 타임아웃: ${elapsed.inSeconds}초. 연결 재설정');
            _pingTimer?.cancel();
            _cleanupWebSocketResources();
            _isConnected = false;
            _isConnecting = false;
            
            // 재연결 시도
            Future.delayed(const Duration(milliseconds: 500), _connectWebSocket);
            return;
          }
        }
        
        // Ping 메시지 전송
        _sendPingMessage();
      } catch (e) {
        debugPrint('⚠️ Ping 전송 실패: $e');
        _pingTimer?.cancel();
        
        // 연결 끊김 감지 시 재연결
        if (_isConnected) {
          _isConnected = false;
          _isConnecting = false;
          _cleanupWebSocketResources();
          Future.delayed(const Duration(seconds: 1), _connectWebSocket);
        }
      }
    });
  }
  
  // WebSocket 리소스 정리
  void _cleanupWebSocketResources() {
    _pingTimer?.cancel();
    _pingTimer = null;
    
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    
    try {
      _webSocketChannel?.sink.close();
    } catch (e) {
      // 무시
    }
    _webSocketChannel = null;
  }
  
  // 알림 수신 중지
  void stopListening() {
    // WebSocket 연결 해제
    _cleanupWebSocketResources();
    _isConnected = false;
    _isConnecting = false;
    
    // HTTP 폴링 중지
    _pollingTimer?.cancel();
    _pollingTimer = null;
    
    debugPrint('🔕 알림 수신 중지됨');
  }

  // 앱 시작 시 최초 알림 로드
  Future<void> loadInitialNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.getEvents}?since_id=$_lastEventId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> eventsData = json.decode(response.body);
        
        if (eventsData.isNotEmpty) {
          // 설정 확인
          final settings = await getNotificationSettings();
          
          for (final dynamic eventData in eventsData) {
            // Map<dynamic, dynamic>을 Map<String, dynamic>으로 변환
            final Map<String, dynamic> event = _convertToStringKeyMap(eventData);
            
            // ID 업데이트
            final eventId = event['id'] ?? 0;
            if (eventId > _lastEventId) {
              _lastEventId = eventId;
              // 마지막 이벤트 ID 저장
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('lastEventId', _lastEventId);
            }
            
            // 알림 스트림에 추가 (시간 정보 추가)
            final notification = {
              ...event,
              'time': event['created_at'] ?? DateTime.now().toString(),
              'read' : (await loadSavedNotifications())
                .firstWhere(
                  (n) => (n['event_id'] ?? n['id']) == (event['id'] ?? 0),
                  orElse: () => {})['read'] ?? false,
            };
            
            // 알림을 로컬에 저장하고 스트림에 전달
            await _saveNotification(notification);
            _notificationController.add(notification);
          }
        }
      }
    } catch (e) {
      debugPrint('🔔 초기 알림 로드 중 오류: $e');
    }
  }

  // 백엔드에서 직접 수신한 알림 처리 (서버에서 POST 호출로 직접 수신)
  Future<bool> handleDirectNotification(Map<String, dynamic> data) async {
    try {
      debugPrint('🔔 직접 알림 데이터 수신: ${data['message'] ?? "메시지 없음"}');
      
      // 설정 확인
      final settings = await getNotificationSettings();
      
      // 스테이지 확인 및 알림 필터링
      final int stage = int.tryParse(data['stage']?.toString() ?? '0') ?? 0;
      
      // 메인 알림 설정이 꺼져 있으면 무시
      if (!settings['main']!) return false;
      
      // 해당 단계 알림 설정이 꺼져 있으면 무시
      if (!settings['stage$stage']!) return false;
      
      // 이미 저장된 알림인지 확인 (중복 방지)
      final notifications = await loadSavedNotifications();
      final int eventId = data['event_id'] ?? data['id'] ?? 0;
      
      // 중복 여부 확인
      final bool isDuplicate = notifications.any((n) => 
          n['id'] == eventId || n['event_id'] == eventId);
      
      if (isDuplicate) {
        debugPrint('🔄 직접 알림 중복 감지 - 무시됨');
        return false;
      }
      
      // 알림 처리
      final notification = await _processEventToNotification(data);
      if (notification != null) {
        // 스트림에 전달
        _notificationController.add(notification);
        
        // 알림 저장
        await saveNotification(notification);
        
        // 로컬 알림 표시
        await _showLocalNotification(notification);
        
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ 직접 알림 처리 중 오류: $e');
    }
    
    return false;
  }
  
  // Gemini 응답 파싱 함수
  Map<String, String> parseGeminiResponse(String response) {
    try {
      // 결과 맵 초기화
      final result = {
        'behavior_description': '',
        'action_plan': '',
      };
      
      // 디버깅
      debugPrint('🔍 Gemini 응답 파싱 시작:');
      
      // 빈 응답이면 기본값 반환
      if (response.isEmpty) {
        return result;
      }
      
      // 인코딩 문제 수정 (한글 깨짐 방지)
      String fixedResponse = _fixUtf8Encoding(response);
      
      // 불필요한 문자 제거
      fixedResponse = fixedResponse.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
      
      // 1. 행동 설명 부분 추출 (1. 다음부터 2. 또는 다음 숫자까지)
      final behaviorMatch = RegExp(r'1\.\s*(.*?)(?=\s*\d+\.|\s*$)', dotAll: true).firstMatch(fixedResponse);
      if (behaviorMatch != null && behaviorMatch.group(1) != null) {
        result['behavior_description'] = behaviorMatch.group(1)!.trim();
        debugPrint('✅ 이상행동 리포트 추출: ${result['behavior_description']}');
      }
      
      // 3. 대처 방법 추출 (3. 다음부터 4. 또는 끝까지)
      final actionMatch = RegExp(r'3\.\s*(.*?)(?=\s*\d+\.|\s*$)', dotAll: true).firstMatch(fixedResponse);
      if (actionMatch != null && actionMatch.group(1) != null) {
        result['action_plan'] = actionMatch.group(1)!.trim();
        debugPrint('✅ 대처방법 추출: ${result['action_plan']}');
      }
      
      // 숫자 없이 표현된 경우 첫 문장을 행동 설명으로, 나머지를 대처 방법으로 (백업 방법)
      if (result['behavior_description']!.isEmpty && result['action_plan']!.isEmpty) {
        final sentences = fixedResponse.split(RegExp(r'(?<=[.!?])\s+'));
        if (sentences.isNotEmpty) {
          result['behavior_description'] = sentences[0].trim();
          if (sentences.length > 1) {
            result['action_plan'] = sentences.sublist(1).join(' ').trim();
          }
        }
      }
      
      // 추가 정제
      if (result['behavior_description']!.isNotEmpty) {
        result['behavior_description'] = result['behavior_description']!
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
      
      if (result['action_plan']!.isNotEmpty) {
        result['action_plan'] = result['action_plan']!
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
      
      return result;
    } catch (e) {
      debugPrint('⚠️ Gemini 응답 파싱 중 오류: $e');
      return {
        'behavior_description': _fixUtf8Encoding(response),
        'action_plan': '',
      };
    }
  }

  // 로컬 알림 표시
  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // 알림 설정 확인
      final settings = await getNotificationSettings();
      final int stage = int.tryParse(notification['stage']?.toString() ?? '0') ?? 0;
      
      // 메인 알림 설정이 꺼져 있으면 알림 표시 안함
      if (!settings['main']!) {
        return;
      }
      
      // 단계별 알림 설정 확인
      if (stage == 0 && !settings['stage0']!) return;
      if (stage == 1 && !settings['stage1']!) return;
      if (stage == 2 && !settings['stage2']!) return;
      if (stage == 3 && !settings['stage3']!) return;
      
      // 알림 내용 준비
      final int id = notification['id'] ?? _generateNotificationId();
      
      // 알림 내용 우선순위: behavior_description > behavior_report > message
      String content = notification['behavior_description'] ?? 
                      notification['behavior_report'] ?? 
                      notification['message'] ?? '';
                      
      // 메시지 요약 - "1. " 이후의 내용만 표시
      if (content.contains("1. ")) {
        content = content.substring(content.indexOf("1. "));
      } else if (content.isEmpty) {
        content = '반려동물의 이상행동이 감지되었습니다.';
      }
      
      // 채널 ID와 이름 설정 (단계에 따라 다른 채널 사용)
      String channelId;
      String channelName;
      String channelDescription;
      
      switch (stage) {
        case 3:
          channelId = 'high_importance_channel';
          channelName = '높은 심각도 알림';
          channelDescription = '심각한 이상행동 감지 시 알림';
          break;
        case 2:
          channelId = 'medium_importance_channel';
          channelName = '중간 심각도 알림';
          channelDescription = '주의가 필요한 이상행동 감지 시 알림';
          break;
        case 1:
          channelId = 'low_importance_channel';
          channelName = '낮은 심각도 알림';
          channelDescription = '경미한 이상행동 감지 시 알림';
          break;
        default:
          channelId = 'normal_channel';
          channelName = '일반 알림';
          channelDescription = '일반 상태 알림';
      }
      
      // 안드로이드용 채널 설정
      AndroidNotificationDetails androidNotificationDetails;
      
      if (stage >= 2) {
        androidNotificationDetails = const AndroidNotificationDetails(
          'high_importance_channel',
          '높은 심각도 알림',
          channelDescription: '심각한 이상행동 감지 시 알림',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );
      } else if (stage == 1) {
        androidNotificationDetails = const AndroidNotificationDetails(
          'low_importance_channel',
          '낮은 심각도 알림',
          channelDescription: '경미한 이상행동 감지 시 알림',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showWhen: true,
        );
      } else {
        androidNotificationDetails = const AndroidNotificationDetails(
          'normal_channel',
          '일반 알림',
          channelDescription: '일반 상태 알림',
          importance: Importance.low,
          priority: Priority.low,
          showWhen: true,
        );
      }
      
      // iOS용 설정
      const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      // 플랫폼별 설정
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );
      
      // 알림 표시
      String title;
      if (stage >= 2) {
        title = '⚠️ 반려동물 이상행동 감지';
      } else if (stage == 1) {
        title = '⚠️ 반려동물 행동 변화 감지';
      } else {
        title = '반려동물 알림';
      }
      
      // payload에 모든 알림 정보 포함하여 알림 클릭 시 활용
      final String payload = json.encode(notification);
      
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        content,
        notificationDetails,
        payload: payload,
      );
      
      debugPrint('📲 시스템 알림 표시됨: $title - $content');
    } catch (e) {
      debugPrint('⚠️ 시스템 알림 표시 중 오류: $e');
    }
  }

  // 알림 갱신 (서버에서 다시 로드)
  Future<List<Map<String, dynamic>>> refreshNotifications() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getEvents),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ 알림 갱신 타임아웃');
          return http.Response('{"error": "timeout"}', 408);
        },
      );

      debugPrint('🔄 서버에서 알림 가져오기: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          // UTF-8로 명시적 디코딩하여 한글 인코딩 문제 해결
          final String decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
          final List<dynamic> eventsData = json.decode(decodedBody);
          
          debugPrint('📨 서버 응답: ${eventsData.length}개 이벤트');
          
          // 기존 알림 목록 로드
          final prefs   = await SharedPreferences.getInstance();
          final oldList = await loadSavedNotifications();
          final Map<int, bool> oldRead = {
            for (final n in oldList)
              (n['event_id'] ?? n['id'] ?? 0) : (n['read'] ?? false),
          };
          
          // 새 알림 목록 준비
          final List<Map<String, dynamic>> notifications = [];
          
          for (final dynamic eventData in eventsData) {
            try {
              // Map<dynamic, dynamic>을 Map<String, dynamic>으로 변환
              final Map<String, dynamic> event = _convertToStringKeyMap(eventData);
              
              // 기본 메시지 설정
              final String message = '반려동물의 이상행동이 감지되었습니다.';
              
              // 인코딩 문제가 있는 경우 수정
              String summary = event['summary'] ?? '';
              summary = _fixUtf8Encoding(summary);
              
              // 행동 설명 및 대처 방법
              String behaviorDescription = event['behavior_description'] ?? '';
              String behaviorReport = event['behavior_report'] ?? '';
              String actionPlan = event['action_plan'] ?? '';
              
              // 인코딩 문제 해결
              behaviorDescription = _fixUtf8Encoding(behaviorDescription);
              behaviorReport = _fixUtf8Encoding(behaviorReport);
              actionPlan = _fixUtf8Encoding(actionPlan);
              
              // 행동 설명이 비어있으면 Gemini 응답 파싱
              if (behaviorDescription.isEmpty && summary.isNotEmpty) {
                final Map<String, String> parsedResponse = parseGeminiResponse(summary);
                behaviorDescription = parsedResponse['behavior_description'] ?? message;
                if (actionPlan.isEmpty) {
                  actionPlan = parsedResponse['action_plan'] ?? '추가적인 이상행동이 있는지 주의 깊게 관찰하세요.';
                }
              }
              
              // 알림 데이터 보강 (모든 문자열 값에 인코딩 수정 적용)
              final int eventId = event['id'] ?? 0;

              final Map<String, dynamic> notification = {
                'id': event['id'] ?? DateTime.now().millisecondsSinceEpoch,
                'event_id': event['id'] ?? 0,
                'pet_id': event['pet_id'] ?? 1,
                'stage': (event['stage'] ?? 0).toString(),
                'message': _fixUtf8Encoding(message),
                'behavior_report': behaviorReport,
                'behavior_description': behaviorDescription,
                'action_plan': actionPlan,
                'time': event['created_at'] ?? DateTime.now().toString(),
                'video_name': event['video_name'],
                'read' : oldRead[eventId] ?? false,
              };
              
              // 유효한 알림만 추가
              if (notification['event_id'] > 0) {
                notifications.add(notification);
              }
            } catch (e) {
              debugPrint('⚠️ 이벤트 처리 중 오류: $e');
            }
          }
          
          // 알림 목록 저장
          if (notifications.isNotEmpty) {
            // 기존 알림과 병합
            final existingNotifications = await loadSavedNotifications();
            final Map<int, Map<String, dynamic>> uniqueNotifications = {};
            
            // 기존 알림 먼저 추가
            for (final notification in existingNotifications) {
              final int eventId = notification['event_id'] ?? notification['id'] ?? 0;
              if (eventId > 0) {
                uniqueNotifications[eventId] = notification;
              }
            }
            
            // 새 알림 추가 (중복 시 덮어씀)
            for (final notification in notifications) {
              final int eventId = notification['event_id'] ?? notification['id'] ?? 0;
              if (eventId > 0) {
                uniqueNotifications[eventId] = notification;
              }
            }
            
            // 최종 알림 목록 생성
            final List<Map<String, dynamic>> mergedNotifications = uniqueNotifications.values.toList();
            
            // 시간 기준으로 정렬 (최신순)
            mergedNotifications.sort((a, b) {
              final timeA = DateTime.tryParse(a['time'] ?? '') ?? DateTime.now();
              final timeB = DateTime.tryParse(b['time'] ?? '') ?? DateTime.now();
              return timeB.compareTo(timeA); // 최신순
            });
            
            // 저장
            await prefs.setString(_notificationsKey, json.encode(mergedNotifications));
            debugPrint('✅ 알림 ${mergedNotifications.length}개 저장 완료');

            await setUnreadFromServer(
                mergedNotifications.where((n) => !(n['read'] ?? false)).length);

            return mergedNotifications;
          }
        } catch (e) {
          debugPrint('⚠️ 응답 처리 중 오류: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 알림 갱신 중 오류: $e');
    }
    
    return [];
  }

  // 특정 이벤트 세부 정보 가져오기
  Future<Map<String, dynamic>?> getEventDetails(int eventId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getEventById.replaceFirst('{id}', eventId.toString())),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('🔔 이벤트 세부정보 가져오기 오류: $e');
      return null;
    }
  }

  // 알림 서비스 초기화
  Future<void> setupService() async {
    try {
      debugPrint('🔔 알림 서비스 초기화 중...');
      
      // 저장된 읽지 않은 알림 개수 로드
      final prefs = await SharedPreferences.getInstance();
      await setUnreadFromServer(prefs.getInt(_unreadCountKey) ?? 0);
      
      // 저장된 마지막 이벤트 ID 로드
      _lastEventId = prefs.getInt('lastEventId') ?? 0;
      
      // 타이머 시작 (중복 방지)
      _clearTimers();
      
      // HTTP 폴링 타이머 시작 (주요 메커니즘)
      _startPollingFallback();
      
      // 초기 알림 로드 (앱 시작 시 한 번)
      _checkNewEventsViaHttp();
      
      // 클라이언트 ID가 없으면 생성
      if (prefs.getInt('client_id') == null) {
        final clientId = DateTime.now().millisecondsSinceEpoch % 10000;
        await prefs.setInt('client_id', clientId);
      }
      
      // WebSocket 연결 시도 (보조 메커니즘)
      Future.delayed(const Duration(seconds: 3), () {
        _connectWebSocket();
      });
      
      debugPrint('✅ 알림 서비스 초기화 완료');
    } catch (e) {
      debugPrint('⚠️ 알림 서비스 초기화 오류: $e');
    }
  }

  // 타이머 정리 (다른 이름 사용)
  void _clearTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // dynamic Map을 String Map으로 변환
  Map<String, dynamic> _convertToStringKeyMap(Map<dynamic, dynamic> map) {
    final result = <String, dynamic>{};
    for (final key in map.keys) {
      result[key.toString()] = map[key];
    }
    return result;
  }
} 