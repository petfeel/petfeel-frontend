import 'package:flutter/material.dart';
import 'package:test123/screen/streaming_page.dart';
import 'package:test123/screen/diary_page.dart';
import 'package:test123/screen/calendar_page.dart';
import 'package:test123/screen/profile_edit_page.dart';
import 'package:test123/screen/alarm_page.dart';
import 'package:test123/screen/settings_page.dart';
import 'package:test123/screen/alarm_detail_page.dart';
import 'package:test123/utils/api_endpoints.dart';
import 'package:test123/utils/notification_service.dart';
import 'dart:async';

extension OpacityX on Color {
  /// 예) Colors.white.o(0.6) == Colors.white.withAlpha(153)
  Color o(double opacity) => withAlpha((opacity * 255).round());
}

class HomeConnected extends StatefulWidget {
  final List<dynamic> pets;
  final int initialIndex;

  const HomeConnected({
    super.key,
    required this.pets,
    required this.initialIndex,
  });

  @override
  State<HomeConnected> createState() => _HomeConnectedState();
}

class _HomeConnectedState extends State<HomeConnected> {
  late PageController _pageController;
  late List<dynamic> pets;
  late int absolutePage;
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _recentNotifications = [];
  StreamSubscription? _notificationSubscription;

  // 중복 요청 방지를 위한 플래그 (static을 클래스 레벨로 이동)
  static bool _isLoadingNotifications = false;

  int get currentIndex => pets.isNotEmpty ? absolutePage % pets.length : 0;

  Map<String, dynamic> get _petData =>
      pets.isNotEmpty ? pets[currentIndex] : <String, dynamic>{};

  @override
  void initState() {
    super.initState();

    pets = List.from(widget.pets);

    // ✅ 펫이 없으면 자동으로 이전 화면으로 되돌아감
    if (pets.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return;
    }

    absolutePage = pets.length * 1000 + widget.initialIndex;
    _pageController = PageController(initialPage: absolutePage);

    // 알림 관련 데이터 로드
    _notificationService.startListening();
    _notificationService.getUnreadCount();
    _reloadRecentNotifications();

    // 알림 스트림 구독 - 실시간 업데이트를 위해 추가
    _notificationSubscription = _notificationService.notificationStream.listen((notification) {
      if (!mounted) return;
      
      debugPrint('📱 홈 화면에서 새 알림 수신: $notification');
      
      // 알림 내용 확인 - 빈 메시지 필터링
      final String content = notification['behavior_description'] ?? 
                           notification['behavior_report'] ?? 
                           notification['message'] ?? '';
      
      if (content.isEmpty || content == '반려동물의 이상행동이 감지되었습니다.') {
        debugPrint('🔕 내용이 없거나 기본 메시지인 알림 무시');
        return;
      }
      
      // 반려동물 ID 확인 - 현재 선택된 반려동물에 해당하는 알림만 표시
      final int notificationPetId = notification['pet_id'] ?? 0;
      final int currentPetId = _petData['id'] ?? 0;
      
      // 디버그 로그 추가
      debugPrint('🔍 알림 필터링: 알림 pet_id=$notificationPetId, 현재 pet_id=$currentPetId');
      
      // 특정 반려동물이 선택되었고, 알림이 해당 반려동물에 관한 것이 아니면 무시
      if (currentPetId > 0 && notificationPetId > 0 && notificationPetId != currentPetId) {
        debugPrint('🔕 현재 선택된 반려동물과 일치하지 않는 알림 무시');
        return;
      }
      
      // 중복 방지를 위해 이미 있는 알림인지 확인
      final int eventId = notification['event_id'] ?? notification['id'] ?? 0;
      final existingIndex = _recentNotifications.indexWhere((n) =>
        (n['id'] == notification['id'] && notification['id'] != null) || 
        (n['event_id'] == eventId && eventId > 0));
      
      // 최근 알림 목록 업데이트 (setState 내부에서 처리)
      setState(() {
        if (existingIndex >= 0) {
          // 이미 있는 알림이면 업데이트
          _recentNotifications[existingIndex] = notification;
          debugPrint('🔄 기존 알림 업데이트: index=$existingIndex');
        } else {
          // 새 알림이면 추가 (최신순으로 정렬)
          _recentNotifications.insert(0, notification);
          debugPrint('➕ 새 알림 추가: 현재 알림 수=${_recentNotifications.length}');
          
          // 최대 3개만 유지
          if (_recentNotifications.length > 3) {
            _recentNotifications.removeLast();
          }
          
          // 읽지 않은 알림 개수 업데이트 (즉시 반영)
        }
      });
      
      // 푸시 알림 표시 (약간의 지연 후)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _showNotificationToast(notification);
        }
      });
      
