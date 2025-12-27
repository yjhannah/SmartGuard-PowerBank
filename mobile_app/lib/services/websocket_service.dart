import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config/app_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  String? _userId;

  Stream<Map<String, dynamic>>? get messageStream =>
      _messageController?.stream;

  Future<void> connect(String userId) async {
    _userId = userId;
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsBaseUrl}/$userId'),
      );

      _messageController = StreamController<Map<String, dynamic>>.broadcast();

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _messageController?.add(data);
          } catch (e) {
            // 忽略解析错误
          }
        },
        onError: (error) {
          _messageController?.addError(error);
        },
        onDone: () {
          _messageController?.close();
        },
      );
    } catch (e) {
      throw Exception('WebSocket连接失败: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _messageController?.close();
    _channel = null;
    _messageController = null;
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }
}

