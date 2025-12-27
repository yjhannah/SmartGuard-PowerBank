import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class LargeTimeDisplay extends StatefulWidget {
  const LargeTimeDisplay({super.key});

  @override
  State<LargeTimeDisplay> createState() => _LargeTimeDisplayState();
}

class _LargeTimeDisplayState extends State<LargeTimeDisplay> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateTime();
    // 每秒更新一次
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年MM月dd日', 'zh_CN');
    final timeFormat = DateFormat('HH:mm:ss', 'zh_CN');
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 日期
        Text(
          dateFormat.format(_currentTime),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.normal,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        // 时间（超大字体）
        Text(
          timeFormat.format(_currentTime),
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

