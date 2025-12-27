import 'package:flutter/material.dart';

/// 3D小熊告警动画对话框
/// 显示放大缩小的动画效果，不显示文字
/// 
/// 使用说明：
/// - message: 用于语音播报，不在对话框中显示
/// - onDismiss: 对话框关闭时的回调
/// - duration: 对话框显示时长（从显示开始计算）
/// - autoCloseAfterSpeech: 如果为true，会在语音完成后延迟5秒关闭
/// - showCloseButton: 是否显示关闭按钮（默认true）
/// - tapToDismiss: 是否点击可关闭（默认true）
/// - maxDuration: 最大显示时长，安全超时（默认60秒）
class BearAlertDialog extends StatefulWidget {
  final String? message; // 用于语音播报，不显示
  final VoidCallback? onDismiss;
  final Duration duration;
  final bool autoCloseAfterSpeech; // 是否在语音完成后自动关闭
  final bool showCloseButton; // 是否显示关闭按钮
  final bool tapToDismiss; // 是否点击可关闭
  final Duration maxDuration; // 最大显示时长（安全超时）

  const BearAlertDialog({
    super.key,
    this.message,
    this.onDismiss,
    this.duration = const Duration(seconds: 5),
    this.autoCloseAfterSpeech = false, // 默认使用固定时长
    this.showCloseButton = true, // 默认显示关闭按钮
    this.tapToDismiss = true, // 默认点击可关闭
    this.maxDuration = const Duration(seconds: 60), // 默认最大60秒
  });

  @override
  State<BearAlertDialog> createState() => _BearAlertDialogState();
}

class _BearAlertDialogState extends State<BearAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isClosed = false; // 防止重复关闭

  @override
  void initState() {
    super.initState();
    
    // 创建动画控制器
    // 动画时长：1秒完成一次放大或缩小，总共2秒完成一个完整循环（放大->缩小->放大）
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000), // 单次动画时长
      vsync: this,
    );
    
    // 创建缩放动画：从0.8到1.2，循环播放
    // 0.8 -> 1.2 (放大) -> 0.8 (缩小) -> 1.2 (放大) ... 无限循环
    _scaleAnimation = Tween<double>(
      begin: 0.8,  // 最小缩放
      end: 1.2,    // 最大缩放
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut, // 缓入缓出，使动画更平滑
      ),
    );
    
    // 开始动画（重复反向播放）
    // repeat(reverse: true) 会创建：放大->缩小->放大->缩小...的循环效果
    _controller.repeat(reverse: true);
    
    // 自动关闭逻辑
    if (widget.autoCloseAfterSpeech) {
      // 如果设置了autoCloseAfterSpeech，等待外部调用closeAfterSpeech()
      debugPrint('[BearAlertDialog] 等待语音完成后关闭（最大${widget.maxDuration.inSeconds}秒）');
      
      // 添加安全超时：最多显示 maxDuration，防止语音异常导致对话框永远不关闭
      Future.delayed(widget.maxDuration, () {
        if (!_isClosed) {
          debugPrint('[BearAlertDialog] ⚠️ 达到最大显示时长，强制关闭');
          _closeDialog();
        }
      });
    } else {
      // 使用固定时长自动关闭
      Future.delayed(widget.duration, () {
        _closeDialog();
      });
    }
  }
  
  /// 关闭对话框
  void _closeDialog() {
    if (mounted && !_isClosed) {
      _isClosed = true;
      _controller.stop();
      Navigator.of(context).pop();
      widget.onDismiss?.call();
      debugPrint('[BearAlertDialog] 对话框已关闭');
    }
  }
  
  /// 在语音完成后关闭（延迟5秒）
  void closeAfterSpeech() {
    if (_isClosed) return;
    debugPrint('[BearAlertDialog] 语音播报完成，5秒后自动关闭');
    Future.delayed(const Duration(seconds: 5), () {
      _closeDialog();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 动画小熊图片（可点击关闭）
          GestureDetector(
            onTap: widget.tapToDismiss ? () {
              debugPrint('[BearAlertDialog] 用户点击关闭');
              _closeDialog();
            } : null,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/3d bear.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // 如果3D小熊图片不存在，使用备用图片
                        return Image.asset(
                          'assets/images/bear_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // 如果备用图片也不存在，显示图标
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 100,
                                color: Colors.blue,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 关闭按钮（右上角）
          if (widget.showCloseButton)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  debugPrint('[BearAlertDialog] 用户点击关闭按钮');
                  _closeDialog();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ),
            ),
          
          // 底部提示文字
          Positioned(
            bottom: -50,
            child: Text(
              '点击可关闭',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

