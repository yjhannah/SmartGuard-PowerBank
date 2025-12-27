import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'dart:ui' as ui if (dart.library.html) 'dart:ui';

/// Web平台的视频预览Widget
class VideoPreviewWidget extends StatefulWidget {
  final html.VideoElement? videoElement;
  final double? width;
  final double? height;

  const VideoPreviewWidget({
    super.key,
    this.videoElement,
    this.width,
    this.height,
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  String? _viewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && widget.videoElement != null) {
      _viewId = 'video-preview-${DateTime.now().millisecondsSinceEpoch}';
      // 注册HTML元素
      ui.platformViewRegistry.registerViewFactory(
        _viewId!,
        (int viewId) => widget.videoElement!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _viewId == null || widget.videoElement == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: const Center(
          child: Text(
            '视频预览不可用',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewId!),
    );
  }
}

