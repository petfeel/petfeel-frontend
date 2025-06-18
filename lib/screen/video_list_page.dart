// video_list_page.dart
// lib/screen/video_list_page.dart
//
// 영상 목록 · 재생 · 삭제 · 이름 변경(UI + 서버 호출) – 2025-06-07 수정판
// Skeleton Loading 적용, Shimmer 사용

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

import 'package:test123/utils/api_endpoints.dart';
import 'package:test123/utils/video_storage.dart';
import 'video_player_page.dart';   // ▶ 영상 재생 화면

class VideoListPage extends StatefulWidget {
  const VideoListPage({Key? key}) : super(key: key);

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  bool _isLoading = true;
  List<Map<String, String>> get _videoItems => VideoStorage.items;

  static const TextStyle _popupTextStyle =
  TextStyle(fontFamily: 'LGSmartUI', fontSize: 14);

  @override
  void initState() {
    super.initState();
    VideoStorage.items = [];
    _fetchVideoList();
  }

  Future<void> _fetchVideoList() async {
    final uri = Uri.parse(ApiEndpoints.listVideos);
    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final decoded = utf8.decode(resp.bodyBytes);
      final body = jsonDecode(decoded) as Map<String, dynamic>;
      final itemsJson = (body['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      setState(() {
        VideoStorage.items = itemsJson.map((e) {
          final title = e['title'] as String? ?? '';
          final encoded = Uri.encodeComponent(title);
          return {
            'id': e['id'] as String? ?? '',
            'title': title,
            'channel': e['channel'] as String? ?? '',
            'thumbnail': e['thumbnail'] as String? ?? '',
            'url': ApiEndpoints.playFile.replaceFirst('{filename}', encoded),
          };
        }).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('영상 목록 로드 실패 (${resp.statusCode})', Colors.red);
    }
  }

  Future<void> _renameVideo(int index) async {
    final rawTitle = _videoItems[index]['title'] ?? '';
    final initialName = rawTitle.replaceAll(RegExp(r'\.mp4$'), '');
    final controller = TextEditingController(text: initialName);

    final newBase = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '새 이름',
            isDense: true,
            contentPadding:
            EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          style: const TextStyle(fontFamily: 'LGSmartUI', fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: _popupTextStyle),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(
              '저장',
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

    if (newBase == null || newBase.isEmpty) return;

    final newName = '$newBase.mp4';
    final uri = Uri.parse(ApiEndpoints.recordRename);
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'video_name': newName}),
    );

    if (resp.statusCode == 200) {
      setState(() {
        _videoItems[index]['title'] = newName;
        final enc = Uri.encodeComponent(newName);
        _videoItems[index]['url'] =
            ApiEndpoints.playFile.replaceFirst('{filename}', enc);
      });
      _showSnackBar('이름이 변경되었습니다.', Colors.green);
    } else {
      _showSnackBar('이름 변경 실패 (${resp.statusCode})', Colors.red);
    }
  }

  Future<void> _deleteVideo(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '삭제 확인',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '정말로 이 영상을 삭제하시겠습니까?',
          style: TextStyle(fontFamily: 'LGSmartUI', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: _popupTextStyle),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
    if (confirmed != true) return;

    final id = _videoItems[index]['id'] ?? '';
    if (id.isEmpty) return;

    final uri = Uri.parse(
      ApiEndpoints.deleteVideo.replaceFirst('{id}', id),
    );
    final resp = await http.delete(uri);

    if (resp.statusCode == 200) {
      setState(() => _videoItems.removeAt(index));
      _showSnackBar('삭제되었습니다.', Colors.green);
    } else {
      _showSnackBar('삭제 실패 (${resp.statusCode})', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          '영상 목록',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? _buildSkeletonList()
          : _videoItems.isEmpty
          ? const Center(
        child: Text(
          '녹화된 영상이 없습니다.',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _videoItems.length,
        itemBuilder: (_, i) => _buildItem(i),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 7,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Row(
            children: [
              Container(width: 120, height: 68, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 12, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 24, height: 24, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int i) {
    final v = _videoItems[i];
    final rawTitle = v['title'] ?? '';
    final displayTitle = rawTitle.replaceAll(RegExp(r'\.mp4$'), '');
    final thumbnail = v['thumbnail'] ?? '';
    final videoUrl = v['url'] ?? '';

    return GestureDetector(
      onTap: videoUrl.isNotEmpty
          ? () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(videoUrl: videoUrl),
        ),
      )
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 120,
                height: 68,
                child: thumbnail.isNotEmpty
                    ? Image.network(
                  thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _thumbFallback(),
                )
                    : _thumbFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v['channel'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: Colors.white,
              icon: const Icon(Icons.more_vert, color: Colors.black54),
              onSelected: (val) =>
              val == 'rename' ? _renameVideo(i) : _deleteVideo(i),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
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
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() => Container(
    width: 120,
    height: 68,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.videocam_off, size: 32, color: Colors.grey),
  );
}
