import 'package:flutter/material.dart';
import 'dart:async';

class SosButton extends StatefulWidget {
  final VoidCallback onSosTriggered;
  final int longPressDuration; // 长按持续时间（秒）

  const SosButton({
    super.key,
    required this.onSosTriggered,
    this.longPressDuration = 3,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  Timer? _pressTimer;
  bool _isPressing = false;
  int _pressDuration = 0;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressing = true;
      _pressDuration = 0;
    });

    // 开始计时
    _pressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _pressDuration++;
      });

      // 达到长按时间，触发SOS
      if (_pressDuration >= widget.longPressDuration) {
        _pressTimer?.cancel();
        widget.onSosTriggered();
        setState(() {
          _isPressing = false;
          _pressDuration = 0;
        });
      }
    });
  }

  void _onTapUp(TapUpDetails details) {
    _pressTimer?.cancel();
    setState(() {
      _isPressing = false;
      _pressDuration = 0;
    });
  }

  void _onTapCancel() {
    _pressTimer?.cancel();
    setState(() {
      _isPressing = false;
      _pressDuration = 0;
    });
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _isPressing ? Colors.red[700] : Colors.red,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isPressing && _pressDuration > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${widget.longPressDuration - _pressDuration}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

