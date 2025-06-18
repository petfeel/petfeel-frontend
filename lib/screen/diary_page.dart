// lib/screen/diary_page.dart

import 'dart:io';
import 'dart:convert'; // utf8 디코딩을 위한 import 추가
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';  // API 엔드포인트 추가
import 'dart:async';

class DiaryPage extends StatefulWidget {
  final List<Map<String, dynamic>> petList;
  final int initialIndex;

  const DiaryPage({
    Key? key,
    required this.petList,
    this.initialIndex = 0,
  }) : super(key: key);

  factory DiaryPage.single({required Map<String, dynamic> petData}) =>
      DiaryPage(petList: [petData]);

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late final PageController _controller;
  late int _current;

  /// 로딩 애니메이션 텍스트
  String _loadingText = '로딩 중.';

  Timer? _loadingTimer;

  /// petKey + 날짜(yyyyMMdd) 조합으로 관리할 때 사용하는 공통 키 문자열
  String get _currentDateKey {
    final now = _selectedDate;
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d'; // 예: "20250604"
  }

  /// pet 고유 키. pet['id']가 있으면 그 값, 없으면 pet['pet_name']을 문자열로 사용
  String _petKey(Map<String, dynamic> p) =>
      (p['id'] ?? p['pet_name']).toString();

  /// 최종적으로 SharedPreferences에 쓸 이미지 키
  String _imageKey(Map<String, dynamic> p) =>
      'diary_image_${_petKey(p)}_${_currentDateKey}';

  /// SharedPreferences에 쓸 "이상행동 일기" 키
  String _abnormalTextKey(Map<String, dynamic> p) =>
      'diary_abnormal_${_petKey(p)}_${_currentDateKey}';

  /// SharedPreferences에 쓸 "오늘의 일기" 키
  String _normalTextKey(Map<String, dynamic> p) =>
      'diary_normal_${_petKey(p)}_${_currentDateKey}';

  /// 현재 선택된 날짜 (시·분·초 제거)
  late DateTime _selectedDate;

  /// pet+날짜별 이미지를 저장하는 맵
  final Map<String, File?> _images = {};

  /// pet+날짜별 "이상행동 일기" 컨트롤러 맵
  final Map<String, TextEditingController> _abnormalControllers = {};

  /// pet+날짜별 "오늘의 일기" 컨트롤러 맵
  final Map<String, TextEditingController> _normalControllers = {};

  /// DB에서 가져온 일기 데이터 저장
  Map<String, Map<String, String>> _dbDiaries = {};

