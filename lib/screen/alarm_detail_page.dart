import 'package:flutter/material.dart';
import 'alarm_all_page.dart'; // ⬅️ 추가
import 'alarm_video_page.dart'; // ⬅️ 영상 페이지 추가
import 'dart:convert';

class AlarmDetailPageApp extends StatelessWidget {
  final Map<String, dynamic> petData;
  final String alertMessage;
  final String alertTime;
  final String actionPlan;
  final int stage;
  final String behaviorDescription; // 행동 설명 추가
  final int eventId; // 이벤트 ID 추가
  final String? videoName; // 비디오 파일명 추가

  const AlarmDetailPageApp({
    super.key,
    required this.petData,
    required this.alertMessage,
    required this.alertTime,
    this.actionPlan = '',
    this.stage = 0,
    this.behaviorDescription = '', // 행동 설명 필드 추가
    this.eventId = 0, // 이벤트 ID 추가
    this.videoName, // 비디오 파일명 추가
  });

  @override
  Widget build(BuildContext context) {
    // 인코딩 문제 해결
    String safeAlertMessage = alertMessage;
    String safeBehaviorDescription = behaviorDescription;
    String safeActionPlan = actionPlan;
    
    try {
      if (alertMessage.isNotEmpty) {
        final List<int> msgBytes = utf8.encode(alertMessage);
        safeAlertMessage = utf8.decode(msgBytes, allowMalformed: true);
      }
      
      if (behaviorDescription.isNotEmpty) {
        final List<int> descBytes = utf8.encode(behaviorDescription);
        safeBehaviorDescription = utf8.decode(descBytes, allowMalformed: true);
      }
      
      if (actionPlan.isNotEmpty) {
        final List<int> actionBytes = utf8.encode(actionPlan);
        safeActionPlan = utf8.decode(actionBytes, allowMalformed: true);
      }
    } catch (e) {
      debugPrint('⚠️ 텍스트 인코딩 수정 중 오류: $e');
    }
    
    // 실제 표시할 내용 결정 (파싱된 내용이 있으면 그것을 사용, 없으면 전체 메시지)
    final String displayDescription = safeBehaviorDescription.isNotEmpty 
        ? safeBehaviorDescription 
        : safeAlertMessage;
    
    final String displayActionPlan = safeActionPlan.isNotEmpty 
        ? safeActionPlan 
        : '추가적인 이상행동이 있는지 주의 깊게 관찰하고, 계속 지속될 시 수의사와 상담하세요.';
    
    // 디버깅 로그 추가
    debugPrint('📝 알림 상세 표시:');
    debugPrint('- 단계: $stage');
    debugPrint('- 메시지: $safeAlertMessage');
    debugPrint('- 행동 설명: $safeBehaviorDescription');
    debugPrint('- 표시할 설명: $displayDescription');
    debugPrint('- 대처 방법: $displayActionPlan');
    debugPrint('- 비디오: $videoName');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,                  // Calendar/AlarmPage와 동일하게 0.5로 설정
        centerTitle: true,               // 타이틀을 중앙 정렬
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          '알림 상세',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,                // Calendar/AlarmPage와 동일한 크기
            fontWeight: FontWeight.w600, // Calendar/AlarmPage와 동일한 두께
            fontFamily: 'LGSmartUI',     // 동일한 폰트
          ),
        ),
        actionsPadding: const EdgeInsets.only(left: 20),
        actions: [
          // 알림 목록으로 이동하는 아이콘 버튼 추가
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
            icon: const Icon(Icons.list, color: Colors.black),
            onPressed: () {
              // 알림 날짜별 조회 페이지로 이동
              Navigator.of(context).push(
                _route(AlarmAllPage(petData: petData)),
              );
            },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '반려동물: ${petData['pet_name'] ?? '알 수 없음'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'LGSmartUI',
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '알림 시간: $alertTime',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'LGSmartUI',
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle(emoji: '🚨', label: '행동 단계'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _AlertStep(
                          emoji: '☀️', 
                          label: '0단계: 정상',
                          isActive: stage == 0,
                        ),
                        _AlertStep(
                          emoji: '⛅', 
                          label: '1단계: 관찰',
                          isActive: stage == 1,
                        ),
                        _AlertStep(
                          emoji: '☁️', 
                          label: '2단계: 주의',
                          isActive: stage == 2,
                        ),
                        _AlertStep(
                          emoji: '⛈️', 
                          label: '3단계: 위험',
                          isActive: stage == 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle(emoji: '🐾', label: '이상행동 리포트'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        displayDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'LGSmartUI',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle(emoji: '🛡️', label: '대처방법'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        displayActionPlan,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'LGSmartUI',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 비디오 버튼을 항상 표시 (비디오가 없어도 표시)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.videocam),
                      label: const Text('이상행동 영상 보기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0F5EF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        // 비디오가 있거나 심각도가 1 이상인 경우 비디오 페이지로 이동
                        if ((videoName != null && videoName!.isNotEmpty) || stage >= 1) {
                          // 비디오 이름이 없으면 기본 이름 생성
                          final effectiveVideoName = (videoName != null && videoName!.isNotEmpty) 
                              ? videoName! 
                              : 'event_${eventId}_stage_${stage}.mp4';
                              
                          Navigator.of(context).push(
                            _route(AlarmVideoPage(
                              eventId: eventId,
                              videoName: effectiveVideoName,
                              petId: petData['id'] ?? 0,
                              stage: stage,
                            )),
                          );
                        } else {
                          // 화면 하단 여백 + 원하는 띄움 거리(예: 72)만큼 위로 올림
                          final bottomGap = MediaQuery.of(context).padding.bottom + 64;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '이 알림에 대한 영상이 없습니다',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB(16, 0, 16, bottomGap), // ⭐ 위치 조정
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertStep extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isActive;

  const _AlertStep({
    super.key, 
    required this.emoji, 
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x30B8E5E0) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive 
            ? Border.all(color: const Color(0xFFB8E5E0), width: 2)
            : null,
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              fontFamily: 'LGSmartUI',
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String emoji;
  final String label;

  const _SectionTitle({super.key, required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'LGSmartUI',
          ),
        ),
      ],
    );
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
