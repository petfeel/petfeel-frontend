// lib/screen/settings_page.dart
import 'package:flutter/material.dart';
import 'package:test123/screen/alarm_setting_page.dart';
import 'package:test123/screen/login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const double horizontalPadding = 16.0;
    const double sectionTitlePaddingTop = 12.0;
    const double sectionTitlePaddingBottom = 4.0;

    const TextStyle sectionTitleStyle = TextStyle(
      fontFamily: 'LGSmartUI',
      fontSize: 13,
      color: Colors.grey,
      fontWeight: FontWeight.w400,
    );

    const TextStyle itemTitleStyle = TextStyle(
      fontFamily: 'LGSmartUI',
      fontSize: 16,
      color: Colors.black,
      fontWeight: FontWeight.w600,
    );

    const TextStyle itemSubtitleStyle = TextStyle(
      fontFamily: 'LGSmartUI',
      fontSize: 14,
      color: Colors.grey,
      fontWeight: FontWeight.w400,
    );

    const TextStyle accentSubtitleStyle = TextStyle(
      fontFamily: 'LGSmartUI',
      fontSize: 14,
      color: Color(0xFF6E5CC6),
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,           // 다른 페이지와 동일하게 0.5로 설정
        centerTitle: true,        // 타이틀 중앙 정렬
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          '설정',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 22,         // 다른 페이지와 동일한 크기
            color: Colors.black,
            fontWeight: FontWeight.w600, // 다른 페이지와 동일한 두께
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                sectionTitlePaddingTop,
                horizontalPadding,
                sectionTitlePaddingBottom,
              ),
              child: Text('연결', style: sectionTitleStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  title: const Text('네트워크', style: itemTitleStyle),
                  subtitle: const Text(
                    '제품에 연결할 Wi-Fi를 설정할 수 있어요.',
                    style: itemSubtitleStyle,
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // 네트워크 설정 화면으로 이동
                  },
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                sectionTitlePaddingTop,
                horizontalPadding,
                sectionTitlePaddingBottom,
              ),
              child: Text('알림', style: sectionTitleStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  title: const Text('알림 설정', style: itemTitleStyle),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                        const AlarmSetting(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;

                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));
                          var fadeTween = Tween<double>(begin: 0.0, end: 1.0)
                              .chain(CurveTween(curve: curve));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: FadeTransition(
                              opacity: animation.drive(fadeTween),
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                  },
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                sectionTitlePaddingTop,
                horizontalPadding,
                sectionTitlePaddingBottom,
              ),
              child: Text('홈', style: sectionTitleStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      title: const Text('홈 설정', style: itemTitleStyle),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {},
                    ),
                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      title: const Text('화면 테마', style: itemTitleStyle),
                      subtitle: const Text('시스템 기본 설정', style: accentSubtitleStyle),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                sectionTitlePaddingTop,
                horizontalPadding,
                sectionTitlePaddingBottom,
              ),
              child: Text('제품 로그인', style: sectionTitleStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  title: const Text('ThinQ 계정 공유', style: itemTitleStyle),
                  subtitle: const Text(
                    'LG ThinQ 앱 로그인을 지원하는 제품에 표시된 QR 코드를\n'
                        '스캔하거나 숫자 코드를 입력해 다른 계정이 공유하도록.',
                    style: itemSubtitleStyle,
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {},
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                sectionTitlePaddingTop,
                horizontalPadding,
                sectionTitlePaddingBottom,
              ),
              child: Text('일반', style: sectionTitleStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      title: const Text('언어', style: itemTitleStyle),
                      subtitle: const Text('한국어', style: itemSubtitleStyle),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {},
                    ),
                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      title: const Text('약관 및 정책', style: itemTitleStyle),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {},
                    ),
                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      title: const Text('LG PetFeel 정보', style: itemTitleStyle),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  onPressed: () {
                    _showLogoutConfirmation(context);
                  },
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            '로그아웃',
            style: TextStyle(
              fontFamily: 'LGSmartUI',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            '정말로 로그아웃 하시겠습니까?',
            style: TextStyle(
              fontFamily: 'LGSmartUI',
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  fontFamily: 'LGSmartUI',
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _navigateToLogin(context);
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  fontFamily: 'LGSmartUI',
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Login2(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          final fadeAnim = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(opacity: fadeAnim, child: child);
        },
      ),
          (route) => false,
    );
  }
}
