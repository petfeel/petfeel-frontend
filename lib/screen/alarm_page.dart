// lib/screen/alarm_page.dart
import 'package:flutter/material.dart';
import 'alarm_detail_page.dart';
import 'home_connected_page.dart';
import '../utils/notification_service.dart';
import '../utils/api_endpoints.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alarm_all_page.dart';

class AlarmPage extends StatefulWidget {
  final Map<String, dynamic>? petData;

  const AlarmPage({Key? key, this.petData}) : super(key: key);

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  final List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 즉시 알림 로드 시도
    _loadNotifications();

    // 알림 스트림 구독
    _notificationSubscription = _notificationService.notificationStream.listen((notification) {
      debugPrint('⭐ 알림 수신: $notification');

      // 반려동물 ID 확인 - 현재 선택된 반려동물에 해당하는 알림만 표시
      final int notificationPetId = notification['pet_id'] ?? 0;
      final int currentPetId = widget.petData?['id'] ?? 0;

      // 필터링 확인 메시지
      debugPrint('🔍 알림 필터링: 알림 pet_id=$notificationPetId, 현재 pet_id=$currentPetId');

      // 특정 반려동물이 선택되었고, 알림이 해당 반려동물에 관한 것이 아니면 무시
      if (currentPetId > 0 && notificationPetId > 0 && notificationPetId != currentPetId) {
        debugPrint('🔕 현재 선택된 반려동물과 일치하지 않는 알림 무시');
        return;
      }

      if (!mounted) return;
      setState(() {
        // 중복 방지를 위해 이미 있는 알림인지 확인
        final existingIndex = _notifications.indexWhere((n) =>
        n['id'] == notification['id'] ||
            n['event_id'] == notification['event_id']);

        // 중복된 알림이고 내용이 있는 경우에만 업데이트
        if (existingIndex >= 0) {
          // 이미 있는 알림이면 내용 체크 후 업데이트
          final String newContent = notification['behavior_description'] ??
              notification['behavior_report'] ??
              notification['message'] ?? '';

          if (newContent.isNotEmpty) {
            // 새 알림의 내용이 있으면 업데이트
            _notifications[existingIndex] = notification;
          }
        } else {
          // 새 알림이고 내용이 있는 경우만 추가
          final String content = notification['behavior_description'] ??
              notification['behavior_report'] ??
              notification['message'] ?? '';

          if (content.isNotEmpty) {
            _notifications.insert(0, notification);
          }
        }
      });

      // 메시지 바 표시 (스낵바)
      if (mounted) {
        _showMessageBar(notification);
      }
    });

    // 알림 수신 준비
    _notificationService.startListening();

    // 로컬 알림 탭 시 처리
    _setupNotificationTapAction();

