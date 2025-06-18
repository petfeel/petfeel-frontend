// lib/screen/profile_liston_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// HomeConnected를 사용하기 위해 반드시 import가 필요합니다.
import 'package:test123/screen/home_connected_page.dart';
import 'package:test123/screen/profile_register_page.dart';

// ★ ApiEndpoints를 import
import 'package:test123/utils/api_endpoints.dart';

class ProfileListOnPage extends StatefulWidget {
  const ProfileListOnPage({Key? key}) : super(key: key);

  @override
  State<ProfileListOnPage> createState() => _ProfileListOnPageState();
}

class _ProfileListOnPageState extends State<ProfileListOnPage> {
  List<dynamic> pets = [];
  bool isLoading = true;
  Timer? _refreshTimer;
  String? token;

  @override
  void initState() {
    super.initState();
    _getToken().then((_) => _loadPets());
    
    // 주기적으로 펫 목록 갱신 (60초마다)
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _loadPets();
      }
    });
  }

  // 토큰 가져오기
  Future<void> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('access_token') ?? '';
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPets() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getPets),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> loadedPets = json.decode(utf8.decode(response.bodyBytes));
        
        if (mounted) {
          setState(() {
            pets = loadedPets;
            isLoading = false;
          });
          
          // 사용자의 펫 ID 목록 저장 (알림 필터링용)
          _saveUserPetIds(loadedPets);
        }
      } else {
        if (mounted) {
          setState(() {
            pets = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          pets = [];
          isLoading = false;
        });
      }
    }
  }
  
  // 사용자의 펫 ID 목록 저장 함수
  Future<void> _saveUserPetIds(List<dynamic> petList) async {
    try {
      final List<String> petIds = petList
          .map((pet) => (pet['id'] ?? 0).toString())
          .where((id) => id != '0')
          .toList();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_pet_ids', petIds);
      
      debugPrint('✅ 사용자 반려동물 ID 목록 저장됨: $petIds');
    } catch (e) {
      debugPrint('⚠️ 반려동물 ID 목록 저장 중 오류: $e');
    }
  }

  /* ───────────────── 유틸 ───────────────── */
  String _calculateAge(String birthDate) {
    try {
      final birth = DateTime.parse(birthDate);
      final now = DateTime.now();
      final age = now.year -
          birth.year -
          ((now.month < birth.month ||
              (now.month == birth.month && now.day < birth.day))
              ? 1
              : 0);
      return '$age세';
    } catch (_) {
      return '';
    }
  }

  /* ───────────────── UI ───────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '나의 반려동물',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: pets.isEmpty
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: 0.1,
                    child: Image.asset(
                      'assets/images/paw_placeholder.png',
                      width: 180,
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '등록된 반려동물이 없습니다.',
                    style: TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 15,
                      color: Color(0xFF7D7D7D),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: pets.length,
                itemBuilder: (context, index) {
                  final pet = pets[index];
                  // ★ ApiEndpoints.base와 image_path를 결합하여 imageUrl 생성
                  final imageUrl = pet['image_path'] != null
                      ? '${ApiEndpoints.base}${pet['image_path']}'
                      : 'assets/images/paw_placeholder.png';
                  final gender = pet['gender'] == 'male' ? '♂' : '♀';
                  final genderColor =
                  pet['gender'] == 'male' ? Colors.blue : Colors.pink;

                  return GestureDetector(
                    onTap: () async {
                      // 전체 pets 리스트와 현재 인덱스를 HomeConnected에 넘깁니다.
                      final result = await Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration:
                          const Duration(milliseconds: 600),
                          pageBuilder: (_, __, ___) => HomeConnected(
                            pets: pets,
                            initialIndex: index,
                          ),
                          transitionsBuilder:
                              (_, animation, __, child) {
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            );
                            final fade = Tween<double>(
                              begin: 0.0,
                              end: 1.0,
                            ).animate(curved);
                            final scale = Tween<double>(
                              begin: 0.9,
                              end: 1.0,
                            ).animate(curved);
                            final slide = Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(curved);

                            return FadeTransition(
                              opacity: fade,
                              child: ScaleTransition(
                                scale: scale,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              ),
                            );
                          },
                        ),
                      );

                      /* ――― HomeConnected에서 pop된 결과가 오면 목록을 새로고침 ――― */
                      if (result is Map<String, dynamic>) {
                        // 편집 혹은 삭제 후 목록 갱신
                        await _loadPets();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: imageUrl.startsWith('http')
                                ? Image.network(
                              imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            )
                                : Image.asset(
                              imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      pet['pet_name'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'LGSmartUI',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      gender,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: genderColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '종 : ${pet['pet_species'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'LGSmartUI',
                                  ),
                                ),
                                Text(
                                  '생년월일 : ${(pet['birth_date'] ?? '').toString().split('T').first.replaceAll('-', '/')} '
                                      '(${_calculateAge(pet['birth_date'])})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'LGSmartUI',
                                  ),
                                ),
                                Text(
                                  '몸무게 : ${pet['weight']} kg',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'LGSmartUI',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            /* ─── 프로필 추가 버튼 ─── */
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                      PageRouteBuilder(
                        transitionDuration:
                        const Duration(milliseconds: 600),
                        pageBuilder: (_, __, ___) =>
                        const ProfileRegisterPage(),
                        transitionsBuilder: (_, animation, __, child) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          );
                          final fade = Tween<double>(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(curved);
                          final scale = Tween<double>(
                            begin: 0.9,
                            end: 1.0,
                          ).animate(curved);
                          final slide = Tween<Offset>(
                            begin: const Offset(0.0, 0.1),
                            end: Offset.zero,
                          ).animate(curved);

                          return FadeTransition(
                            opacity: fade,
                            child: ScaleTransition(
                              scale: scale,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                        .then((_) => _loadPets());
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    '프로필 추가',
                    style: TextStyle(fontFamily: 'LGSmartUI'),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
