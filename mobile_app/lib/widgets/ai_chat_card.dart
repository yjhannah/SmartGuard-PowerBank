import 'package:flutter/material.dart';

/// AI聊天卡片（匹配图片样式）
class AiChatCard extends StatelessWidget {
  final VoidCallback onTap;

  const AiChatCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 熊图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF87CEEB), // 浅蓝色
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // 文本
            const Expanded(
              child: Text(
                'Chat with AI Agent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

