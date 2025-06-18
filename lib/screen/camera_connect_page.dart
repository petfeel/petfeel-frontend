// lib/screen/camera_connect_page.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:test123/screen/profile_liston_page.dart';

class CameraConnectPage extends StatefulWidget {
  final bool isConnected;
  final bool isRecording;

  const CameraConnectPage({
    super.key,
    this.isConnected = true,
    this.isRecording = true,
  });

  @override
  State<CameraConnectPage> createState() => _CameraConnectPageState();
}

class _CameraConnectPageState extends State<CameraConnectPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });
    });
  }

  void _goNext() {
    // 1) 커스텀 스타일의 스낵바 보여주기 (1초)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '카메라 연결이 완료되었습니다.',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'LGSmartUI',
          ),
        ),
        backgroundColor: Colors.green, // 성공을 의미하는 녹색
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 1),
      ),
    );

    // 2) 1초 뒤에 페이지 전환
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const ProfileListOnPage(),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
            final fade = Tween<double>(begin: 0, end: 1).animate(curved);
            final scale = Tween<double>(begin: 0.9, end: 1.0).animate(curved);
            final slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curved);

            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: SlideTransition(position: slide, child: child),
              ),
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 카메라', style: TextStyle(fontFamily: 'LGSmartUI')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemBuilder: (_, __) => const SkeletonCard(),
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemCount: 5,
        )
            : Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _goNext,
                child: _buildCameraCard(),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard() {
    const String cameraName = 'Cam 1';
    const String lastSeen = '0분 전';
    const String previewUrl = 'https://via.placeholder.com/400x300';

    const accent = Color(0xFFFF7E00);
    const shadowColor = Color(0xFF000000);
    const disabledText = Color(0xFF888888);
    const cardOfflineBg = Color(0xFFECECEC);
    const cardOfflineBorder = Color(0xFFDADADA);
    const cardOnlineBg = Color(0xFFD1D1D6);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: widget.isConnected ? cardOnlineBg : cardOfflineBg,
        borderRadius: BorderRadius.circular(12),
        border: widget.isConnected
            ? Border.all(color: Colors.transparent)
            : Border.all(color: cardOfflineBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        image: widget.isConnected
            ? const DecorationImage(
          image: NetworkImage(previewUrl),
          fit: BoxFit.cover,
          opacity: 0.25,
        )
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          if (!widget.isConnected)
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: 120,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: accent),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onPressed: () {},
                    child: const Text(
                      '원격 실행',
                      style: TextStyle(
                        fontFamily: 'LGSmartUI',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              children: [
                Text(
                  cameraName,
                  style: TextStyle(
                    fontFamily: 'LGSmartUI',
                    color: widget.isConnected ? Colors.white : disabledText,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  lastSeen,
                  style: TextStyle(
                    fontFamily: 'LGSmartUI',
                    color: widget.isConnected ? Colors.white : disabledText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Icon(
              Icons.more_vert,
              color: widget.isConnected ? Colors.white : disabledText,
            ),
          ),
          if (widget.isConnected) const Positioned.fill(child: Center(child: _LiveBadge())),
          if (widget.isConnected && widget.isRecording)
            const Positioned(bottom: 12, left: 12, child: _RecBadge()),
          if (widget.isConnected) const Positioned(bottom: 12, right: 12, child: _StatusRow()),
        ],
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          fontFamily: 'LGSmartUI',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF7E00),
        ),
      ),
    );
  }
}

class _RecBadge extends StatelessWidget {
  const _RecBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.videocam, size: 18, color: Colors.white),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'REC',
            style: TextStyle(
              fontFamily: 'LGSmartUI',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.battery_full, size: 16, color: Colors.white),
        SizedBox(width: 4),
        Text(
          '66%',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 16),
        Icon(Icons.thermostat, size: 16, color: Colors.white),
        SizedBox(width: 4),
        Text(
          '29°C',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
