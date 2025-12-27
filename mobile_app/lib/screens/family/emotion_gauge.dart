import 'package:flutter/material.dart';
import '../../core/network/api_service.dart';

class EmotionGauge extends StatefulWidget {
  final String patientId;

  const EmotionGauge({super.key, required this.patientId});

  @override
  State<EmotionGauge> createState() => _EmotionGaugeState();
}

class _EmotionGaugeState extends State<EmotionGauge> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _emotion;
  bool _isLoading = true;

  // 配色方案
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);
  static const Color _accentBlue = Color(0xFF90CAF9);

  @override
  void initState() {
    super.initState();
    _loadEmotion();
  }

  Future<void> _loadEmotion() async {
    try {
      final response = await _apiService.get('/health-report/emotion/${widget.patientId}');
      if (mounted) {
        setState(() {
          _emotion = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getEmotionColor() {
    if (_emotion == null) return _hintColor;
    final level = _emotion!['emotion_level'] as String?;
    if (level == 'positive') return const Color(0xFF66BB6A);
    if (level == 'neutral') return const Color(0xFFFFCA28);
    return const Color(0xFFFFB74D);
  }

  double _getEmotionValue() {
    if (_emotion == null) return 0.75;
    final score = _emotion!['score'] as num?;
    return (score ?? 75) / 100;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '情绪监测',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
                  ),
                ),
              )
            else
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: EmotionGaugePainter(
                      color: _getEmotionColor(),
                      value: _getEmotionValue(),
                      backgroundColor: _hintColor.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmotionGaugePainter extends CustomPainter {
  final Color color;
  final double value;
  final Color backgroundColor;

  EmotionGaugePainter({
    required this.color,
    required this.value,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 12.0;

    // 背景圆环
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 进度圆环
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -90 * 3.14159 / 180;
    final sweepAngle = value * 360 * 3.14159 / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant EmotionGaugePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.value != value ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
