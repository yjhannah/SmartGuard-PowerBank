import 'package:flutter/material.dart';

/// 视频预览占位Widget
/// 在Web平台上显示一个占位符，实际的摄像头预览需要通过平台特定实现
class VideoPreviewWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final bool isActive;
  final String? statusText;
  final VoidCallback? onTap;

  const VideoPreviewWidget({
    super.key,
    this.width,
    this.height,
    this.isActive = false,
    this.statusText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.green : Colors.grey.shade600,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // 背景图案
            Center(
              child: Icon(
                isActive ? Icons.videocam : Icons.videocam_off,
                size: 48,
                color: isActive ? Colors.green.withOpacity(0.5) : Colors.grey.shade700,
              ),
            ),
            // 状态指示器
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 状态文本
            if (statusText != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
