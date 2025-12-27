import 'package:flutter/material.dart';
import 'dart:async';

/// SOS紧急按钮 - 高端洁净风格
class SosButton extends StatefulWidget {
  final VoidCallback onSosTriggered;
  final int longPressDuration;

  const SosButton({
    super.key,
    required this.onSosTriggered,
    this.longPressDuration = 3,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  Timer? _pressTimer;
  bool _isPressing = false;
  int _pressDuration = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 配色方案
  static const Color _buttonColor = Color(0xFFD32F2F); // 红色
  static const Color _pressedColor = Color(0xFFB71C1C);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressing = true;
      _pressDuration = 0;
    });
    _pulseController.repeat(reverse: true);

    _pressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _pressDuration++;
        });

        if (_pressDuration >= widget.longPressDuration) {
          _pressTimer?.cancel();
          _pulseController.stop();
          widget.onSosTriggered();
          setState(() {
            _isPressing = false;
            _pressDuration = 0;
          });
        }
      }
    });
  }

  void _onTapUp(TapUpDetails details) {
    _pressTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isPressing = false;
      _pressDuration = 0;
    });
  }

  void _onTapCancel() {
    _pressTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isPressing = false;
      _pressDuration = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPressing ? _pulseAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 160,
                margin: const EdgeInsets.only(left: 12, right: 24),
                decoration: BoxDecoration(
                  color: _isPressing ? _pressedColor : _buttonColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _buttonColor.withOpacity(_isPressing ? 0.3 : 0.4),
                      spreadRadius: 0,
                      blurRadius: _isPressing ? 12 : 16,
                      offset: Offset(0, _isPressing ? 4 : 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SOS文字
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _isPressing ? 40 : 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    // 倒计时显示
                    if (_isPressing && _pressDuration > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${widget.longPressDuration - _pressDuration}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '长按${widget.longPressDuration}秒',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
