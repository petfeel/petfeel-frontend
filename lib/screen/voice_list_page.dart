// lib/screen/voice_list_page.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as p;            // ← 추가
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

import 'package:test123/utils/api_endpoints.dart';
import 'package:test123/utils/voice_storage.dart';

class VoiceListPage extends StatefulWidget {
  const VoiceListPage({Key? key}) : super(key: key);

  @override
  State<VoiceListPage> createState() => _VoiceListPageState();
}

class _VoiceListPageState extends State<VoiceListPage> {
  static const TextStyle _dialog14 = TextStyle(
    fontFamily: 'LGSmartUI',
    fontSize: 14,
  );
  static const TextStyle _snack14 = TextStyle(
    fontFamily: 'LGSmartUI',
    fontSize: 14,
    color: Colors.white,
  );

  late final FlutterSoundPlayer _audioPlayer;
  bool _playerInitialized = false;

  bool _isPlaying = false;
  String? _currentPlayingPath;
  Duration _currentPosition = Duration.zero;
  Timer? _positionTimer; // 위치 업데이트용 타이머

  void _startProgressTimer([Duration? total]) {
    _positionTimer?.cancel();
    _currentPosition = Duration.zero;
    _positionTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (!mounted) return;
          setState(() => _currentPosition += const Duration(milliseconds: 200));

          // 전체 길이를 알면, 재생 완료 시 자동 종료
          if (total != null && _currentPosition >= total) {
            _stopProgressTimer(finished: true);
          }
        });
  }

  void _stopProgressTimer({bool finished = false}) {
    _positionTimer?.cancel();
    _positionTimer = null;
    setState(() {
      _currentPosition = Duration.zero;
      if (finished) {         // 재생이 끝났을 때 ▶ 아이콘으로 복귀
        _isPlaying = false;
        _currentPlayingId = null;
      }
    });
  }


  /// 서버 재생 모드 플래그
  bool _serverPlayMode = true; // 기본값 true로 설정 (서버에서 재생)
  String? _currentPlayingId; // 현재 재생 중인 파일 ID

  /// 로딩 플래그
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = FlutterSoundPlayer();
    _initPlayer();
    Future.delayed(const Duration(seconds: 1), _fetchVoiceList);
  }

  Future<void> _initPlayer() async {
    await _audioPlayer.openPlayer();
    _playerInitialized = true;
    await _audioPlayer.setSubscriptionDuration(const Duration(milliseconds: 200));
    _audioPlayer.onProgress?.listen((event) {
      debugPrint('⏱ onProgress: ${event.position}');
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    if (_playerInitialized) _audioPlayer.closePlayer();
    super.dispose();
  }

  Future<void> _fetchVoiceList() async {
    setState(() => _isLoading = true);

    final uri = Uri.parse(ApiEndpoints.listVoices);
    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final decoded = utf8.decode(resp.bodyBytes);
      final body = jsonDecode(decoded) as Map<String, dynamic>;
      final data = body['items'] as List<dynamic>;

      final newList = data.map((e) {
        final id = e['id'].toString();
        final rawTitle = e['title'] as String? ?? '';
        // 확장자 제거
        final displayTitle = p.basenameWithoutExtension(rawTitle);
        return {
          'id': id,
          'title': displayTitle,
          'subtitle': e['subtitle'] as String? ?? '',
          'duration': e['duration'] as String? ?? '00:00',
          'filePath': ApiEndpoints.playVoice.replaceFirst('{id}', id),
        };
      }).toList();

      setState(() {
        VoiceStorage.items
          ..clear()
          ..addAll(newList);
        _isLoading = false;
      });
    } else {
      _showSnackBar('음성 목록 로드 실패 (${resp.statusCode})', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlayPause(String uri, String id) async {
    // 서버 재생 모드
    if (_serverPlayMode) {
      return _playOnServer(id);
    }

    // 이하는 로컬 재생 모드 (기존 코드)
    if (!_playerInitialized) return;

    if (_isPlaying && _currentPlayingPath == uri) {
      await _audioPlayer.stopPlayer();
      _positionTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _currentPlayingPath = null;
        _currentPosition = Duration.zero;
      });
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.stopPlayer();
      _positionTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _currentPlayingPath = null;
        _currentPosition = Duration.zero;
      });
    }

    try {
      await _audioPlayer.startPlayer(
        fromURI: uri,
        codec: Codec.aacADTS,
        whenFinished: () {
          _positionTimer?.cancel();
          setState(() {
            _isPlaying = false;
            _currentPlayingPath = null;
            _currentPosition = Duration.zero;
          });
        },
      );

      // 타이머로 위치 직접 증가
      _positionTimer?.cancel();
      _positionTimer = Timer.periodic(
        const Duration(milliseconds: 200),
            (_) {
          setState(() {
            _currentPosition += const Duration(milliseconds: 200);
          });
        },
      );

      setState(() {
        _isPlaying = true;
        _currentPlayingPath = uri;
        _currentPosition = Duration.zero;
      });
    } catch (e) {
      _showSnackBar('재생 중 오류 발생: $e', Colors.red);
    }
  }

  // 서버에서 음성 재생 메서드
  Future<void> _playOnServer(String id) async {
    try {
      // ――― 같은 파일 다시 누르면 중지 ―――
      if (_isPlaying && _currentPlayingId == id) {
        _stopProgressTimer();
        setState(() {
          _isPlaying = false;
          _currentPlayingId = null;
        });
        _showSnackBar('재생 중지됨', Colors.green);
        return;
      }

      // ――― 다른 파일이 재생 중이었으면 초기화 ―――
      if (_isPlaying) {
        _stopProgressTimer();
        setState(() {
          _isPlaying = false;
          _currentPlayingId = null;
        });
      }

      // ――― 서버 재생 요청 ―――
      final url =
      Uri.parse(ApiEndpoints.playVoiceOnServer.replaceFirst('{id}', id));
      final resp = await http.post(url);

      if (resp.statusCode != 200) {
        _showSnackBar('서버 오류: ${resp.statusCode}', Colors.red);
        return;
      }

      final result = json.decode(utf8.decode(resp.bodyBytes));
      if (result['success'] != true) {
        _showSnackBar('재생 실패: ${result['message']}', Colors.red);
        return;
      }

      // ――― 응답 OK → 재생 상태 세팅 ―――
// ① 리스트에서 길이 가져오기
      final item =
      VoiceStorage.items.firstWhere((e) => e['id'] == id, orElse: () => {});
      final durStr = (item['duration'] ?? '00:00') as String;

// ② "00:00" 이면 길이를 모르는 상태로 간주 → totalDur = null
      Duration? totalDur;
      try {
        final parts = durStr.split(':');
        totalDur = Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
        if (totalDur.inSeconds == 0) totalDur = null;
      } catch (_) {
        totalDur = null; // 파싱 실패 시에도 null
      }

// ③ 진행 타이머 시작
      _startProgressTimer(totalDur);

      setState(() {
        _isPlaying = true;
        _currentPlayingId = id;
      });


      // 예외적으로 길이를 몰랐을 때 안전 종료(30초)
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _isPlaying && _currentPlayingId == id) {
          _stopProgressTimer();
          setState(() {
            _isPlaying = false;
            _currentPlayingId = null;
          });
        }
      });
    } catch (e) {
      _showSnackBar('재생 요청 오류: $e', Colors.red);
    }
  }


  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _showRenameDialog(int index) async {
    final controller = TextEditingController(
      text: VoiceStorage.items[index]['title'] ?? '',
    );
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '이름 변경',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '새 이름을 입력하세요',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
            focusedBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
          ),
          style: const TextStyle(fontFamily: 'LGSmartUI', fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
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
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                Navigator.of(ctx).pop();
                _showSnackBar('이름을 입력해주세요.', Colors.red);
                return;
              }
              final id = VoiceStorage.items[index]['id']!;
              final uri = Uri.parse(
                ApiEndpoints.renameVoice.replaceFirst('{id}', id),
              );
              final resp = await http.patch(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'title': newName}),
              );
              Navigator.of(ctx).pop();
              if (resp.statusCode == 200) {
                setState(() => VoiceStorage.items[index]['title'] = newName);
                _showSnackBar('이름이 변경되었습니다.', Colors.green);
              } else {
                _showSnackBar('서버 오류: ${resp.statusCode}', Colors.red);
              }
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

  Future<void> _showDeleteDialog(int index) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '삭제 확인',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text('이 녹음을 삭제하시겠습니까?', style: _dialog14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
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
            onPressed: () async {
              final id = VoiceStorage.items[index]['id']!;
              final uri = Uri.parse(
                ApiEndpoints.deleteVoice.replaceFirst('{id}', id),
              );
              final resp = await http.delete(uri);
              Navigator.of(ctx).pop();
              if (resp.statusCode == 200) {
                if (_isPlaying && _currentPlayingPath == VoiceStorage.items[index]['filePath']) {
                  await _audioPlayer.stopPlayer();
                  _isPlaying = false;
                  _currentPlayingPath = null;
                  _currentPosition = Duration.zero;
                }
                setState(() => VoiceStorage.items.removeAt(index));
                _showSnackBar('삭제되었습니다.', Colors.green);
              } else {
                _showSnackBar('삭제 실패: ${resp.statusCode}', Colors.red);
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(
                fontFamily: 'LGSmartUI',
                fontSize: 14,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _snack14),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = VoiceStorage.items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '음성 목록',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6.0), // ← 우측 패딩 추가로 위치 조정
            child: IconButton(
              icon: Icon(
                _serverPlayMode ? Icons.computer : Icons.smartphone,
                color: _serverPlayMode ? Colors.teal : Colors.black54,
              ),
              onPressed: () {
                setState(() {
                  _serverPlayMode = !_serverPlayMode;

                  if (_isPlaying) {
                    if (!_serverPlayMode && _audioPlayer.isPlaying) {
                      _audioPlayer.stopPlayer();
                    }
                    _isPlaying = false;
                    _currentPlayingPath = null;
                    _currentPlayingId = null;
                    _currentPosition = Duration.zero;
                    _positionTimer?.cancel();
                  }
                });
                _showSnackBar(
                  _serverPlayMode ? '서버 재생 모드' : '앱 재생 모드',
                  _serverPlayMode ? Colors.teal : Colors.blueGrey,
                );
              },
              tooltip: _serverPlayMode ? '서버 재생 모드' : '앱 재생 모드',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 9,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (_, __) => const VoiceSkeletonCard(),
      )
          : items.isEmpty
          ? const Center(
        child: Text(
          '저장된 녹음이 없습니다.',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      )
          : ListView.builder(
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final title = item['title']!;
          final subtitle = item['subtitle']!;
          final staticDur = item['duration']!;
          final uri = item['filePath']!;
          final id = item['id']!;

          // 재생 상태 확인 (재생 모드에 따라 다른 방식으로)
          final bool isPlayingThis = _serverPlayMode
              ? (_isPlaying && _currentPlayingId == id)
              : (_isPlaying && _currentPlayingPath == uri);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _togglePlayPause(uri, id),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlayingThis ? Icons.pause : Icons.play_arrow,
                      color: _serverPlayMode ? Colors.teal : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'LGSmartUI',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontFamily: 'LGSmartUI',
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          if (_serverPlayMode && isPlayingThis)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '서버 재생 중',
                                  style: TextStyle(
                                    fontFamily: 'LGSmartUI',
                                    fontSize: 10,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  isPlayingThis ? _formatDuration(_currentPosition) : staticDur,
                  style: const TextStyle(
                    fontFamily: 'LGSmartUI',
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert, color: Colors.black54),
                  onSelected: (value) async {
                    if (value == 'rename') {
                      await _showRenameDialog(index);
                    } else {
                      await _showDeleteDialog(index);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('삭제', style: TextStyle(
                        fontFamily: 'LGSmartUI',
                        fontSize: 14,
                        color: Colors.red,
                      )),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VoiceSkeletonCard extends StatelessWidget {
  const VoiceSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: double.infinity, height: 14, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 100, height: 12, color: Colors.white),
              ]),
            ),
            const SizedBox(width: 12),
            Container(width: 36, height: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
