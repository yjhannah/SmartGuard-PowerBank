import 'package:flutter/material.dart';

/// 用药提醒卡片 - 高端洁净风格
class MedicationCard extends StatelessWidget {
  final String time;
  final String label;

  const MedicationCard({
    super.key,
    required this.time,
    required this.label,
  });

  // 配色方案
  static const Color _cardBackground = Colors.white;
  static const Color _timeColor = Color(0xFF546E7A);
  static const Color _labelColor = Color(0xFF90A4AE);
  static const Color _pillBlue = Color(0xFF90CAF9);
  static const Color _pillWhite = Color(0xFFFAFAFA);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF546E7A).withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF546E7A).withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 3D药丸图标
          _buildPillIcon(),
          const SizedBox(width: 20),
          // 时间和标签
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: _timeColor,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _labelColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建3D药丸图标
  Widget _buildPillIcon() {
    return Container(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          // 药丸胶囊形状 - 使用自定义绘制
          CustomPaint(
            size: const Size(56, 56),
            painter: _PillPainter(
              blueColor: _pillBlue,
              whiteColor: _pillWhite,
            ),
          ),
        ],
      ),
    );
  }
}

/// 药丸绘制器 - 3D胶囊效果
class _PillPainter extends CustomPainter {
  final Color blueColor;
  final Color whiteColor;

  _PillPainter({required this.blueColor, required this.whiteColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pillWidth = size.width * 0.4;
    final pillHeight = size.height * 0.85;
    
    // 旋转角度 (-45度)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.785); // -45 degrees in radians
    
    // 绘制阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(2, 2), width: pillWidth, height: pillHeight),
      Radius.circular(pillWidth / 2),
    );
    canvas.drawRRect(shadowRect, shadowPaint);
    
    // 药丸主体
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: pillWidth, height: pillHeight),
      Radius.circular(pillWidth / 2),
    );
    
    // 蓝色部分（上半）
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(-pillWidth, -pillHeight, pillWidth * 2, pillHeight));
    final bluePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          blueColor.withOpacity(0.8),
          blueColor,
          blueColor.withOpacity(0.9),
        ],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: pillWidth, height: pillHeight));
    canvas.drawRRect(pillRect, bluePaint);
    canvas.restore();
    
    // 白色部分（下半）
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(-pillWidth, 0, pillWidth * 2, pillHeight));
    final whitePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          whiteColor.withOpacity(0.9),
          whiteColor,
          whiteColor.withOpacity(0.95),
        ],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: pillWidth, height: pillHeight));
    canvas.drawRRect(pillRect, whitePaint);
    canvas.restore();
    
    // 高光效果
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.6),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCenter(center: Offset(-pillWidth * 0.15, -pillHeight * 0.2), width: pillWidth * 0.3, height: pillHeight * 0.4));
    
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-pillWidth * 0.1, -pillHeight * 0.2), width: pillWidth * 0.25, height: pillHeight * 0.3),
      highlightPaint,
    );
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
