// lib/screen/profile_edit_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ★ ApiEndpoints를 import
import 'package:test123/utils/api_endpoints.dart';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> petData;

  const ProfileEditPage({Key? key, required this.petData}) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  File? _image;
  final picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _birthController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  String _gender = '남아';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.petData['pet_name'] ?? '');
    _breedController = TextEditingController(text: widget.petData['pet_species'] ?? '');
    _birthController = TextEditingController(
      text: (widget.petData['birth_date'] ?? '')
          .toString()
          .split('T')
          .first
          .replaceAll('-', '/'),
    );
    _ageController    = TextEditingController(text: widget.petData['age']?.toString() ?? '');
    _weightController = TextEditingController(text: widget.petData['weight']?.toString() ?? '');
    _gender = widget.petData['gender'] == 'male' ? '남아' : '여아';

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
      final today = DateTime.now();
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
        duration: success ? const Duration(milliseconds: 700) : const Duration(seconds: 3),
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

  Future<void> _updateProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final petId = widget.petData['id'].toString();
    // ★ ApiEndpoints.base를 사용하여 PATCH URL 구성
    final uri = Uri.parse('${ApiEndpoints.base}/pets/$petId');

    final request = http.MultipartRequest('PATCH', uri)
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
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(responseBody);

        _showSnackBar('프로필 수정 완료', success: true);
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;

        final updatedPetData = {
          'id':           updatedData['id'],
          'pet_name':     updatedData['pet_name'],
          'pet_species':  updatedData['pet_species'],
          'age':          updatedData['age'],
          'birth_date':   updatedData['birth_date'],
          'gender':       updatedData['gender'],
          'weight':       updatedData['weight'],
          'image_path':   updatedData['image_path'],
        };

        Navigator.of(context).pop(updatedPetData); // ✅ 수정된 데이터 반환
      } else {
        _showSnackBar('수정 실패: ${response.statusCode}\n$responseBody', success: false);
      }
    } catch (e) {
      _showSnackBar('에러 발생: $e', success: false);
    }
  }

  Future<void> _deleteProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final petId = widget.petData['id'].toString();
    // ★ ApiEndpoints.base를 사용하여 DELETE URL 구성
    final uri = Uri.parse('${ApiEndpoints.base}/pets/$petId');

    try {
      final response = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('프로필 삭제 완료', success: true);
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        Navigator.of(context).pop({'deleted': true}); // ✅ 삭제 완료 표시
      } else {
        _showSnackBar('삭제 실패: ${response.statusCode}\n${response.body}', success: false);
      }
    } catch (e) {
      _showSnackBar('에러 발생: $e', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.petData['image_path'] != null
    // ★ ApiEndpoints.base를 사용하여 이미지 URL 구성
        ? '${ApiEndpoints.base}${widget.petData['image_path']}'
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '프로필 수정',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(); // ✅ 뒤로가기: 데이터 반환 없음
          },
        ),
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
                    ? ClipOval(child: Image.file(_image!, fit: BoxFit.cover))
                    : (imageUrl != null
                    ? ClipOval(child: Image.network(imageUrl, fit: BoxFit.cover))
                    : ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/paw_placeholder.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                )),
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
            ),
            _buildGenderSelection(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '수정 완료',
                  style: TextStyle(
                    fontFamily: 'LGSmartUI',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleteProfile,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '삭제',
                  style: TextStyle(
                    fontFamily: 'LGSmartUI',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
        keyboardType: TextInputType.text,
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
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
