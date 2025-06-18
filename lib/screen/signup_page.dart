// lib/screen/join2.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart'; // 로그인 페이지 import

// ★ ApiEndpoints를 import
import 'package:test123/utils/api_endpoints.dart';

class Join2 extends StatefulWidget {
  const Join2({super.key});

  @override
  State<Join2> createState() => _Join2State();
}

class _Join2State extends State<Join2> {
  final TextEditingController _nameController             = TextEditingController();
  final TextEditingController _emailController            = TextEditingController();
  final TextEditingController _passwordController         = TextEditingController();
  final TextEditingController _confirmPasswordController  = TextEditingController();

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontFamily: 'LGSmartUI'),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToLoginPage() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => Login2(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          final fade   = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
          final slide  = Tween<Offset>(begin: const Offset(0.0, -0.1), end: Offset.zero).animate(curved);
          return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
        },
      ),
    );
  }

  Future<void> _signup() async {
    final name             = _nameController.text.trim();
    final email            = _emailController.text.trim();
    final password         = _passwordController.text.trim();
    final confirmPassword  = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('모든 항목을 입력해주세요.');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('올바른 이메일 형식을 입력해주세요.');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('비밀번호가 일치하지 않습니다.');
      return;
    }

    // ★ ApiEndpoints.signup 상수를 사용
    final url     = Uri.parse(ApiEndpoints.signup);
    final headers = {'Content-Type': 'application/json'};
    final body    = jsonEncode({'username': name, 'email': email, 'password': password});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 201) {
        _showSnackBar('회원가입 성공', success: true);
        await Future.delayed(const Duration(milliseconds: 1200));
        _navigateToLoginPage();
      } else {
        String errorMessage = '회원가입에 실패했습니다.';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map && decoded['detail'] is String) {
            errorMessage = decoded['detail'];
          }
        } catch (_) {}
        _showSnackBar(errorMessage);
      }
    } catch (e) {
      _showSnackBar('에러 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(
            color: Colors.black,
            fontSize: 25,
            fontFamily: 'LGSmartUI',
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      _buildInputField(
                        '이름',
                        '이름을 입력하세요',
                        _nameController,
                      ),
                      _buildInputField(
                        '이메일',
                        '이메일을 입력하세요',
                        _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _buildInputField(
                        '비밀번호',
                        '비밀번호를 입력하세요',
                        _passwordController,
                        obscureText: true,
                      ),
                      _buildInputField(
                        '비밀번호 확인',
                        '비밀번호를 입력하세요',
                        _confirmPasswordController,
                        obscureText: true,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9E003A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _signup,
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'LGSmartUI',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
      String label,
      String hint,
      TextEditingController controller, {
        bool obscureText = false,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF767676),
              fontSize: 14,
              fontFamily: 'LGSmartUI',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0x7F7C6F67),
                fontFamily: 'LGSmartUI',
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.black.withAlpha(26), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.black.withAlpha(26), width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
