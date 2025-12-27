import 'package:flutter/material.dart';

/// 一键呼叫按钮 - 高端洁净风格
class CallButton extends StatefulWidget {
  final VoidCallback onPressed;

  const CallButton({
    super.key,
    required this.onPressed,
  });

  @override
  State<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<CallButton> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  // 配色方案
  static const Color _buttonColor = Color(0xFF2E7D32); // 深绿色
  static const Color _pressedColor = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 160,
          margin: const EdgeInsets.only(left: 24, right: 12),
          decoration: BoxDecoration(
            color: _isPressed ? _pressedColor : _buttonColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _buttonColor.withOpacity(_isPressed ? 0.2 : 0.35),
                spreadRadius: 0,
                blurRadius: _isPressed ? 8 : 16,
                offset: Offset(0, _isPressed ? 4 : 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 电话图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.phone,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Call',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