      // 알림 데이터 저장 후 즉시 새로고침
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _loadRecentNotifications();
        }
      });
    });

    // 주기적으로 알림 데이터 새로고침 (30초마다)
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadRecentNotifications();
      } else {
        timer.cancel(); // 화면이 사라지면 타이머 취소
      }
    });
  }

  void _reloadRecentNotifications() {
    _loadRecentNotifications();
  }

  // ────────── HomeConnected.dart ──────────
  void _showNotificationToast(Map<String, dynamic> notification) {
    if (!mounted) return;

    // ── 단계별 컬러 & 이모지 ──────────────────────────────────────────────
    final int stage = int.tryParse(notification['stage']?.toString() ?? '0') ?? 0;
    final stageData = [
      {'emoji': '☀️', 'color': const Color(0xFFE0F7FA)}, // Normal   – 스카이블루
      {'emoji': '⛅', 'color': const Color(0xFFB2DFDB)}, // Caution  – 민트그레이
      {'emoji': '☁️', 'color': const Color(0xFFFFF3C4)}, // Warning  – 소프트앰버
      {'emoji': '⛈️', 'color': const Color(0xFFFFCDD2)}, // Danger   – 로즈핑크
    ][stage.clamp(0, 3)];

    // ── 내용 추출 & 요약 ────────────────────────────────────────────────
    String content = notification['behavior_description'] ??
        notification['behavior_report'] ??
        notification['message'] ??
        '반려동물의 이상행동이 감지되었습니다.';
    if (content.contains('1. ') && content.contains('2. ')) {
      content = content.substring(
        content.indexOf('1. ') + 3,
        content.indexOf('2. '),
      ).trim();
    }

    // ── 커스텀 스낵바 표시 ───────────────────────────────────────────────
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // ❶ 완전 투명 배경 + 패딩 0 (Content 컨테이너로 스타일링)
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: kToolbarHeight + 8,          // 앱바 바로 아래
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 5),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (stageData['color'] as Color).o(0.95),
                (stageData['color'] as Color).o(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(blurRadius: 12, offset: Offset(0, 3), color: Colors.black26),
            ],
          ),
          child: Row(
            children: [
              // ❸ 이모지 크기 ↑
              Text(stageData['emoji'] as String, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              // ❹ 메시지 : 글자 크기·굵기 ↑
              Expanded(
                child: Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'LGSmartUI',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              // ❺ “보기” 버튼 – 기존 SnackBarAction 대체 (글자 검은색 → 흰색)
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(_route(
                    AlarmDetailPageApp(
                      petData: _petData,
                      alertMessage: notification['behavior_report'] ?? content,
                      alertTime: _formatTime(notification['time'] ?? ''),
                      stage: stage,
                      behaviorDescription: notification['behavior_description'] ?? '',
                      actionPlan: notification['action_plan'] ?? '',
                      eventId: notification['event_id'] ?? 0,
                      videoName: notification['video_name'],
                    ),
                  ))
                      .then((_) => _reloadRecentNotifications());
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: const Text('보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // 최근 알림 가져오기
  Future<void> _loadRecentNotifications() async {
    try {
      // 이미 로딩 중이면 중복 요청 방지
      if (_isLoadingNotifications) return;

      _isLoadingNotifications = true;
      debugPrint('📋 최근 알림 로드 시작');

      // 서버에서 최신 알림 데이터 가져오기 (항상 서버에서 최신 데이터 가져오기)
      await _notificationService.refreshNotifications();
      
      // 저장된 알림 중 최근 3개 가져오기
      final savedNotifications = await _notificationService.loadSavedNotifications();

      debugPrint('📬 저장된 알림: ${savedNotifications.length}개');
      if (savedNotifications.isNotEmpty) {
        debugPrint('   - 첫 번째 알림: ${savedNotifications[0]}');
      }

      // 현재 선택된 반려동물에 해당하는 알림만 필터링
      final int currentPetId = _petData['id'] ?? 0;
      final filteredNotifications = currentPetId > 0
          ? savedNotifications.where((n) {
              final notificationPetId = n['pet_id'] ?? 0;
              return notificationPetId == 0 || notificationPetId == currentPetId;
            }).toList()
          : savedNotifications;

      // 내용이 없는 알림 필터링
      final validNotifications = filteredNotifications.where((notification) {
        final String content = notification['behavior_description'] ?? 
                              notification['behavior_report'] ?? 
                              notification['message'] ?? '';
        return content.isNotEmpty && 
               content != '이상행동이 감지되었습니다.' && 
               content != '반려동물의 이상행동이 감지되었습니다.';
      }).toList();

      debugPrint('🔍 필터링 후 유효한 알림: ${validNotifications.length}개');
      
      // 날짜 기준으로 정렬 (최신순)
      validNotifications.sort((a, b) {
        final timeA = DateTime.tryParse(a['time'] ?? '') ?? DateTime.now();
        final timeB = DateTime.tryParse(b['time'] ?? '') ?? DateTime.now();
        return timeB.compareTo(timeA); // 최신순
      });
      
      // 중복 제거
      final Map<int, Map<String, dynamic>> uniqueNotifications = {};
      for (final notification in validNotifications) {
        final int eventId = notification['event_id'] ?? notification['id'] ?? 0;
        if (eventId > 0) {
          uniqueNotifications[eventId] = notification;
        }
      }
      
      if (mounted) {
        setState(() {
          _recentNotifications = uniqueNotifications.values.toList().take(3).toList();
          debugPrint('📊 알림 UI 업데이트: ${_recentNotifications.length}개');
        });
      }

      _isLoadingNotifications = false;
    } catch (e) {
      debugPrint('❌ 최근 알림 로드 중 오류: $e');
      // 에러 발생 시에도 플래그 초기화
      _isLoadingNotifications = false;
    }
  }

  @override
  void dispose() {
    if (pets.isNotEmpty) {
      _pageController.dispose();
    }
    // 스트림 구독 취소
    _notificationSubscription?.cancel();
    _notificationService.stopListening();
    super.dispose();
  }

  Future<void> _openEditPage() async {
    if (pets.isEmpty) return;

    final result = await Navigator.of(context).push(
      _route(ProfileEditPage(petData: _petData)),
    );

    if (!mounted || result == null) return;

    if (result is Map<String, dynamic> && result['deleted'] == true) {
      Navigator.of(context).pop(result);
      return;
    }

    if (result is Map<String, dynamic>) {
      setState(() {
        pets[currentIndex] = result;
      });
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_petData);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) return const SizedBox.shrink();

    return PopScope(
      canPop: false,                         // 뒤로가기 직접 제어
      onPopInvoked: (bool didPop) async {    // ← A 버전: bool 하나만 받음
        if (!didPop) {
          await _onWillPop();                // 기존 로직 호출
          // didPop 값을 따로 바꿀 필요 없음
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBCDFDB), Color(0xFFDBECF4), Color(0xFFC0D3E4)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: _buildAppBar(),
          body: _buildPageViewBody(),
          bottomNavigationBar: _buildBottomNavBar(),
        ),
      ),
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(_petData),
      ),
      title: Text(
        '${_petData['pet_name'] ?? '펫'} 홈',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'LGSmartUI',
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: StreamBuilder<int>(
            stream: _notificationService.unreadCountStream,
            initialData: 0,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications, color: Colors.grey[800]),
                    onPressed: () async {
                      if (pets.isEmpty) return;
                      await Navigator.of(context)
                          .push(_route(AlarmPage(petData: _petData)));
                      // 알림을 모두 본 뒤 숫자 리셋
                      await _notificationService.markAllAsRead();
                      await _notificationService.getUnreadCount();
                      _reloadRecentNotifications();
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageViewBody() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal,
      physics: pets.length > 1
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (int newAbsolutePage) {
        setState(() {
          absolutePage = newAbsolutePage;
        });
      },
      itemBuilder: (context, index) {
        final pet = pets[index % pets.length];
        return _buildBodyForPet(pet);
      },
    );
  }

  Widget _buildBodyForPet(Map<String, dynamic> pet) {
    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                (kToolbarHeight +
                    MediaQuery.of(context).viewPadding.top +
                    MediaQuery.of(context).viewPadding.bottom +
                    kBottomNavigationBarHeight),
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _openEditPage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: (pet['image_path'] != null &&
                        pet['image_path'].toString().isNotEmpty)
                        ? NetworkImage('${ApiEndpoints.base}${pet['image_path']}')
                        : const NetworkImage('https://placehold.co/149x149'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildStatusCard(),
              const SizedBox(height: 24),
              _buildDeviceSection(),
              const SizedBox(height: 24),
              _buildAlertSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    String statusText = '특이사항은 없습니다';
    String lastActivity = '방금 전';

    // 최근 알림이 있으면 상태 텍스트 업데이트
    if (_recentNotifications.isNotEmpty) {
      final latestNotification = _recentNotifications[0];
      debugPrint('🔍 최근 알림 표시: $latestNotification');

      final stage = int.tryParse(latestNotification['stage']?.toString() ?? '0') ?? 0;

      if (stage > 0) {
        statusText = latestNotification['behavior_description'] ??
            latestNotification['behavior_report'] ??
            latestNotification['message'] ??
            '이상행동이 감지되었습니다';
      } else {
        statusText = latestNotification['behavior_description'] ??
            latestNotification['behavior_report'] ??
            latestNotification['message'] ??
            '정상적인 행동을 하고 있습니다';
      }

      // 시간 형식화
      final notificationTime = latestNotification['time'] ?? '';
      if (notificationTime.isNotEmpty) {
        try {
          final time = DateTime.parse(notificationTime);
          final now = DateTime.now();
          final difference = now.difference(time);

          if (difference.inMinutes < 1) {
            lastActivity = '방금 전';
          } else if (difference.inHours < 1) {
            lastActivity = '${difference.inMinutes}분 전';
          } else if (difference.inDays < 1) {
            lastActivity = '${difference.inHours}시간 전';
          } else {
            lastActivity = '${difference.inDays}일 전';
          }
        } catch (e) {
          lastActivity = notificationTime;
        }
      }
    }

    return GestureDetector(
      onTap: () {
        // 최근 알림이 있으면 해당 알림의 상세 페이지로 이동
        if (_recentNotifications.isNotEmpty) {
          final latestNotification = _recentNotifications[0];
          final int stage = int.tryParse(latestNotification['stage']?.toString() ?? '0') ?? 0;
          final String actionPlan = latestNotification['action_plan'] ?? '';
          final String formattedTime = latestNotification['time'] != null 
              ? _formatTime(latestNotification['time']) 
              : lastActivity;
          
          Navigator.of(context).push(_route(
            AlarmDetailPageApp(
              petData: _petData,
              alertMessage: latestNotification['message'] ?? statusText,
              alertTime: formattedTime,
              stage: stage,
              behaviorDescription: latestNotification['behavior_description'] ?? 
                                   latestNotification['behavior_report'] ?? '',
              actionPlan: actionPlan,
            ),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.6 * 255).round()),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00B300),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('상태', style: TextStyle(fontFamily: 'LGSmartUI', fontSize: 14)),
                    SizedBox(
                      width: 200,
                      child: Text(
                        statusText,
                        style: const TextStyle(
                            fontFamily: 'LGSmartUI',
                            fontSize: 12,
                            color: Colors.grey
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('마지막 활동:', style: TextStyle(fontFamily: 'LGSmartUI', fontSize: 12)),
                Text(
                    lastActivity,
                    style: const TextStyle(fontFamily: 'LGSmartUI', fontSize: 12, color: Colors.grey)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSection() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('연결 기기', style: TextStyle(fontFamily: 'LGSmartUI', fontSize: 18)),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildDeviceCard('Smart Camera', '카메라', '연결됨'),
              const SizedBox(width: 16), // 간격 벌리기
              _buildDeviceCard('Microphone', '마이크', '연결됨'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(String title, String subtitle, String status) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black.o(0.05),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            alignment: Alignment.center,
            child: Text(title, style: const TextStyle(fontFamily: 'LGSmartUI', fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(subtitle, style: const TextStyle(fontFamily: 'LGSmartUI', fontSize: 12)),
                const SizedBox(height: 4),
                Text(status,
                    style: const TextStyle(
                        fontFamily: 'LGSmartUI', fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () {
              if (_recentNotifications.isNotEmpty) {
                Navigator.of(context).push(_route(AlarmPage(petData: _petData))).then((_) {
                  // 알림 화면에서 돌아오면 읽지 않은 알림 개수 새로고침
                  _reloadRecentNotifications();
                });
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('최근 알림', style: TextStyle(fontFamily: 'LGSmartUI', fontSize: 18)),
                if (_recentNotifications.isNotEmpty)
                  Row(
                    children: const [
                      Text(
                        '더보기',
                        style: TextStyle(
                          fontFamily: 'LGSmartUI',
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black54),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _recentNotifications.isEmpty
            ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.6 * 255).round()),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Text(
                '아직 알림이 없습니다',
                style: TextStyle(
                  fontFamily: 'LGSmartUI',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        )
            : Column(
          children: _recentNotifications.map((notification) {
            final String time = notification['time'] ?? '시간 정보 없음';
            final String formattedTime = _formatTime(time);
            
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
            
            final int stage = int.tryParse(notification['stage']?.toString() ?? '0') ?? 0;
            String emoji = '';

            switch (stage) {
              case 0:
                emoji = '☀️';
                break;
              case 1:
                emoji = '⛅';
                break;
              case 2:
                emoji = '☁️';
                break;
              case 3:
                emoji = '⛈️';
                break;
              default:
                emoji = '🔔';
            }

            return _buildAlertTile(formattedTime, content, emoji, notification);
          }).toList(),
        ),
      ],
    );
  }

  // 시간 형식화 함수
  String _formatTime(String timeString) {
    try {
      // T 제거를 위한 시간 문자열 전처리
      timeString = timeString.replaceAll('T', ' ');
      final time = DateTime.parse(timeString);
      final now = DateTime.now();

      if (time.year == now.year && time.month == now.month && time.day == now.day) {
        // 오늘
        return '오늘 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } else if (time.year == now.year && time.month == now.month && time.day == now.day - 1) {
        // 어제
        return '어제 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        // 그 외
        return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // T 포함된 원본 문자열에서 T 제거하여 반환
      return timeString.replaceAll('T', ' ');
    }
  }

  Widget _buildAlertTile(String time, String content, String emoji, Map<String, dynamic> notification) {
    // 스테이지 정보 가져오기
    final int stage = int.tryParse(notification['stage']?.toString() ?? '0') ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: () {
          // 알림을 클릭하면 해당 알림의 상세 페이지로 이동
          if (notification.isNotEmpty) {
            final String actionPlan = notification['action_plan'] ?? '';
            
            Navigator.of(context).push(_route(
              AlarmDetailPageApp(
                petData: _petData,
                alertMessage: notification['behavior_report'] ?? notification['message'] ?? content,
                alertTime: time,
                stage: stage,
                behaviorDescription: notification['behavior_description'] ?? notification['behavior_report'] ?? '',
                actionPlan: actionPlan,
                eventId: notification['event_id'] ?? 0,
                videoName: notification['video_name'],
              ),
            ));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.6 * 255).round()),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(time, style: const TextStyle(fontFamily: 'LGSmartUI', fontSize: 14)),
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
                    Text(
                      content,
                      style: TextStyle(
                          fontFamily: 'LGSmartUI',
                          fontSize: 12,
                        color: Colors.black.o(0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Theme(
      data: ThemeData(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        // 👉 추가: 글자 크기·폰트 고정
        selectedLabelStyle: const TextStyle(
          fontFamily: 'LGSmartUI',
          fontSize: 12,           // 원하는 크기로 통일
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'LGSmartUI',
          fontSize: 12,           // ↑와 동일
          fontWeight: FontWeight.w500,
        ),
        onTap: (idx) {
          if (pets.isEmpty) return;
          if (idx == 0) {
            Navigator.of(context).push(_route(Calendar(petData: _petData))).then((_) {
              _reloadRecentNotifications();
            });
          } else if (idx == 1) {
            Navigator.of(context).push(_route(Streaming(petData: _petData))).then((_) {
              _reloadRecentNotifications();
            });
          } else if (idx == 2) {
            Navigator.of(context).push(_route(DiaryPage.single(petData: _petData))).then((_) {
              _reloadRecentNotifications();
            });
          } else if (idx == 3) {
            Navigator.of(context).push(_route(const SettingsPage())).then((_) {
              _reloadRecentNotifications();
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '캘린더'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '일기'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }

  PageRouteBuilder _route(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
        final scale = Tween<double>(begin: 0.95, end: 1.0).animate(curved);
        return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
      },
    );
  }
}
