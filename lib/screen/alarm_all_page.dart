import 'package:flutter/material.dart';
import 'alarm_detail_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/api_endpoints.dart';
import 'dart:async';

class AlarmAllPage extends StatefulWidget {
  final Map<String, dynamic> petData;
  
  const AlarmAllPage({
    Key? key,
    required this.petData,
  }) : super(key: key);

  @override
  State<AlarmAllPage> createState() => _AlarmAllPageState();
}

class _AlarmAllPageState extends State<AlarmAllPage> {
  final DateTime _today = DateTime.now();
  late DateTime _selectedDate;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;

  String _loadingText = '알림 조회 중.';
  Timer? _loadingTimer;

  void _startLoadingAnimation() {
    _loadingText = '알림 조회 중.';
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() {
        _loadingText = _loadingText.endsWith('...')
            ? '알림 조회 중.'
            : '$_loadingText.';
      });
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    _loadingText = '알림 조회 중.';
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    _selectedDate = _today;
    // 현재 날짜로 초기 데이터 로드
    _loadEventsForDate(_selectedDate);
  }
  
  // 날짜별 이벤트 로드
  Future<void> _loadEventsForDate(DateTime date) async {
    if (!mounted) return;

    _startLoadingAnimation();
    setState(() => _isLoading = true);
    
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final petId = widget.petData['id'] ?? 0;
      
      if (petId <= 0) {
        debugPrint('⚠️ 올바른 반려동물 ID가 없습니다');
        setState(() {
          _events = [];
          _isLoading = false;
        });
        return;
      }
      
      // 서버에 날짜 파라미터 추가
      final response = await http.get(
        Uri.parse('${ApiEndpoints.getEvents}?pet_id=$petId&date=$formattedDate'),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        // UTF-8로 명시적 디코딩하여 한글 인코딩 문제 해결
        final String decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        List<dynamic> eventsData = json.decode(decodedBody);
        debugPrint('📋 서버에서 받은 이벤트: ${eventsData.length}개');
        
        // 서버에서 필터링된 데이터를 그대로 사용
        setState(() {
          _events = List<Map<String, dynamic>>.from(eventsData);
          _isLoading = false;
        });
        
        debugPrint('📅 $formattedDate 날짜에 해당하는 이벤트: ${_events.length}개');
      } else {
        debugPrint('❌ 서버 응답 오류: ${response.statusCode}');
        setState(() {
          _events = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 이벤트 로드 중 오류: $e');
      if (mounted) {
        setState(() {
          _events = [];
          _isLoading = false;
        });
      }
    } finally {
      _stopLoadingAnimation();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '날짜별 알림 조회',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          // 날짜 선택 영역
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 왼쪽 달력 아이콘
                IconButton(
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.calendar_today, color: Colors.black),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020, 1, 1),
                      lastDate: DateTime(2100, 12, 31),
                      currentDate: _today,
                      selectableDayPredicate: (DateTime day) {
                        return !day.isAfter(_today);
                      },
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.blue,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                            textTheme: const TextTheme(
                              bodyMedium: TextStyle(fontFamily: 'LGSmartUI'),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    
                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                      });
                      // 날짜 선택 후 바로 해당 날짜의 데이터 로드
                      _loadEventsForDate(picked);
                    }
                  },
                ),
                
                // 선택된 날짜 표시
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      DateFormat('yyyy년 MM월 dd일').format(_selectedDate),
                      style: const TextStyle(
                        fontFamily: 'LGSmartUI',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                // 조회 버튼
                ElevatedButton(
                  onPressed: () {
                    _loadEventsForDate(_selectedDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F5EF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '조회',
                    style: TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 구분선
          const Divider(height: 1),
          
          // 이벤트 목록
          Expanded(
            child: _isLoading                     // ← 로딩 중일 때
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [                             // ✅ const 지움
                  const CircularProgressIndicator(),    // ← 상수 위젯은 그대로 const 유지
                  const SizedBox(height: 20),
                  Text(                                 // ✅ const 지움
                    _loadingText,                       //   애니메이션되는 변수
                    style: const TextStyle(             //   TextStyle 은 여전히 const 가능
                      fontFamily: 'LGSmartUI',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )

            // 로딩이 끝났는데 이벤트가 없을 때
                : _events.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_off,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${DateFormat('yyyy년 MM월 dd일').format(_selectedDate)}\n해당 날짜에 알림이 없습니다',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )

            // 이벤트가 있을 때
                : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          
                          // 인코딩 문제 해결을 위한 처리
                          String summary = event['summary'] ?? '알림 내용이 없습니다';
                          try {
                            final List<int> bytes = utf8.encode(summary);
                            summary = utf8.decode(bytes, allowMalformed: true);
                          } catch (e) {
                            debugPrint('⚠️ summary 인코딩 수정 중 오류: $e');
                          }
                          
                          final String createdAt = event['created_at'] ?? '';
                          final int stage = event['stage'] ?? 0;
                          
                          // 비디오 정보 추출
                          final String? videoName = event['video_name'];
                          final int eventId = event['id'] ?? 0;
                          
                          // 심각도 1 이상이면 영상이 있다고 간주 (비디오 이름이 없어도)
                          final bool hasVideo = stage >= 1 || (videoName != null && videoName.toString().isNotEmpty);
                          
                          // 시간 형식화
                          String formattedTime = '';
                          if (createdAt.isNotEmpty) {
                            try {
                              // T 제거
                              final cleanTime = createdAt.replaceAll('T', ' ');
                              final dateTime = DateTime.parse(cleanTime);
                              formattedTime = DateFormat('HH:mm').format(dateTime);
                            } catch (e) {
                              formattedTime = createdAt.replaceAll('T', ' ');
                            }
                          }
                          
                          return Column(
                            children: [
                              _buildEventTile(
                                context,
                                summary,
                                formattedTime,
                                event,
                                stage,
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // 이벤트 항목 위젯
  Widget _buildEventTile(
    BuildContext context,
    String message,
    String time,
    Map<String, dynamic> event,
    int stage,
  ) {
    // 단계에 따른 배경색 설정
    final Color backgroundColor = _getStageColor(stage);
    
    // 단계에 따른 아이콘 설정
    final IconData icon = _getStageIcon(stage);
    
    // 인코딩 문제가 있는 경우 수정
    String safeMessage = message;
    try {
      if (message.isNotEmpty) {
        final List<int> bytes = utf8.encode(message);
        safeMessage = utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e) {
      debugPrint('⚠️ 메시지 인코딩 수정 중 오류: $e');
    }
    
    // 메시지 요약 - "1. " 이후의 내용만 표시
    if (safeMessage.contains("1. ")) {
      safeMessage = safeMessage.substring(safeMessage.indexOf("1. "));
    } else if (safeMessage.isEmpty) {
      safeMessage = '반려동물의 이상행동이 감지되었습니다.';
    }
    
    return GestureDetector(
      onTap: () {
        // 알림 상세 페이지로 이동
        Navigator.push(
          context,
          _route(
            AlarmDetailPageApp(
              petData: widget.petData,
              alertMessage: event['summary'] ?? safeMessage,
              alertTime: event['created_at'] ?? time,
              actionPlan: '',  // 여기에 대처 방법 정보 추가 필요
              stage: stage,
              behaviorDescription: event['summary'] ?? '',
              eventId: event['id'] ?? 0,  // 이벤트 ID 전달
              videoName: event['video_name'],  // 비디오 파일명 전달
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
                          safeMessage,
                          style: const TextStyle(
                            fontFamily: 'LGSmartUI',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // 심각도 1 이상이거나 비디오가 있는 경우 비디오 아이콘 표시
                      if (stage >= 1 || (event['video_name'] != null && event['video_name'].toString().isNotEmpty))
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
              time,
              style: const TextStyle(
                fontFamily: 'LGSmartUI',
                fontSize: 8,
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
}

// 페이지 전환 애니메이션
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