    // 모든 알림 읽음 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notificationService.markAllAsRead();
      }
    });
  }

  // 알림 탭 시 처리하는 함수
  void _setupNotificationTapAction() {
    _notificationService.flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails().then((details) {
      if (!mounted) return;
      if (details != null && details.didNotificationLaunchApp && details.notificationResponse?.payload != null) {
        try {
          final notification = json.decode(details.notificationResponse!.payload!);
          _handleNotificationTap(notification);
        } catch (e) {
          debugPrint('알림 페이로드 처리 중 오류: $e');
        }
      }
    });
  }

  // 알림 탭 시 해당 알림 상세 페이지로 이동
  void _handleNotificationTap(Map<String, dynamic> notification) {
    if (!mounted) return;

    // 알림 상세 페이지로 이동
    Navigator.push(
      context,
      _route(
        AlarmDetailPageApp(
          petData: widget.petData ?? {},
          alertMessage: notification['behavior_report'] ?? notification['message'] ?? '',
          alertTime: notification['time'] ?? '',
          actionPlan: notification['action_plan'] ?? '',
          stage: int.tryParse(notification['stage']?.toString() ?? '0') ?? 0,
          behaviorDescription: notification['behavior_description'] ?? '',
          eventId: notification['event_id'] ?? 0,
          videoName: notification['video_name'],
        ),
      ),
    );
  }

  // 메시지 바 표시 (스낵바)
  void _showMessageBar(Map<String, dynamic> notification) {
    if (!mounted) return;

    final int stage = int.tryParse(notification['stage']?.toString() ?? '0') ?? 0;

    // 메시지 추출
    String message = notification['behavior_description'] ??
        notification['behavior_report'] ??
        notification['message'] ??
        '반려동물의 이상행동이 감지되었습니다.';

    // 메시지 요약 처리
    if (message.contains("1. ")) {
      message = message.substring(message.indexOf("1. "));
    }

    // 색상: stage 기준 또는 기본
    final Color backgroundColor = stage >= 3
        ? Colors.red
        : stage >= 2
        ? Colors.orange
        : Colors.green;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'LGSmartUI',
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(milliseconds: 1200),
        action: SnackBarAction(
          label: '보기',
          textColor: Colors.white,
          onPressed: () {
            if (mounted) {
              _handleNotificationTap(notification);
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // 기존 알림 로드 (로컬 저장소에서 가져오기)
  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 저장된 알림 목록 가져오기
      final notifications = await _notificationService.loadSavedNotifications();

      if (!mounted) return;

      // 현재 선택된 반려동물에 해당하는 알림만 필터링
      final int currentPetId = widget.petData?['id'] ?? 0;
      final filteredNotifications = currentPetId > 0
          ? notifications.where((n) {
        final notificationPetId = n['pet_id'] ?? 0;
        return notificationPetId == 0 || notificationPetId == currentPetId;
      }).toList()
          : notifications;

      setState(() {
        _notifications.clear();
        _notifications.addAll(filteredNotifications);
        _isLoading = false;
      });

      debugPrint('📋 알림 ${filteredNotifications.length}개 로드됨 (총 ${notifications.length}개 중)');

      // 저장된 알림이 없으면 서버에서 가져오기
      if (_notifications.isEmpty) {
        _loadNotificationsFromServer();
      }
    } catch (e) {
      debugPrint('알림 로드 중 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // 오류 발생 시 서버에서 직접 가져오기 시도
      _loadNotificationsFromServer();
    }
  }

  // 서버에서 알림 가져오기 (백업 방법)
  Future<void> _loadNotificationsFromServer() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 반려동물 ID
      final int petId = widget.petData?['id'] ?? 0;

      // 최신 이벤트 목록 가져오기 - 선택된 반려동물이 있으면 해당 반려동물의 알림만 가져옴
      String url = ApiEndpoints.getEvents;
      if (petId > 0) {
        url += '?pet_id=$petId';
      }

      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // UTF-8로 디코딩하여 인코딩 문제 해결
        final List<dynamic> events = json.decode(utf8.decode(response.bodyBytes));

        // 이벤트를 알림 형식으로 변환
        final List<Map<String, dynamic>> notifications = [];

        for (final event in events) {
          try {
            // 최대 10개만 가져옴
            if (notifications.length >= 10) break;

            // 요약 정보 확인
            final String summary = event['summary'] ?? '';

            // 항상 요약 정보를 표시하도록 함
            final Map<String, dynamic> notification = {
              'id': event['id'] ?? 0,
              'event_id': event['id'] ?? 0,
              'pet_id': event['pet_id'] ?? 0,
              'stage': (event['stage'] ?? 0).toString(),
              // summary가 비어있는 경우에만 기본 메시지 사용
              'message': summary.isEmpty ? '반려동물의 이상행동이 감지되었습니다.' : summary,
              'behavior_report': summary,
              'time': event['created_at'] ?? DateTime.now().toString(),
              'read': false, // 새로 불러온 알림은 읽지 않은 상태로 설정
              'video_name': event['video_name'],
            };

            // 알림 저장 (saveNotification은 void 반환)
            await _notificationService.saveNotification(notification);
            notifications.add(notification);
          } catch (e) {
            debugPrint('이벤트 처리 중 오류: $e');
          }
        }

        if (!mounted) return;

        // 시간 기준으로 정렬 (최신순)
        notifications.sort((a, b) {
          final timeA = DateTime.tryParse(a['time'] ?? '') ?? DateTime.now();
          final timeB = DateTime.tryParse(b['time'] ?? '') ?? DateTime.now();
          return timeB.compareTo(timeA); // 최신순
        });

        // 중복 제거 (동일한 이벤트 ID를 가진 알림 중 최신 것만 유지)
        final Map<int, Map<String, dynamic>> uniqueNotifications = {};

        for (final notification in notifications) {
          final int eventId = notification['event_id'] ?? notification['id'] ?? 0;
          if (eventId > 0) {
            uniqueNotifications[eventId] = notification;
          }
        }

        // 기존 알림과 합치기
        setState(() {
          _notifications.clear();
          _notifications.addAll(uniqueNotifications.values.toList());
          _isLoading = false;
        });

        debugPrint('서버에서 알림 ${notifications.length}개 로드됨, 중복 제거 후 ${uniqueNotifications.length}개');
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('서버에서 알림 로드 중 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,                    // Calendar 페이지와 동일하게 0.5로 설정
        centerTitle: true,                 // 타이틀을 중앙 정렬
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '알림',
          style: TextStyle(
            fontFamily: 'LGSmartUI',        // Calendar 페이지와 동일한 폰트
            fontSize: 22,                   // Calendar 페이지와 동일한 크기
            fontWeight: FontWeight.w600,    // Calendar 페이지와 동일한 두께
            color: Colors.black,
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Colors.black),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity(horizontal: -4, vertical: -4), // 더 조밀하게
                constraints: const BoxConstraints(), // 최소 크기 제한 제거
                onPressed: () {
                  Navigator.push(
                    context,
                    _route(AlarmAllPage(petData: widget.petData ?? {})),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                constraints: const BoxConstraints(),
                onPressed: () {
                  _loadNotifications();
                  _notificationService.loadSavedNotifications().then((notifications) {
                    setState(() {
                      _notifications.clear();
                      _notifications.addAll(notifications);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '알림이 새로고침되었습니다',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'LGSmartUI',
                            fontSize: 14,
                          ),
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        duration: const Duration(milliseconds: 1200),
                      ),
                    );
                  });
                },
              ),
              const SizedBox(width: 16), // 우측 끝 간격
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
          stream: Stream.value(_notifications),
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return const Center(
                child: Text(
                  '아직 알림이 없습니다',
                  style: TextStyle(
                    fontFamily: 'LGSmartUI',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final String message = notification['behavior_description'] ??
                      notification['behavior_report'] ??
                      notification['message'] ??
                      '이상행동이 감지되었습니다.';
                  final String time = notification['time'] ?? '시간 정보 없음';
                  final int stage = int.tryParse(notification['stage']?.toString() ?? '0') ?? 0;

                  return Column(
                    children: [
                      if (index == 0) const SizedBox(height: 30),
                      _buildAlertTile(context, message, time, notification, stage),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            );
          }
      ),
    );
  }

  Widget _buildAlertTile(BuildContext context, String message, String time, Map<String, dynamic> notification, int stage) {
    // 단계에 따른 배경색 설정
    final Color backgroundColor = _getStageColor(stage);

    // 단계에 따른 아이콘 설정
    final IconData icon = _getStageIcon(stage);

    // 시간 형식 변환 (T 제거)
    final formattedTime = _formatTime(time);

    // 메시지 요약 - "1. " 이후의 내용만 표시
    String displayMessage = message;
    if (displayMessage.contains("1. ")) {
      displayMessage = displayMessage.substring(displayMessage.indexOf("1. "));
    } else if (displayMessage.isEmpty) {
      displayMessage = '반려동물의 이상행동이 감지되었습니다.';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          _route(
            AlarmDetailPageApp(
              petData: widget.petData ?? {},
              alertMessage: notification['behavior_report'] ?? message,
              alertTime: formattedTime, // 포맷된 시간 전달
              actionPlan: notification['action_plan'] ?? '',
              stage: stage,
              behaviorDescription: notification['behavior_description'] ?? '',
              eventId: notification['event_id'] ?? 0,
              videoName: notification['video_name'],
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                height: 50,
                child: Center(
                  child: Icon(icon, size: 20, color: Colors.black),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          displayMessage,
                          style: const TextStyle(
                            fontFamily: 'LGSmartUI',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // 심각도 1 이상이거나 비디오가 있는 경우 비디오 아이콘 표시
                      if (stage >= 1 || (notification['video_name'] != null && notification['video_name'].toString().isNotEmpty))
                        const Icon(
                          Icons.videocam,
                          size: 16,
                          color: Colors.black54,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              formattedTime,
              style: const TextStyle(
                fontFamily: 'LGSmartUI',
                fontSize: 10,
                color: Color(0xFFB1B1B1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 단계에 따른 배경색 반환
  Color _getStageColor(int stage) {
    switch (stage) {
      case 0:
        return const Color(0x4CE0F5EF); // 매우 연한 민트색 (정상)
      case 1:
        return const Color(0x4CB8E5E0); // 연한 민트색 (주의)
      case 2:
        return const Color(0x4CFFD9A3); // 연한 노란색 (경고)
      case 3:
        return const Color(0x4CFFB1B1); // 연한 빨간색 (위험)
      default:
        return const Color(0x4CB8E5E0); // 기본 색상
    }
  }

  // 단계에 따른 아이콘 반환
  IconData _getStageIcon(int stage) {
    switch (stage) {
      case 0:
        return Icons.pets; // 기본 반려동물 아이콘
      case 1:
        return Icons.visibility; // 관찰 필요
      case 2:
        return Icons.warning; // 주의
      case 3:
        return Icons.error; // 위험
      default:
        return Icons.pets; // 기본 반려동물 아이콘
    }
  }

  // 시간 형식화 함수 수정
  String _formatTime(String timeString) {
    try {
      // T 제거를 위한 시간 문자열 전처리
      timeString = timeString.replaceAll('T', ' ');
      final time = DateTime.parse(timeString);
      final now = DateTime.now();

      if (time.year == now.year && time.month == now.month && time.day == now.day) {
        // 오늘
        return '오늘 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (time.year == now.year && time.month == now.month && time.day == now.day - 1) {
        // 어제
        return '어제 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        // 그 외
        return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // T 포함된 원본 문자열에서 T 제거하여 반환
      return timeString.replaceAll('T', ' ');
    }
  }
}

PageRouteBuilder _route(Widget page) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, animation, __, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    final scale = Tween<double>(begin: 0.95, end: 1.0).animate(curved);
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: child),
    );
  },
);
