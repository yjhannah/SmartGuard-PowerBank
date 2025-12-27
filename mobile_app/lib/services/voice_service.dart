import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../core/config/app_config.dart';

/// 语音服务
/// 
/// 当前使用 flutter_tts (基于系统TTS)
/// - Android: 使用 Android TTS Engine
/// - iOS: 使用 AVSpeechSynthesizer
/// - Web: 使用 Web Speech API
/// 
/// 萌童声音实现方式：
/// 1. 当前方案：通过调整 pitch (1.4) 和 speechRate (0.45) 模拟萌童声音
/// 2. 云服务方案：使用华为云/百度云/腾讯云TTS API，提供真正的儿童声音
///    - 华为云：华小雪(女童)、华小辉(男童)
///    - 百度云：度小童(儿童声音)
///    - 腾讯云：智逍遥(儿童声音)
class VoiceService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isChildVoiceMode = false;
  List<dynamic>? _availableVoices;
  // Web平台不支持BytesSource播放，所以在Web上禁用讯飞TTS
  bool _useXunfeiTTS = !kIsWeb; // 非Web平台优先使用讯飞TTS

  Future<void> init() async {
    if (_isInitialized) return;

    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [VoiceService] ========== 初始化TTS服务 ==========');
    print('[$timestamp] [VoiceService] 运行平台: ${kIsWeb ? "Web" : "Native"}');
    print('[$timestamp] [VoiceService] 使用服务: flutter_tts (系统TTS)');
    if (kIsWeb) {
      print('[$timestamp] [VoiceService] ⚠️ Web平台: 禁用讯飞TTS，使用Web Speech API');
    }
    
    await _flutterTts.setLanguage('zh-CN');
    print('[$timestamp] [VoiceService] ✅ 语言: zh-CN');
    
    await _flutterTts.setSpeechRate(0.5);
    print('[$timestamp] [VoiceService] ✅ 语速: 0.5');
    
    await _flutterTts.setVolume(1.0);
    print('[$timestamp] [VoiceService] ✅ 音量: 1.0');
    
    await _flutterTts.setPitch(1.0);
    print('[$timestamp] [VoiceService] ✅ 音调: 1.0');

    // 尝试获取可用的声音列表（某些平台可能不支持）
    try {
      _availableVoices = await _flutterTts.getVoices;
      print('[$timestamp] [VoiceService] ✅ 可用声音列表: $_availableVoices');
    } catch (e) {
      print('[$timestamp] [VoiceService] ⚠️ 无法获取声音列表: $e');
      _availableVoices = null;
    }

    _isInitialized = true;
    print('[$timestamp] [VoiceService] ✅ TTS服务初始化完成');
    print('[$timestamp] [VoiceService] ============================================');
  }

  /// 获取可用的声音列表
  /// 
  /// 返回格式：
  /// Android: [{name: "zh-cn-x-xcf-local", locale: "zh-CN"}, ...]
  /// iOS: [{name: "Ting-Ting", locale: "zh-CN"}, ...]
  /// Web: null (不支持)
  List<dynamic>? getAvailableVoices() {
    return _availableVoices;
  }

  /// 设置为萌童声音模式
  /// 
  /// 实现方式：
  /// 1. 调整 pitch 到 1.4（提高音调，模拟儿童声音）
  /// 2. 调整 speechRate 到 0.45（降低语速，更清晰）
  /// 
  /// 注意：这是模拟效果，不是真正的儿童声音
  /// 如需真正的儿童声音，建议使用云服务TTS API
  Future<void> setChildVoiceMode(bool enabled) async {
    if (!_isInitialized) {
      await init();
    }
    
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [VoiceService] setChildVoiceMode: $enabled');
    
    _isChildVoiceMode = enabled;
    
    if (enabled) {
      // 萌童声音：提高音调（pitch），降低语速（speechRate）
      print('[$timestamp] [VoiceService] 设置萌童声音参数...');
      await _flutterTts.setPitch(1.4);  // 提高音调，更接近儿童声音
      print('[$timestamp] [VoiceService] ✅ pitch = 1.4 (已设置)');
      await _flutterTts.setSpeechRate(0.45);  // 降低语速，更清晰
      print('[$timestamp] [VoiceService] ✅ speechRate = 0.45 (已设置)');
      print('[$timestamp] [VoiceService] 萌童声音模式已启用');
    } else {
      // 恢复正常声音
      print('[$timestamp] [VoiceService] 恢复默认声音参数...');
      await _flutterTts.setPitch(1.0);
      print('[$timestamp] [VoiceService] ✅ pitch = 1.0 (已恢复)');
      await _flutterTts.setSpeechRate(0.5);
      print('[$timestamp] [VoiceService] ✅ speechRate = 0.5 (已恢复)');
      print('[$timestamp] [VoiceService] 默认声音模式已恢复');
    }
  }

  /// 设置特定的声音（如果平台支持）
  /// 
  /// 参数：
  /// - voiceName: 声音名称，例如 "zh-cn-x-xcf-local" (Android)
  /// 
  /// 注意：不同平台的声音名称格式不同
  Future<void> setVoice(String? voiceName) async {
    if (!_isInitialized) {
      await init();
    }
    
    if (voiceName != null) {
      try {
        await _flutterTts.setVoice({"name": voiceName, "locale": "zh-CN"});
        print('[VoiceService] 设置声音: $voiceName');
      } catch (e) {
        print('[VoiceService] 设置声音失败: $e');
      }
    }
  }

  /// 播报文本，返回Future在语音播报完成后完成
  /// 
  /// 优先使用讯飞TTS（真正的萌童声音），失败时回退到flutter_tts
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }
    
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [VoiceService] ========== TTS播报开始 ==========');
    print('[$timestamp] [VoiceService] 文本内容: $text');
    print('[$timestamp] [VoiceService] 文本长度: ${text.length} 字符');
    print('[$timestamp] [VoiceService] 优先使用讯飞TTS: $_useXunfeiTTS');
    
    // 优先尝试使用讯飞TTS（真正的萌童声音）
    if (_useXunfeiTTS) {
      try {
        print('[$timestamp] [VoiceService] 🎤 尝试使用讯飞TTS API...');
        final success = await _speakWithXunfei(text);
        if (success) {
          print('[$timestamp] [VoiceService] ✅ 讯飞TTS播报成功');
          print('[$timestamp] [VoiceService] ============================================');
          return;
        } else {
          print('[$timestamp] [VoiceService] ⚠️ 讯飞TTS失败，回退到flutter_tts');
        }
      } catch (e) {
        print('[$timestamp] [VoiceService] ❌ 讯飞TTS异常: $e');
        print('[$timestamp] [VoiceService] ⚠️ 回退到flutter_tts');
      }
    }
    
    // 回退到flutter_tts（模拟萌童声音）
    print('[$timestamp] [VoiceService] 📢 使用flutter_tts（模拟萌童声音）');
    await _speakWithFlutterTts(text);
    print('[$timestamp] [VoiceService] ============================================');
  }
  
  /// 使用讯飞TTS播报（真正的萌童声音）
  /// 注意：Web平台不支持BytesSource播放，会抛出UnimplementedError
  Future<bool> _speakWithXunfei(String text) async {
    // Web平台不支持BytesSource播放
    if (kIsWeb) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [VoiceService] ⚠️ Web平台不支持讯飞TTS，跳过');
      return false;
    }
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [VoiceService] 🎤 调用讯飞TTS API: ${AppConfig.apiBaseUrl}/voice/tts/synthesize');
      
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/voice/tts/synthesize'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'child_voice': true,
          'voice_type': 'x5_lingxiaotang_flow', // 聆小糖-亲和女声（萌童声音）
        }),
      ).timeout(const Duration(seconds: 10));
      
      print('[$timestamp] [VoiceService] 🎤 讯飞TTS响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // 获取音频数据
        final audioBytes = response.bodyBytes;
        print('[$timestamp] [VoiceService] ✅ 收到音频数据: ${audioBytes.length} bytes');
        
        // 播放音频
        final completer = Completer<void>();
        StreamSubscription? completeSubscription;
        
        completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
          print('[$timestamp] [VoiceService] ✅ 音频播放完成');
          completeSubscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        });
        
        _audioPlayer.onLog.listen((message) {
          print('[$timestamp] [VoiceService] [AudioPlayer] $message');
        });
        
        // 播放音频（使用BytesSource）
        await _audioPlayer.play(BytesSource(audioBytes));
        print('[$timestamp] [VoiceService] 🎵 开始播放音频');
        
        // 等待播放完成（最多等待30秒）
        await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('[$timestamp] [VoiceService] ⚠️ 音频播放超时');
          },
        );
        return true;
      } else {
        final errorBody = response.body;
        print('[$timestamp] [VoiceService] ❌ 讯飞TTS API错误: ${response.statusCode}');
        print('[$timestamp] [VoiceService] 错误响应: $errorBody');
        
        // 如果是503错误，说明服务未配置，禁用讯飞TTS
        if (response.statusCode == 503) {
          print('[$timestamp] [VoiceService] ⚠️ 讯飞TTS服务未配置，禁用讯飞TTS');
          _useXunfeiTTS = false;
        }
        return false;
      }
    } catch (e, stackTrace) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [VoiceService] ❌ 讯飞TTS调用异常: $e');
      print('[$timestamp] [VoiceService] 堆栈: $stackTrace');
      return false;
    }
  }
  
  /// 使用flutter_tts播报（模拟萌童声音）
  Future<void> _speakWithFlutterTts(String text) async {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [VoiceService] 📢 使用flutter_tts播报');
    print('[$timestamp] [VoiceService] 当前模式: ${_isChildVoiceMode ? "萌童声音" : "正常声音"}');
    
    // 告警消息使用萌童声音
    print('[$timestamp] [VoiceService] 启用萌童声音模式...');
    await setChildVoiceMode(true);
    print('[$timestamp] [VoiceService] 萌童声音参数: pitch=1.4, speechRate=0.45');
    print('[$timestamp] [VoiceService] 开始调用flutter_tts.speak()...');
    
    final speakStartTime = DateTime.now();
    
    // 创建Completer来等待语音播报完成
    final completer = Completer<void>();
    
    // 监听语音播报完成事件
    _flutterTts.setCompletionHandler(() {
      final speakDuration = DateTime.now().difference(speakStartTime);
      final endTimestamp = DateTime.now().toIso8601String();
      print('[$endTimestamp] [VoiceService] ✅ flutter_tts播报完成，总耗时: ${speakDuration.inMilliseconds}ms');
      print('[$endTimestamp] [VoiceService] 已恢复默认声音模式');
      
      // 恢复默认声音
      setChildVoiceMode(false);
      
      // 完成Future
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    
    // 监听错误事件
    _flutterTts.setErrorHandler((msg) {
      final endTimestamp = DateTime.now().toIso8601String();
      print('[$endTimestamp] [VoiceService] ❌ flutter_tts播报错误: $msg');
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    
    // 开始播报
    await _flutterTts.speak(text);
    
    // 等待播报完成
    await completer.future;
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }
}

