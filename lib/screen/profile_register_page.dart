// lib/screen/profile_register_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// HomeConnected 및 ProfileListOnPage import
import 'profile_liston_page.dart';

// ★ ApiEndpoints를 import
import 'package:test123/utils/api_endpoints.dart';

class ProfileRegisterPage extends StatefulWidget {
  const ProfileRegisterPage({Key? key}) : super(key: key);

  @override
  State<ProfileRegisterPage> createState() => _ProfileRegisterPageState();
}

class _ProfileRegisterPageState extends State<ProfileRegisterPage> {
  File? _image;
  final picker = ImagePicker();

  final TextEditingController _nameController   = TextEditingController();
  final TextEditingController _breedController  = TextEditingController();
  final TextEditingController _birthController  = TextEditingController();
  final TextEditingController _ageController    = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String _gender = '남아';

  @override
  void initState() {
    super.initState();
    _birthController.addListener(() {
      final raw = _birthController.text.replaceAll('/', '');
      String formatted = '';
      if (raw.length >= 4) {
        formatted = raw.substring(0, 4);
        if (raw.length >= 6) {
          formatted += '/' + raw.substring(4, 6);
          if (raw.length >= 8) {
            formatted += '/' + raw.substring(6, 8);
          } else if (raw.length > 6) {
            formatted += '/' + raw.substring(6);
          }
        } else if (raw.length > 4) {
          formatted += '/' + raw.substring(4);
        }
      } else {
        formatted = raw;
      }

      _birthController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );

      _calculateAge();
    });
  }

  void _calculateAge() {
    try {
      final birthText = _birthController.text;
      if (birthText.length != 10) return;

      final birthDate = DateFormat('yyyy/MM/dd').parseStrict(birthText);
      final today     = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      setState(() {
        _ageController.text = age.toString();
      });
    } catch (e) {
      _ageController.text = '';
    }
  }

  void _showSnackBar(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPetProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (token.isEmpty) {
      _showSnackBar('로그인이 필요합니다.', success: false);
      return;
    }

    if (_nameController.text.isEmpty) {
      _showSnackBar('이름을 입력해주세요.', success: false);
      return;
    }
    if (_breedController.text.isEmpty) {
      _showSnackBar('종을 입력해주세요.', success: false);
      return;
    }
    if (_birthController.text.isEmpty || _birthController.text.length != 10) {
      _showSnackBar('생년월일을 정확히 입력해주세요.', success: false);
      return;
    }
    if (_ageController.text.isEmpty) {
      _showSnackBar('나이를 입력해주세요.', success: false);
      return;
    }
    if (_weightController.text.isEmpty) {
      _showSnackBar('몸무게를 입력해주세요.', success: false);
      return;
    }

    // ★ ApiEndpoints.base를 사용해 POST URL 구성
    final uri = Uri.parse('${ApiEndpoints.base}/pets/');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['pet_name']    = _nameController.text
      ..fields['pet_species'] = _breedController.text
      ..fields['age']         = _ageController.text
      ..fields['birth_date']  = _birthController.text.replaceAll('/', '-')
      ..fields['gender']      = _gender == '남아' ? 'male' : 'female'
      ..fields['weight']      = _weightController.text;

    if (_image != null) {
      request.files.add(await http.MultipartFile.fromPath('pet_photo', _image!.path));
    }

    try {
      final response     = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        _showSnackBar('등록 성공');
        await Future.delayed(const Duration(milliseconds: 700));
        // 등록 후 ProfileListOnPage로 대체(pushReplacement)
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => const ProfileListOnPage(),
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
        _showSnackBar('등록 실패: ${response.statusCode}\n$responseBody', success: false);
      }
    } catch (e) {
      _showSnackBar('에러 발생: $e', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '프로필 등록',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: _image != null
                    ? ClipOval(
                  child: Image.file(
                    _image!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/images/paw_placeholder.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _pickImage,
              child: const Text('사진 업로드'),
            ),
            const SizedBox(height: 16),
            _buildTextField('이름을 입력하세요', _nameController),
            _buildTextField('종을 입력하세요', _breedController),
            _buildTextField(
              'YYYY/MM/DD',
              _birthController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            _buildTextFieldWithSuffix(
              hint: '나이를 입력하세요',
              controller: _ageController,
              suffix: '세',
            ),
            _buildTextFieldWithSuffix(
              hint: '몸무게를 입력하세요',
              controller: _weightController,
              suffix: 'kg',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            const SizedBox(height: 16),
            _buildGenderSelection(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _submitPetProfile,
                child: const Text(
                  '저장',
                  style: TextStyle(
                    fontFamily: 'LGSmartUI',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      String hint,
      TextEditingController controller, {
        List<TextInputFormatter>? inputFormatters,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: (controller == _ageController || controller == _weightController)
            ? TextInputType.number
            : TextInputType.text,
        textInputAction: TextInputAction.next,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTextFieldWithSuffix({
    required String hint,
    required TextEditingController controller,
    required String suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          suffixText: suffix,
          suffixStyle: const TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Row(
      children: [
        const Text('성별'),
        const SizedBox(width: 20),
        Expanded(
          child: Row(
            children: [
              Radio<String>(
                value: '남아',
                groupValue: _gender,
                onChanged: (value) {
                  setState(() {
                    _gender = value!;
                  });
                },
              ),
              const Text('남아'),
              Radio<String>(
                value: '여아',
                groupValue: _gender,
                onChanged: (value) {
                  setState(() {
                    _gender = value!;
                  });
                },
              ),
              const Text('여아'),
            ],
          ),
        ),
      ],
    );
  }
}
