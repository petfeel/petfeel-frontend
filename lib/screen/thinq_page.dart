import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test123/screen/start2_page.dart'; // StartPage2 경로 확인 후 수정하세요.

class ThinqPage extends StatefulWidget {
  const ThinqPage({super.key});

  @override
  State<ThinqPage> createState() => _ThinqPageState();
}

class _ThinqPageState extends State<ThinqPage> {
  int _selectedIndex = 0;
  String _username = '로딩 중…';

  static const List<BottomNavigationBarItem> _bottomItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      label: '홈',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.devices_outlined),
      label: '디바이스',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.insert_chart_outlined),
      label: '리포트',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.pets_outlined),
      label: 'PetFeel',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.menu),
      label: '메뉴',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('username') ?? '알수없음';
    print('🟡 불러온 username: $savedName');
    setState(() {
      _username = savedName;
    });
  }

  void _onBottomNavTapped(int index) {
    if (index == 3) {
      // PetFeel 탭 클릭 시 StartPage2로 이동 (Fade + Scale 애니메이션)
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
          const StartPage2(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );
            final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
        // TODO: 다른 인덱스(홈, 디바이스, 리포트, 메뉴) 눌렀을 때 페이지 전환 로직 추가
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFE8F0FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────── 상단 헤더 ───────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 왼쪽: "<username> 홈" + 드롭다운 화살표
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _username,
                                style: TextStyle(
                                  fontFamily: 'LGSmartUI',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              TextSpan(
                                text: ' 홈',
                                style: const TextStyle(
                                  fontFamily: 'LGSmartUI',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 28,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                    // 오른쪽: +, 알림, 더보기 아이콘
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.black87),
                          onPressed: () {
                            // TODO: "+" 버튼 동작
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.notifications_none, color: Colors.black87),
                          onPressed: () {
                            // TODO: 알림 버튼 동작
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.black87),
                          onPressed: () {
                            // TODO: 더보기 버튼 동작
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─────────── 카드1: 홈 위치 설정 안내 ───────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    children: [
                      Icon(
                        Icons.home,
                        size: 48,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '홈 위치를 설정하면 맞춤 정보와 기능을 사용할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                          fontFamily: null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 120,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: 설정하기 버튼 동작
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.blue.shade600,
                            elevation: 0,
                          ),
                          child: const Text(
                            '설정하기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─────────── 카드2: 3D 홈뷰 안내 ───────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 좌측 3D 아이콘
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.threed_rotation,
                          size: 28,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 우측: 텍스트 + 버튼
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '3D 홈뷰로 우리집과 제품의 실시간 상태를 한눈에 확인해보세요.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                                fontFamily: null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 32,
                              child: OutlinedButton(
                                onPressed: () {
                                  // TODO: 3D 홈뷰 만들기 버튼 동작
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.blue.shade600),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: Text(
                                  '3D 홈뷰 만들기',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade600,
                                    fontFamily: null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─────────── "즐겨 찾는 제품" 섹션 ───────────
                Row(
                  children: const [
                    Text(
                      '즐겨 찾는 제품',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        fontFamily: null,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 제품 카드 예시 (에어컨)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // 제품 아이콘 (에어컨)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.ac_unit,
                          size: 24,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 온도 텍스트 + 라벨
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '실내 온도 23°C',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                                fontFamily: null,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '에어컨',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: Colors.black54,
                                fontFamily: null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 전원 버튼 아이콘
                      IconButton(
                        icon: const Icon(
                          Icons.power_settings_new,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          // TODO: 에어컨 On/Off 로직
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─────────── ThinQ PLAY 배너 ───────────
                Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6D6D), Color(0xFFFFA66D)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.play_circle_fill,
                        size: 32,
                        color: Colors.white,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '앱을 다운로드하여 제품과 공간을 업그레이드해보세요.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            fontFamily: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─────────── "스마트 루틴" 섹션 ───────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      '스마트 루틴',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        fontFamily: null,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.black54,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 루틴 알아보기 카드
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.schedule,
                        size: 24,
                        color: Colors.orangeAccent,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '루틴 알아보기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87,
                            fontFamily: null,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ─────────── 화면 편집 버튼 ───────────
                Center(
                  child: SizedBox(
                    width: 140,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: 화면 편집 버튼 동작
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        side: BorderSide(color: Colors.blue.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '화면 편집',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade600,
                          fontFamily: null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: FAB 동작
        },
        backgroundColor: Colors.pinkAccent,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        items: _bottomItems,
      ),
    );
  }
}
