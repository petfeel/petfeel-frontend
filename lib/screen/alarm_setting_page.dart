import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/notification_service.dart';

class AlarmSetting extends StatefulWidget {
  const AlarmSetting({super.key});

  @override
  State<AlarmSetting> createState() => _AlarmSettingState();
}

class _AlarmSettingState extends State<AlarmSetting> {
  bool toggleMain = true;
  bool toggle0 = true;
  bool toggle1 = true;
  bool toggle2 = true;
  bool toggle3 = true;
  bool toggleSchedule = true;
  bool toggleMarketing = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadToggles();
  }

  Future<void> _loadToggles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      toggleMain = prefs.getBool('toggleMain') ?? true;
      toggle0 = prefs.getBool('toggle0') ?? true;
      toggle1 = prefs.getBool('toggle1') ?? true;
      toggle2 = prefs.getBool('toggle2') ?? true;
      toggle3 = prefs.getBool('toggle3') ?? true;
      toggleSchedule = prefs.getBool('toggleSchedule') ?? true;
      toggleMarketing = prefs.getBool('toggleMarketing') ?? true;
    });
  }

  Future<void> _saveToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // 알림 서비스 설정 업데이트 - 메인 알림 설정이 변경되면 서비스 상태 변경
    if (key == 'toggleMain') {
      if (value) {
        _notificationService.startListening();
      } else {
        _notificationService.stopListening();
      }
    }

    // 설정 변경 시 알림 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_getToggleName(key)} 알림이 ${value ? '켜졌습니다.' : '꺼졌습니다.'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: value ? Colors.green : Colors.red,   // ON/OFF 색상 구분
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  // 토글 이름 반환
  String _getToggleName(String key) {
    switch (key) {
      case 'toggleMain':
        return '이상행동 감지';
      case 'toggle0':
        return '0단계';
      case 'toggle1':
        return '1단계';
      case 'toggle2':
        return '2단계';
      case 'toggle3':
        return '3단계';
      case 'toggleSchedule':
        return '일정';
      case 'toggleMarketing':
        return '마케팅';
      default:
        return '';
    }
  }

  Widget _buildToggleTile(
      String title,
      String subtitle,
      bool value,
      String key,
      void Function(bool) onChanged,
      ) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
        _saveToggle(key, !value);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.only(left: 24, right: 16, top: 12, bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'LGSmartUI',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (val) {
                onChanged(val);
                _saveToggle(key, val);
              },
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF007AFF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          final dashWidth = 4.0;
          final dashSpace = 2.0;
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xFFB1B1B1)),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,              // 다른 페이지와 동일하게 0.5로 설정
        centerTitle: true,           // 타이틀 중앙 정렬
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림 설정',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 22,            // 다른 페이지와 동일한 크기
            color: Colors.black,
            fontWeight: FontWeight.w600, // 다른 페이지와 동일한 두께
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Text(
                '이상행동 감지 알림',
                style: TextStyle(
                  fontFamily: 'LGSmartUI',
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildToggleTile(
                    '이상행동 감지 시 알림 수신',
                    '반려동물의 이상행동에 대한 알림을 받아보세요.',
                    toggleMain,
                    'toggleMain',
                        (val) => setState(() => toggleMain = val),
                  ),
                  _buildDashedDivider(),
                  _buildToggleTile('0단계', '', toggle0, 'toggle0',
                          (val) => setState(() => toggle0 = val)),
                  _buildDashedDivider(),
                  _buildToggleTile('1단계', '', toggle1, 'toggle1',
                          (val) => setState(() => toggle1 = val)),
                  _buildDashedDivider(),
                  _buildToggleTile('2단계', '', toggle2, 'toggle2',
                          (val) => setState(() => toggle2 = val)),
                  _buildDashedDivider(),
                  _buildToggleTile('3단계', '', toggle3, 'toggle3',
                          (val) => setState(() => toggle3 = val)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Text(
                '캘린더 일정 알림',
                style: TextStyle(
                  fontFamily: 'LGSmartUI',
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildToggleTile(
                    '일정 알림',
                    '캘린더에 적어둔 일정에 대한 알림을 받아보세요.',
                    toggleSchedule,
                    'toggleSchedule',
                        (val) => setState(() => toggleSchedule = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Text(
                '마케팅 정보 알림',
                style: TextStyle(
                  fontFamily: 'LGSmartUI',
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildToggleTile(
                '마케팅 정보 알림',
                '다양한 혜택과 정보 안내',
                toggleMarketing,
                'toggleMarketing',
                    (val) => setState(() => toggleMarketing = val),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
