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

  @override
  void initState() {
    super.initState();
    _loadEmotion();
  }

  Future<void> _loadEmotion() async {
    try {
      final response = await _apiService.get('/health-report/emotion/${widget.patientId}');
      setState(() {
        _emotion = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getEmotionColor() {
    if (_emotion == null) return Colors.grey;
    final level = _emotion!['emotion_level'] as String?;
    if (level == 'positive') return Colors.green;
    if (level == 'neutral') return Colors.yellow;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '情绪监测',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: EmotionGaugePainter(_getEmotionColor()),
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

  EmotionGaugePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

