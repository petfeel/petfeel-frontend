// lib/screen/streaming_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// ApiEndpoints, VoiceStorage, VoiceListPage import
import 'package:test123/utils/api_endpoints.dart';
import 'package:test123/utils/voice_storage.dart';
import 'package:test123/screen/voice_list_page.dart';

// VideoStorage, VideoListPage import
import 'package:test123/utils/video_storage.dart';
import 'package:test123/screen/video_list_page.dart';

class Streaming extends StatefulWidget {
  final Map<String, dynamic> petData;
  const Streaming({Key? key, required this.petData}) : super(key: key);

  @override
  _StreamingState createState() => _StreamingState();
}

class _StreamingState extends State<Streaming> {
  late final String streamUrl;

  bool isRecording = false;
  bool isProcessing = false;
  DateTime? _videoRecordStartTime;

  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _recorderInitialized = false;
  bool _isAudioRecording = false;
  String? _audioFilePath;
  DateTime? _recordStartTime;

  @override
  void initState() {
    super.initState();
    streamUrl = ApiEndpoints.stream;
    _initAudioRecorder();
  }

  @override
  void dispose() {
    if (_recorderInitialized) {
      _audioRecorder.closeRecorder();
    }
    super.dispose();
  }

  Future<void> _initAudioRecorder() async {
    try {
      await _audioRecorder.openRecorder();
      _recorderInitialized = true;
    } catch (e) {
      _recorderInitialized = false;
      _showStyledSnackBar(
        message: '녹음 세션 초기화 실패: $e',
        backgroundColor: Colors.red,
      );
      return;
    }

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showStyledSnackBar(
        message: '마이크 권한이 필요합니다.',
        backgroundColor: Colors.red,
      );
    }
  }

  void _showStyledSnackBar({
    required String message,
    required Color backgroundColor,
    Duration duration = const Duration(milliseconds: 700),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: duration,
      ),
    );
  }

  Future<String?> _promptForFileName({required String hintText}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          '파일 이름 입력',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black54),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.teal),
            ),
          ),
          style: const TextStyle(fontFamily: 'LGSmartUI', fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'LGSmartUI',
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final txt = controller.text.trim();
              if (txt.isEmpty) {
                _showStyledSnackBar(
                  message: '파일 이름을 입력해주세요.',
                  backgroundColor: Colors.red,
                );
                return;
              }
              Navigator.of(ctx).pop(txt);
            },
            child: const Text(
              '확인',
              style: TextStyle(
                fontFamily: 'LGSmartUI',
                fontSize: 14,
                color: Colors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onScreenRecordButtonPressed() {
    if (isProcessing) return;
    if (!isRecording) {
      setState(() {
        isRecording = true;
        isProcessing = true;
        _videoRecordStartTime = DateTime.now();
      });
      _startScreenRecording();
    } else {
      _stopScreenRecordingFlow();
    }
  }

  Future<void> _startScreenRecording() async {
    final uri = Uri.parse(
      ApiEndpoints.recordStart.replaceFirst('{petId}', widget.petData['id'].toString()),
    );

    _showStyledSnackBar(
      message: '화면 녹화를 시작했습니다.',
      backgroundColor: Colors.green,
    );
    try {
      final response = await http.post(uri);
      if (response.statusCode != 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        _showStyledSnackBar(
          message: '녹화 시작 실패: ${body['detail'] ?? '알 수 없는 오류'}',
          backgroundColor: Colors.red,
        );
        setState(() {
          isRecording = false;
        });
      }
    } catch (e) {
      _showStyledSnackBar(
        message: '녹화 시작 오류: $e',
        backgroundColor: Colors.red,
      );
      setState(() {
        isRecording = false;
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _stopScreenRecordingFlow() async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    // 1. 바로 녹화 중지 API 호출
    final uriStop = Uri.parse(ApiEndpoints.recordStop);
    try {
      final stopResponse = await http.post(uriStop);
      if (stopResponse.statusCode != 200) {
        final body = json.decode(stopResponse.body) as Map<String, dynamic>;
        _showStyledSnackBar(
          message: '녹화 중지 실패: ${body['detail'] ?? '알 수 없는 오류'}',
          backgroundColor: Colors.red,
        );
        setState(() => isProcessing = false);
        return;
      }
    } catch (e) {
      _showStyledSnackBar(
        message: '녹화 중지 오류: $e',
        backgroundColor: Colors.red,
      );
      setState(() => isProcessing = false);
      return;
    }

    // 2. 중지 직후 사용자에게 이름 입력
    final fileNameFromUser = await _promptForFileName(hintText: '예: 나의_녹화영상');
    if (fileNameFromUser == null || fileNameFromUser.trim().isEmpty) {
      _showStyledSnackBar(
        message: '파일 이름이 입력되지 않아 저장이 취소되었습니다.',
        backgroundColor: Colors.red,
      );
      setState(() {
        isRecording = false;
        isProcessing = false;
      });
      return;
    }
    final chosenTitle = '$fileNameFromUser.mp4';

    // 2.5 이름 반영 중 대기 스낵바
    _showStyledSnackBar(
      message: '잠시만 기다려주세요...',
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    );

    // 3. 이름 서버에 반영
    final uriRename = Uri.parse(ApiEndpoints.recordRename);
    try {
      final renameResponse = await http.post(
        uriRename,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'video_name': chosenTitle}),
      );
      if (renameResponse.statusCode != 200) {
        final body = json.decode(renameResponse.body) as Map<String, dynamic>;
        _showStyledSnackBar(
          message: '이름 반영 실패: ${body['detail'] ?? '알 수 없는 오류'}',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      _showStyledSnackBar(
        message: '이름 반영 중 오류: $e',
        backgroundColor: Colors.red,
      );
    }

    // 4. 리스트에 추가 및 완료
    _addRecordedVideoToList(chosenTitle);
    _showStyledSnackBar(
      message: '영상이 저장되었습니다.',
      backgroundColor: Colors.green,
    );

    setState(() {
      isRecording = false;
      isProcessing = false;
    });
  }


  void _addRecordedVideoToList(String customTitle) {
    if (_videoRecordStartTime == null) return;

    final stopTime = DateTime.now();
    final diff = stopTime.difference(_videoRecordStartTime!);
    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    final formattedDuration = '$minutes:$seconds';

    final petName = widget.petData['pet_name'] as String? ?? 'Unknown';
    const placeholderThumbnail = 'https://via.placeholder.com/120x68?text=Video';

    VideoStorage.items.add({
      'title': customTitle,
      'channel': petName,
      'duration': formattedDuration,
      'thumbnail': placeholderThumbnail,
    });
  }

  Future<void> _startAudioRecording() async {
    if (!_recorderInitialized) {
      _showStyledSnackBar(
        message: '녹음 초기화가 필요합니다.',
        backgroundColor: Colors.red,
      );
      return;
    }
    final micStatus = await Permission.microphone.status;
    if (micStatus != PermissionStatus.granted) {
      final req = await Permission.microphone.request();
      if (req != PermissionStatus.granted) {
        _showStyledSnackBar(
          message: '마이크 권한이 필요합니다.',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${widget.petData['pet_name']}_${DateTime.now().millisecondsSinceEpoch}.aac';
      _audioFilePath = p.join(tempDir.path, fileName);
    } catch (e) {
      _showStyledSnackBar(
        message: '임시 경로 생성 실패: $e',
        backgroundColor: Colors.red,
      );
      return;
    }

    try {
      _recordStartTime = DateTime.now();
      await _audioRecorder.startRecorder(
        toFile: _audioFilePath,
        codec: Codec.aacADTS,
        bitRate: 128000,
        sampleRate: 44100,
      );
      setState(() {
        _isAudioRecording = true;
      });
      _showStyledSnackBar(
        message: '음성 녹음을 시작했습니다.',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      _showStyledSnackBar(
        message: '녹음 시작 실패: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _stopAudioRecording() async {
    if (!_isAudioRecording || _audioFilePath == null) return;

    try {
      // 1) 녹음 중지 (UI 상태는 이 시점에 바꾸지 않습니다)
      await _audioRecorder.stopRecorder();

      // 녹음이 멈췄지만, 아이콘은 아직 '중지' 상태로 유지

      // 2) 녹음 길이 계산
      final stopTime = DateTime.now();
      if (_recordStartTime == null) _recordStartTime = stopTime;
      final diff = stopTime.difference(_recordStartTime!);
      final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      final formattedDuration = '$minutes:$seconds';

      // 3) 파일명 입력 팝업
      final userInput = await _promptForFileName(hintText: '예: 나의_녹음파일');
      if (userInput == null || userInput.trim().isEmpty) {
        // 취소했을 때도 아이콘은 '중지' 상태 그대로 유지
        _showStyledSnackBar(
          message: '파일 이름이 입력되지 않아 업로드를 취소했습니다.',
          backgroundColor: Colors.red,
        );
        return;
      }
      final desiredFilename = '$userInput.aac';

      // 4) 리스트에 추가 (제목만 사용자 입력값으로)
      VoiceStorage.items.add({
        'title': userInput,
        'subtitle': widget.petData['pet_name'] as String? ?? '',
        'duration': formattedDuration,
        'filePath': _audioFilePath!,
      });

      _showStyledSnackBar(
        message: '녹음을 저장했습니다.',
        backgroundColor: Colors.green,
      );

      // 5) 서버 업로드
      await _uploadAudioFile(_audioFilePath!, desiredFilename);

      // 6) 업로드까지 끝난 뒤에야 아이콘을 다시 '녹음하기' 상태로 변경
      setState(() {
        _isAudioRecording = false;
      });
    } catch (e) {
      _showStyledSnackBar(
        message: '녹음 중지 실패: $e',
        backgroundColor: Colors.red,
      );
    }
  }


  Future<void> _uploadAudioFile(String filePath, String desiredFilename) async {
    final rawPetName = widget.petData['pet_name'] as String? ?? '';
    if (rawPetName.isEmpty) {
      _showStyledSnackBar(
        message: '반려동물 이름이 없습니다.',
        backgroundColor: Colors.red,
      );
      return;
    }
    final encodedPetName = Uri.encodeComponent(rawPetName);
    final uri = Uri.parse(ApiEndpoints.uploadVoice.replaceFirst('{petName}', encodedPetName));

    final file = File(filePath);
    if (!file.existsSync()) {
      _showStyledSnackBar(
        message: '녹음 파일을 찾을 수 없습니다.',
        backgroundColor: Colors.red,
      );
      return;
    }

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: desiredFilename,
          contentType: MediaType('audio', 'aac'),
        ),
      );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 업로드 성공 시 SnackBar 표시를 원치 않으면 이 부분을 비워두세요.
      } else {
        String detailMsg = '알 수 없는 오류';
        try {
          final body = json.decode(response.body) as Map<String, dynamic>;
          detailMsg = body['detail'] ?? detailMsg;
        } catch (_) {}
        _showStyledSnackBar(
          message: '업로드 실패: $detailMsg',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      _showStyledSnackBar(
        message: '업로드 중 오류: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color recordBtnColor = isRecording ? Colors.white : const Color(0x4CB8E5E0);
    final IconData recordIcon = isRecording ? Icons.stop : Icons.videocam;
    final String recordLabel = isRecording ? '녹화 중지' : '녹화하기';

    final Color audioBtnColor = _isAudioRecording ? Colors.white : const Color(0x4CB8E5E0);
    final IconData audioIcon = _isAudioRecording ? Icons.mic_off : Icons.mic;
    final String audioLabel = _isAudioRecording ? '녹음 중지' : '녹음하기';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          '실시간 스트리밍',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'LGSmartUI',
          ),
        ),
        actions: [
          Transform.translate(
            offset: const Offset(15, 0),
            child: IconButton(
              icon: const Icon(Icons.video_library, color: Colors.black54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VideoListPage()),
                );
              },
              tooltip: '영상 목록',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.library_music, color: Colors.black54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceListPage()),
                );
              },
              tooltip: '음성 목록',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현재 화면',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'LGSmartUI',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                  color: const Color(0x0F000000),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Mjpeg(
                          stream: streamUrl,
                          isLive: true,
                          fit: BoxFit.cover,
                          error: (ctx, error, stack) {
                            return Center(
                              child: Text(
                                '스트림을 불러올 수 없습니다.\n${error.toString()}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontFamily: 'LGSmartUI',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Color(0x0F000000),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomRight: Radius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Stable Connection',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'LGSmartUI',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '거실 카메라',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontFamily: 'LGSmartUI',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '연결됨',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: 'LGSmartUI',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StreamingControl(
                  icon: Icons.volume_up,
                  label: '소리 켜기',
                  onTap: () {
                    _showStyledSnackBar(
                      message: '소리 켜기 클릭됨',
                      backgroundColor: Colors.blue,
                    );
                  },
                ),
                GestureDetector(
                  onTap: _onScreenRecordButtonPressed,
                  child: Column(
                    children: [
                      Container(
                        width: 73,
                        height: 73,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: recordBtnColor,
                          border: Border.all(
                            color: const Color(0xFF00C8BC),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            recordIcon,
                            size: 30,
                            color: const Color(0xFF00C8BC),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recordLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'LGSmartUI',
                        ),
                      ),
                    ],
                  ),
                ),
                _StreamingControl(
                  icon: Icons.photo_camera,
                  label: '캡쳐하기',
                  onTap: () {
                    _showStyledSnackBar(
                      message: '캡쳐하기 클릭됨',
                      backgroundColor: Colors.blue,
                    );
                  },
                ),
                GestureDetector(
                  onTap: () {
                    if (_isAudioRecording) {
                      _stopAudioRecording();
                    } else {
                      _startAudioRecording();
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 73,
                        height: 73,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: audioBtnColor,
                          border: Border.all(
                            color: const Color(0xFF00C8BC),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            audioIcon,
                            size: 30,
                            color: const Color(0xFF00C8BC),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        audioLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'LGSmartUI',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StreamingControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 73,
            height: 73,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x4CB8E5E0),
              border: Border.all(
                color: const Color(0xFF00C8BC),
                width: 2,
              ),
            ),
            child: Icon(icon, size: 30, color: const Color(0xFF00C8BC)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'LGSmartUI',
            ),
          ),
        ],
      ),
    );
  }
}