  /// 데이터 로딩 중 상태
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);

    // 초기 날짜 설정: 오늘
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    // 초기 이미지 및 텍스트 로드
    _loadImageForCurrent();
    _loadTextsForCurrent();

    // 페이지 진입 즉시 로딩 점 애니메이션 시작
    _startLoadingAnimation('로딩 중.');

    // 초기화 시 DB에서 자동 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDiaryFromDB(showMessage: false);
    });
  }

  void _startLoadingAnimation(String initialText) {
    _loadingText = initialText;
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      setState(() {
        if (_loadingText.endsWith('...')) {
          _loadingText = initialText;
        } else {
          _loadingText += '.';
        }
      });
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  /// 현재 pet(=widget.petList[_current])와 _selectedDate 조합으로 이미지 로드
  Future<void> _loadImageForCurrent() async {
    final pet = widget.petList[_current];
    final key = _imageKey(pet);
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(key);
    if (path != null && File(path).existsSync()) {
      setState(() {
        _images[key] = File(path);
      });
    } else {
      setState(() {
        _images[key] = null;
      });
    }
  }

  /// 현재 pet+날짜 조합으로 "이상행동 일기"와 "오늘의 일기" 로드
  Future<void> _loadTextsForCurrent() async {
    final pet = widget.petList[_current];
    final petKey = _petKey(pet);
    final abKey = _abnormalTextKey(pet);
    final nmKey = _normalTextKey(pet);
    final prefs = await SharedPreferences.getInstance();

    // DB에서 가져온 데이터가 있는지 확인
    final hasDiaryData = _dbDiaries.containsKey(petKey);

    if (hasDiaryData) {
      // DB 데이터 사용
      final dbData = _dbDiaries[petKey]!;

      // 이상행동 일기
      final abText = dbData['abnormal_diary'] ?? '';
      if (!_abnormalControllers.containsKey(abKey)) {
        _abnormalControllers[abKey] = TextEditingController(text: abText);
      } else {
        _abnormalControllers[abKey]!.text = abText;
      }

      // 오늘의 일기
      final nmText = dbData['normal_diary'] ?? '';
      if (!_normalControllers.containsKey(nmKey)) {
        _normalControllers[nmKey] = TextEditingController(text: nmText);
      } else {
        _normalControllers[nmKey]!.text = nmText;
      }
    } else {
      // 로컬 저장소에서 로드
      // 이상행동 일기
      final abText = prefs.getString(abKey) ?? '';
      if (!_abnormalControllers.containsKey(abKey)) {
        _abnormalControllers[abKey] = TextEditingController(text: abText);
      } else {
        _abnormalControllers[abKey]!.text = abText;
      }

      // 오늘의 일기
      final nmText = prefs.getString(nmKey) ?? '';
      if (!_normalControllers.containsKey(nmKey)) {
        _normalControllers[nmKey] = TextEditingController(text: nmText);
      } else {
        _normalControllers[nmKey]!.text = nmText;
      }
    }

    setState(() {});
  }

  /// pet+날짜 조합으로 이미지 저장
  Future<void> _saveImageForCurrent(String path) async {
    final pet = widget.petList[_current];
    final key = _imageKey(pet);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, path);
    setState(() {
      _images[key] = File(path);
    });
  }

  /// pet+날짜 조합으로 이미지 삭제
  Future<void> _removeImageForCurrent() async {
    final pet = widget.petList[_current];
    final key = _imageKey(pet);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    setState(() {
      _images[key] = null;
    });
  }

  /// pet+날짜+일기 종류(이상행동/오늘) 조합으로 텍스트 저장
  Future<void> _saveTextForCurrent(
      Map<String, dynamic> pet, String type, String text) async {
    final prefs = await SharedPreferences.getInstance();
    late final String key;
    if (type == 'abnormal') {
      key = _abnormalTextKey(pet);
    } else {
      key = _normalTextKey(pet);
    }
    await prefs.setString(key, text);
  }

  /// "오늘" 날짜만 반환 (시·분·초 제거)
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 선택된 날짜를 "YYYY년 M월 D일" 형식으로 리턴 (예: "2025년 6월 4일")
  String get _formattedSelectedDate {
    return '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일';
  }

  /// DB에서 해당 날짜의 일기 데이터 가져오기 (조회 기능)
  Future<void> _fetchDiaryFromDB({bool showMessage = true}) async {
    final pet = widget.petList[_current];
    final petId = pet['id'] ?? 1;
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    _startLoadingAnimation('로딩 중.');
    setState(() {
      _isLoading = true;
    });

    try {
      // 일기 데이터 API 요청 - 조회만 하는 엔드포인트로 변경
      final response = await http.get(
        Uri.parse('${ApiEndpoints.dailySummaryView.replaceFirst('{pet_id}', petId.toString()).replaceFirst('{date}', dateStr)}'),
      );

      debugPrint('📘 일기 데이터 조회 요청: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)); // 인코딩 문제 해결
        final key = _petKey(pet);

        // 일기 데이터 저장
        setState(() {
          _dbDiaries[key] = {
            'normal_diary': data['normal_summary'] ?? '',
            'abnormal_diary': data['abnormal_summary'] ?? '',
          };

          // 컨트롤러에 DB 데이터 설정
          final abKey = _abnormalTextKey(pet);
          final nmKey = _normalTextKey(pet);

          if (_abnormalControllers.containsKey(abKey)) {
            _abnormalControllers[abKey]!.text = data['abnormal_summary'] ?? '';
          }

          if (_normalControllers.containsKey(nmKey)) {
            _normalControllers[nmKey]!.text = data['normal_summary'] ?? '';
          }
        });

        debugPrint('✅ 일기 데이터 조회 완료');

        // 성공 메시지 표시 (직접 버튼을 눌렀을 때만)
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '일기 데이터를 조회했습니다.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 70),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(milliseconds: 700),
            ),
          );
        }
      } else if (response.statusCode == 404) {
        // 데이터가 없는 경우
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '해당 날짜의 일기 데이터가 없습니다.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 70),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(milliseconds: 700),
            ),
          );
        }
      } else {
        debugPrint('⚠️ 일기 데이터 조회 실패: ${response.statusCode}');
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '일기 데이터 조회에 실패했습니다.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 70),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(milliseconds: 700),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ 일기 데이터 조회 중 오류: $e');
    } finally {
      _stopLoadingAnimation();
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 일기 생성 요청 (히스토리 버튼)
  Future<void> _generateDiary() async {
    final pet = widget.petList[_current];
    final petId = pet['id'] ?? 1;


    _startLoadingAnimation('일기 생성중.');

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 일기 생성 요청 중...');

      // 선택한 날짜를 API 요청에 포함 (일기 생성 API 사용)
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final response = await http.get(
        Uri.parse('${ApiEndpoints.diary.replaceFirst('{pet_id}', petId.toString()).replaceFirst('{year}', _selectedDate.year.toString()).replaceFirst('{month}', _selectedDate.month.toString()).replaceFirst('{day}', _selectedDate.day.toString())}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)); // 인코딩 문제 해결

        debugPrint('✅ 일기 생성 완료');

        // 생성된 일기 데이터 저장
        final key = _petKey(pet);
        setState(() {
          _dbDiaries[key] = {
            'normal_diary': data['normal_diary'] ?? '',
            'abnormal_diary': data['abnormal_diary'] ?? '',
          };

          // 컨트롤러에 DB 데이터 설정
          final abKey = _abnormalTextKey(pet);
          final nmKey = _normalTextKey(pet);

          if (_abnormalControllers.containsKey(abKey)) {
            _abnormalControllers[abKey]!.text = data['abnormal_diary'] ?? '';
          }

          if (_normalControllers.containsKey(nmKey)) {
            _normalControllers[nmKey]!.text = data['normal_diary'] ?? '';
          }
        });

        // 완료 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '일기가 생성되었습니다.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 70),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(milliseconds: 700),
          ),
        );
      } else {
        debugPrint('⚠️ 일기 생성 실패: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '일기 생성에 실패했습니다.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 70),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(milliseconds: 700),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 일기 생성 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '일기 생성 중 오류가 발생했습니다. (${e.toString()})',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 70),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(milliseconds: 700),
        ),
      );
    } finally {
      _stopLoadingAnimation();
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPet = widget.petList[_current];
    final currentImage = _images[_imageKey(currentPet)];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(currentPet),

      // ──────────────────────────────────────────────────────────────────────
      // Body: Column 안에 상단(달력/인디케이터), 중간(PageView), 하단(고정 버튼)이 위치
      body: Stack(
        children: [
          Column(
            children: [
              // ➊ 달력 + 좌/우 화살표 + 날짜 텍스트 + "오늘로" 버튼 (수정된 부분)
              _dateHeader(),

              // ➋ 인디케이터
              _indicator(),

              // ➌ PageView: 스크롤 되는 콘텐츠 영역
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.petList.length,
                  onPageChanged: (i) {
                    setState(() => _current = i);
                    // 펫이 바뀔 때마다 이미지/텍스트 로드
                    _loadImageForCurrent();
                    _loadTextsForCurrent();
                    // 펫 변경 시 자동 조회
                    _fetchDiaryFromDB(showMessage: false);
                  },
                  itemBuilder: (_, i) {
                    return _pageBody(widget.petList[i], _selectedDate);
                  },
                ),
              ),

              // ➍ 하단 고정: 버튼들
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 25.0),
                child: Row(
                  children: [
                    // 조회 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _fetchDiaryFromDB(showMessage: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text(
                          '조회',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'LGSmartUI',
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 히스토리(일기 생성) 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _generateDiary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text(
                          '일기 생성',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'LGSmartUI',
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 로딩 인디케이터
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loadingText,               // ← 고정 문자열 → 변수
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'LGSmartUI',
                        shadows: [
                          Shadow(offset: Offset(0, 0), blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 앱바 부분
  PreferredSizeWidget _appBar(Map<String, dynamic> pet) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.black),
      onPressed: () {
        Navigator.pop(context);
      },
    ),
    backgroundColor: Colors.white,
    elevation: 0.5,
    centerTitle: true,
    title: const Text(
      '일기',
      style: TextStyle(
        color: Colors.black,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        fontFamily: 'LGSmartUI',
      ),
    ),
    actions: [
      if (widget.petList.length > 1)
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: _current == 0 ? Colors.grey : Colors.black,
              ),
              onPressed: _current == 0
                  ? null
                  : () {
                _controller.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: _current == widget.petList.length - 1
                    ? Colors.grey
                    : Colors.black,
              ),
              onPressed: _current == widget.petList.length - 1
                  ? null
                  : () {
                _controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              },
            ),
          ],
        ),
    ],
  );

  /// 달력 아이콘 + 좌/우 화살표 + 날짜 텍스트 + "오늘로" 버튼
  Widget _dateHeader() {
    // "오늘"과 비교하여 우측 화살표 활성/비활성 결정
    final isAtToday = _selectedDate.year == _today.year &&
        _selectedDate.month == _today.month &&
        _selectedDate.day == _today.day;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ▶ 왼쪽 달력 아이콘 (아이콘 크기: 24, 패딩 0)
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
                  _selectedDate = DateTime(picked.year, picked.month, picked.day);
                });
                _loadImageForCurrent();
                _loadTextsForCurrent();
                // 날짜 변경 시 자동 조회
                _fetchDiaryFromDB(showMessage: false);
              }
            },
          ),

          const SizedBox(width: 12),

          // ▶ 왼쪽 화살표 (아이콘 크기: 24, 패딩 0)
          IconButton(
            iconSize: 24,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left, color: Colors.black),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
              _loadImageForCurrent();
              _loadTextsForCurrent();
              // 날짜 변경 시 자동 조회
              _fetchDiaryFromDB(showMessage: false);
            },
          ),

          // ▶ 날짜 텍스트 (가운데 배치)
          Expanded(
            child: Center(
              child: Text(
                _formattedSelectedDate,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'LGSmartUI',
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // ▶ 오른쪽 화살표 (아이콘 크기: 24, 패딩 0)
          IconButton(
            iconSize: 24,
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.chevron_right,
              color: isAtToday ? Colors.grey : Colors.black,
            ),
            onPressed: isAtToday
                ? null
                : () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
              _loadImageForCurrent();
              _loadTextsForCurrent();
              // 날짜 변경 시 자동 조회
              _fetchDiaryFromDB(showMessage: false);
            },
          ),

          // ▶ (오늘로 버튼 부분을 완전히 삭제했습니다)
        ],
      ),
    );
  }

  /// 페이지별 인디케이터 (반려동물 수가 1보다 클 때 점으로 표시)
  Widget _indicator() => widget.petList.length == 1
      ? const SizedBox(height: 12)
      : Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.petList.length, (i) {
        final selected = i == _current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.grey[400],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    ),
  );

  /// pet 데이터와 함께 날짜 정보를 전달해서 화면을 렌더링하는 함수
  /// (버튼 부분은 여기에 포함시키지 않습니다)
  Widget _pageBody(Map<String, dynamic> pet, DateTime date) {
    final name = pet['pet_name'] ?? '반려동물';
    final imageKey = _imageKey(pet);
    final img = _images[imageKey];

    // 해당 날짜에 저장된 컨트롤러(없으면 새로 생성했으므로 항상 존재)
    final abKey = _abnormalTextKey(pet);
    final nmKey = _normalTextKey(pet);
    final abnormalController = _abnormalControllers[abKey]!;
    final normalController = _normalControllers[nmKey]!;

    // DB에서 가져온 일기 데이터
    final petKey = _petKey(pet);
    final hasDiaryData = _dbDiaries.containsKey(petKey);
    final dbData = hasDiaryData ? _dbDiaries[petKey]! : <String, String>{};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ───── 사진 섹션 ────────────────────────────────────────────
          _sectionHeader(Icons.photo_library, '오늘의 $name'),
          const SizedBox(height: 12),
          _photoBox(pet, img),
          const SizedBox(height: 30),

          // ───── 이상행동 일기 섹션 ─────────────────────────────────────
          Row(
            children: [
              _sectionHeader(Icons.menu_book, '이상행동 일기'),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDiaryData && dbData['abnormal_diary']?.isNotEmpty == true)
          // DB에서 가져온 이상행동 일기 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD4D4D4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dbData['abnormal_diary'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'LGSmartUI',
                  fontWeight: FontWeight.w400,
                  height: 1.7,
                  color: Colors.black,
                ),
              ),
            )
          else
          // 입력 가능한 텍스트 박스 표시
            _diaryBox(
              placeholder:
              '이상행동 일기가 없습니다.',
              controller: abnormalController,
              onChanged: (text) {
                _saveTextForCurrent(pet, 'abnormal', text);
              },
            ),
          const SizedBox(height: 30),

          // ───── 오늘의 일기 섹션 ───────────────────────────────────────
          Row(
            children: [
              _sectionHeader(Icons.pets, '오늘의 일기'),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDiaryData && dbData['normal_diary']?.isNotEmpty == true)
          // DB에서 가져온 오늘의 일기 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD4D4D4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dbData['normal_diary'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'LGSmartUI',
                  fontWeight: FontWeight.w400,
                  height: 1.7,
                  color: Colors.black,
                ),
              ),
            )
          else
          // 입력 가능한 텍스트 박스 표시
            _diaryBox(
              placeholder:
              '오늘의 일기가 없습니다.',
              controller: normalController,
              onChanged: (text) {
                _saveTextForCurrent(pet, 'normal', text);
              },
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: Colors.black),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontFamily: 'LGSmartUI',
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );

  Widget _photoBox(Map<String, dynamic> pet, File? img) => GestureDetector(
    onTap: () async {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        await _saveImageForCurrent(picked.path);
      }
    },
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 138),
      decoration: BoxDecoration(
        color: const Color(0x33D9D9D9),
        border: Border.all(color: const Color(0xFFD4D4D4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: img != null
          ? Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              img,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removeImageForCurrent,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child:
                const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      )
          : SizedBox(
        height: 138,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add, size: 40, color: Colors.black45),
              SizedBox(height: 8),
              Text(
                '사진 추가하기',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'LGSmartUI',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );


  @override
  void dispose() {
    _loadingTimer?.cancel();          // ① 타이머 해제
    _controller.dispose();            // ② PageController 해제
    for (final c in _abnormalControllers.values) { c.dispose(); }
    for (final c in _normalControllers.values)   { c.dispose(); }
    super.dispose();
  }

  Widget _diaryBox({
    required String placeholder,
    required TextEditingController controller,
    required Function(String) onChanged,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD4D4D4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: controller,
          maxLines: null,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'LGSmartUI',
            fontWeight: FontWeight.w400,
            height: 1.7,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(
              fontSize: 14,
              fontFamily: 'LGSmartUI',
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.7,
            ),
            border: InputBorder.none,
          ),
          onChanged: onChanged,
        ),
      );
}

