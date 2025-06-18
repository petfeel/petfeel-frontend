// lib/screen/login2.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ★ ApiEndpoints 클래스를 import
import 'package:test123/utils/api_endpoints.dart';

import 'package:test123/screen/thinq_page.dart';
import 'camera_connect_page.dart';
import 'signup_page.dart';

class Login2 extends StatefulWidget {
  const Login2({super.key});

  @override
  State<Login2> createState() => _Login2State();
}

class _Login2State extends State<Login2> {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login(BuildContext context) async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요')),
      );
      return;
    }

    // 하드코딩 대신 ApiEndpoints.login 상수를 사용
    final url     = Uri.parse(ApiEndpoints.login);
    final headers = {'Content-Type': 'application/json'};
    final body    = jsonEncode({'email': email, 'password': password});

    try {
      final response = await http.post(url, headers: headers, body: body);
      final decoded  = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(decoded);
        final token = data['access_token'] ?? '';
        final userName = data['username'] ?? '';

        // SharedPreferences에 토큰과 username 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        await prefs.setString('username', userName);

        // 로그인 성공 스낵바
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('로그인 성공', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(milliseconds: 700),
          ),
        );

        // 짧게 대기 후 ThinqPage로 이동
        await Future.delayed(const Duration(milliseconds: 700));

        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) => const ThinqPage(),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
              final fade   = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
              final slide  = Tween<Offset>(begin: const Offset(0.2, 0.0), end: Offset.zero)
                  .animate(curved);
              return FadeTransition(
                opacity: fade,
                child: SlideTransition(position: slide, child: child),
              );
            },
          ),
        );
      } else {
        String errorMessage = '로그인에 실패했습니다. 이메일 또는 비밀번호를 확인해주세요.';
        try {
          final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (decodedBody is Map && decodedBody['detail'] is String) {
            errorMessage = decodedBody['detail'];
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('에러 발생: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'LGSmartUI',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 80),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/img.png',
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 50),
                const Text(
                  '이메일 아이디',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF767676),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'LGSmartUI',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: '이메일을 입력하세요',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 14,
                      fontFamily: 'LGSmartUI',
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '비밀번호',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF767676),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'LGSmartUI',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '비밀번호를 입력하세요',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 14,
                      fontFamily: 'LGSmartUI',
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9E003A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _login(context),
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'LGSmartUI',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    children: [
                      const Text(
                        '아이디 찾기',
                        style: TextStyle(
                          color: Color(0xFF979797),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'LGSmartUI',
                        ),
                      ),
                      const Text(
                        '비밀번호 재설정',
                        style: TextStyle(
                          color: Color(0xFF979797),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'LGSmartUI',
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 500),
                              pageBuilder: (_, __, ___) => const Join2(),
                              transitionsBuilder: (_, animation, __, child) {
                                final fade = Tween<double>(begin: 0.0, end: 1.0)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
                                final slide = Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
                                return FadeTransition(
                                  opacity: fade,
                                  child: SlideTransition(position: slide, child: child),
                                );
                              },
                            ),
                          );
                        },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'LGSmartUI',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF9E003A), width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'LG 계정으로 로그인',
                      style: TextStyle(
                        color: Color(0xFF9E003A),
                        fontSize: 16,
                        fontFamily: 'LGSmartUI',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
