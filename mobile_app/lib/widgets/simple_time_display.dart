import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

/// 大字体时间显示 - 高端洁净风格
class SimpleTimeDisplay extends StatefulWidget {
  const SimpleTimeDisplay({super.key});

  @override
  State<SimpleTimeDisplay> createState() => _SimpleTimeDisplayState();
}

class _SimpleTimeDisplayState extends State<SimpleTimeDisplay> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  // 配色方案
  static const Color _timeColor = Color(0xFF546E7A); // 深蓝灰色

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm', 'zh_CN');
    
    return Text(
      timeFormat.format(_currentTime),
      style: const TextStyle(
        fontSize: 96,
        fontWeight: FontWeight.w600,
        color: _timeColor,
        letterSpacing: -2,
        height: 1.0,
      ),
    );
  }
}
