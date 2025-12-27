import 'package:flutter/material.dart';

/// 小熊Logo组件 - 使用本地PNG图片
class BearLogo extends StatelessWidget {
  final double size;
  final bool withBackground;
  final Color? backgroundColor;

  const BearLogo({
    super.key,
    this.size = 80,
    this.withBackground = false,
    this.backgroundColor,
  });

  // 配色方案
  static const Color _medicalBlue = Color(0xFFE3F2FD);
  static const Color _accentBlue = Color(0xFF90CAF9);

  @override
  Widget build(BuildContext context) {
    Widget logoImage = Image.asset(
      'assets/images/bear_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // 如果图片加载失败，显示备用图标
        return _buildFallbackLogo();
      },
    );

    if (withBackground) {
      return Container(
        width: size * 1.5,
        height: size * 1.5,
        decoration: BoxDecoration(
          color: backgroundColor ?? _medicalBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accentBlue.withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(child: logoImage),
      );
    }

    return logoImage;
  }

  /// 备用Logo（当图片加载失败时）
  Widget _buildFallbackLogo() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _medicalBlue,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.favorite,
        size: size * 0.5,
        color: _accentBlue,
      ),
    );
  }
}

