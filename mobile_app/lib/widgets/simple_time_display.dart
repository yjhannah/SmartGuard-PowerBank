import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

/// 简单时间显示（只显示时间，不显示日期）
class SimpleTimeDisplay extends StatefulWidget {
  const SimpleTimeDisplay({super.key});

  @override
  State<SimpleTimeDisplay> createState() => _SimpleTimeDisplayState();
}

class _SimpleTimeDisplayState extends State<SimpleTimeDisplay> {
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
    final timeFormat = DateFormat('HH:mm', 'zh_CN');
    
    return Text(
      timeFormat.format(_currentTime),
      style: const TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        letterSpacing: 2,
      ),
    );
  }
}

