import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
// import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:typed_data';
import '../utils/api_endpoints.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';

class AlarmVideoPage extends StatefulWidget {
  final int eventId;
  final String videoName;
  final int petId;
  final int stage; // 심각도 단계 추가

  const AlarmVideoPage({
    Key? key,
    required this.eventId,
    required this.videoName,
    required this.petId,
    this.stage = 0, // 기본값 0
  }) : super(key: key);

  @override
  State<AlarmVideoPage> createState() => _AlarmVideoPageState();
}

class _AlarmVideoPageState extends State<AlarmVideoPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  File? _videoFile;
  bool _isAssetVideo = false;
  int _stageForSample = 0; // 샘플 영상 선택용 스테이지 값

  String _loadingText = '비디오 로딩 중.';
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _stageForSample = widget.stage;
    _startLoadingAnimation();
    _loadVideo();
  }

  void _startLoadingAnimation() {
    _loadingText = '비디오 로딩 중.';
    _loadingTimer?.cancel();
    _loadingTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) {
          if (!mounted) return;
          setState(() {
            _loadingText = _loadingText.endsWith('...')
                ? '비디오 로딩 중.'
                : '$_loadingText.';
          });
        });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    _loadingText = '비디오 로딩 중.';
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    try {
      // 스테이지에 따른 샘플 비디오 선택
      String assetVideoPath = 'assets/videos/sample.mp4'; // 기본 샘플
      if (_stageForSample >= 1 && _stageForSample <= 3) {
        assetVideoPath = 'assets/videos/sample_stage${_stageForSample}.mp4';
      }

      // 비디오 저장 디렉토리 설정
      final appDir = await getTemporaryDirectory(); // 캐시 디렉토리 사용
      final videosDir = Directory('${appDir.path}/pet_videos');

      // 디렉토리가 없으면 생성
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      // 비디오 파일 경로 설정
      final videoFilePath = '${videosDir.path}/${widget.videoName}';
      final videoFile = File(videoFilePath);

      // 이미 다운로드된 파일이 있고 크기가 충분한지 확인
      if (await videoFile.exists()) {
        int fileSize = await videoFile.length();
        if (fileSize > 10000) { // 10KB 이상이면 유효한 비디오로 간주
          debugPrint('📁 로컬에서 비디오 파일을 찾았습니다: ${widget.videoName} (${fileSize}바이트)');
          _videoFile = videoFile;
          await _initializePlayer(videoFile);
          return;
        } else {
          debugPrint('⚠️ 로컬 비디오 파일이 손상되었습니다. 다시 다운로드합니다.');
          // 손상된 파일 삭제
          try {
            await videoFile.delete();
          } catch (e) {
            debugPrint('⚠️ 파일 삭제 실패: $e');
          }
        }
      }

      // 서버에서 파일 다운로드 시도
      bool downloadSuccess = await _downloadVideo(videoFilePath);

      // 다운로드 실패 시 샘플 비디오 사용
      if (!downloadSuccess) {
        // 앱 내장 샘플 비디오가 있으면 사용
        try {
          debugPrint('🔄 스테이지 ${_stageForSample}에 맞는 샘플 비디오로 대체합니다...');

          // 앱 에셋의 샘플 비디오 사용 시도
          _isAssetVideo = true;
          await _initializeAssetVideo(assetVideoPath);
          return;
        } catch (e) {
          debugPrint('⚠️ 샘플 비디오 로드 실패: $e');
          _setErrorState('이상행동 영상을 재생할 수 없습니다.');
        }
      }
    } catch (e) {
      debugPrint('❌ 비디오 로드 오류: $e');
      _setErrorState('비디오를 로드하는 중 오류가 발생했습니다: $e');
    }
  }

  Future<bool> _downloadVideo(String filePath) async {
    try {
      // API 엔드포인트 목록 (여러 가능한 엔드포인트 시도)
      final endpoints = [
        '${ApiEndpoints.base}/events/${widget.eventId}/video',
        '${ApiEndpoints.base}/event/${widget.eventId}/video',
        '${ApiEndpoints.base}/video/${widget.eventId}',
        '${ApiEndpoints.base}/videos/${widget.videoName}'
      ];

      debugPrint('🔍 이벤트 ID: ${widget.eventId}, 비디오 이름: ${widget.videoName}');

      // 각 엔드포인트 시도
      for (final url in endpoints) {
        debugPrint('🌐 비디오 다운로드 시도: $url');
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {'Accept': 'video/mp4, application/octet-stream'}
          );

          if (response.statusCode == 200 &&
              response.bodyBytes.isNotEmpty &&
              response.bodyBytes.length > 10000) {

            debugPrint('✅ 다운로드 성공 ($url): ${response.bodyBytes.length} 바이트');

            // MP4 헤더 확인 (유효성 검사)
            bool isValidMp4 = _isValidMp4(response.bodyBytes);
            if (!isValidMp4) {
              debugPrint('⚠️ 유효하지 않은 MP4 데이터 ($url)');
              continue;
            }

            // 유효한 비디오 데이터를 파일로 저장
            final videoFile = File(filePath);
            await videoFile.writeAsBytes(response.bodyBytes);
            debugPrint('✅ 비디오 파일 저장 완료: $filePath');

            // 저장 후 유효성 검사
            final fileSize = await videoFile.length();
            if (fileSize > 10000) {
              _videoFile = videoFile;
              await _initializePlayer(videoFile);
              return true;
            } else {
              debugPrint('⚠️ 저장된 파일이 너무 작습니다: $fileSize 바이트');
              await videoFile.delete();
            }
          } else {
            debugPrint('⚠️ API 응답 실패 ($url): ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('⚠️ 요청 실패 ($url): $e');
        }
      }

      // 직접 비디오 데이터에 액세스 시도 (DB에서 비디오 데이터 조회)
      try {
        final directUrl = '${ApiEndpoints.base}/events/${widget.eventId}';
        debugPrint('🌐 이벤트 정보 조회 시도: $directUrl');

        final response = await http.get(Uri.parse(directUrl));
        if (response.statusCode == 200) {
          // JSON 문자열을 Map으로 변환
          final eventData = json.decode(response.body);

          if (eventData.containsKey('video_data') &&
              eventData['video_data'] != null &&
              eventData['video_data'].length > 10000) {

            debugPrint('✅ 이벤트 데이터에서 비디오 추출 성공');

            // 바이너리 데이터로 변환 및 저장
            final bytes = eventData['video_data'];
            final videoFile = File(filePath);
            await videoFile.writeAsBytes(bytes);

            _videoFile = videoFile;
            await _initializePlayer(videoFile);
            return true;
          }
        }
      } catch (e) {
        debugPrint('⚠️ 이벤트 데이터 직접 조회 실패: $e');
      }

      debugPrint('❌ 모든 다운로드 시도 실패');
      return false;
    } catch (e) {
      debugPrint('❌ 비디오 다운로드 오류: $e');
      return false;
    }
  }

  // MP4 파일 헤더 검증 함수
  bool _isValidMp4(Uint8List data) {
    if (data.length < 12) return false;

    // MP4 파일 시그니처 확인
    // 'ftyp' 문자열이 4-7 바이트에 있어야 함
    final signature = String.fromCharCodes(data.sublist(4, 8));
    return signature == 'ftyp';
  }

  // 앱 에셋의 샘플 비디오 초기화
  Future<void> _initializeAssetVideo(String assetPath) async {
    try {
      _controller = VideoPlayerController.asset(assetPath);
      await _controller!.initialize();
      _stopLoadingAnimation();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _controller!.play();
      }
    } catch (e) {
      debugPrint('❌ 샘플 비디오 초기화 오류: $e');
      _setErrorState('샘플 비디오를 로드할 수 없습니다: $e');
    }
  }

  Future<void> _initializePlayer(File videoFile) async {
    try {
      // 컨트롤러 초기화
      _controller = VideoPlayerController.file(videoFile);

      await _controller!.initialize();

      _stopLoadingAnimation();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _controller!.play();
      }
    } catch (e) {
      debugPrint('❌ 비디오 초기화 오류: $e');
      _stopLoadingAnimation();
      // 비디오 파일 삭제 (손상된 파일일 수 있음)
      try {
        await videoFile.delete();
        debugPrint('🗑️ 손상된 비디오 파일 삭제: ${videoFile.path}');
      } catch (e) {
        debugPrint('⚠️ 파일 삭제 실패: $e');
      }

      // 샘플 비디오로 대체 시도
      try {
        debugPrint('🔄 샘플 비디오로 대체합니다...');
        _isAssetVideo = true;
        await _initializeAssetVideo('assets/videos/sample.mp4');
        return;
      } catch (assetError) {
        debugPrint('❌ 샘플 비디오 대체 실패: $assetError');
        if (mounted) {
          _setErrorState('비디오 파일이 손상되었거나 재생할 수 없는 형식입니다.');
        }
      }
    }
  }

  // 오류 상태 설정 통합 메서드
  void _setErrorState(String message) {
    _stopLoadingAnimation();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isAssetVideo ? '샘플 영상 (원본 없음)' : '이상행동 영상',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'LGSmartUI',
            fontSize: 18,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    _loadingText,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'LGSmartUI',
                    ),
                  ),
                ],
              )
            : _hasError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'LGSmartUI',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _hasError = false;
                            _isAssetVideo = false;
                          });
                          _startLoadingAnimation();
                          _loadVideo();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('다시 시도'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          '돌아가기',
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'LGSmartUI',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '참고: 일부 이벤트는 영상이 저장되지 않을 수 있습니다.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'LGSmartUI',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : _controller != null ? Stack(
                    children: [
                      // 1) 비디오
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),

                      // 2) Play/Pause Overlay
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller!.value.isPlaying
                                  ? _controller!.pause()
                                  : _controller!.play();
                            });
                          },
                          child: Center(
                            child: ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: _controller!,
                              builder: (context, value, child) {
                                return AnimatedOpacity(
                                  opacity: value.isPlaying ? 0.0 : 0.8,
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // 3) 하단 컨트롤
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: Colors.black54,
                          child: Column(
                            children: [
                              // 3-1) 진행 바
                              ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: _controller!,
                                builder: (context, value, child) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Text(
                                          _formatDuration(value.position),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: value.position.inMilliseconds.toDouble(),
                                            min: 0.0,
                                            max: value.duration.inMilliseconds.toDouble(),
                                            onChanged: (newValue) {
                                              final Duration newPosition = Duration(
                                                milliseconds: newValue.round(),
                                              );
                                              _controller!.seekTo(newPosition);
                                            },
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(value.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // 3-2) 컨트롤 버튼
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10, color: Colors.white),
                                    onPressed: () {
                                      final newPosition = _controller!.value.position -
                                          const Duration(seconds: 10);
                                      _controller!.seekTo(newPosition);
                                    },
                                  ),
                                  IconButton(
                                    icon: ValueListenableBuilder<VideoPlayerValue>(
                                      valueListenable: _controller!,
                                      builder: (context, value, child) {
                                        return Icon(
                                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 32,
                                        );
                                      },
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _controller!.value.isPlaying
                                            ? _controller!.pause()
                                            : _controller!.play();
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10, color: Colors.white),
                                    onPressed: () {
                                      final newPosition = _controller!.value.position +
                                          const Duration(seconds: 10);
                                      _controller!.seekTo(newPosition);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 샘플 비디오일 경우 표시
                      if (_isAssetVideo)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              '샘플 영상',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'LGSmartUI',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ) : const Center(
                    child: Text(
                      '비디오를 로드할 수 없습니다',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'LGSmartUI',
                      ),
                    ),
                  ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}