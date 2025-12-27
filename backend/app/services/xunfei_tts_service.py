"""
科大讯飞TTS服务
用于生成萌童声音
参考AuraRecruit项目的成功实现，使用WebSocket方式
"""
import os
import logging
import base64
import hashlib
import hmac
import json
import time
import uuid
import asyncio
from datetime import datetime
from typing import Optional, Dict
from urllib.parse import quote
try:
    import websockets
except ImportError:
    websockets = None
    logging.warning("⚠️ websockets库未安装，请运行: pip install websockets")

from app.core.config import settings

logger = logging.getLogger(__name__)


class XunfeiTTSService:
    """科大讯飞TTS服务"""
    
    def __init__(self):
        # 从环境变量获取配置（支持多种命名方式）
        self.app_id = (
            os.getenv('XUNFEI_APP_ID') or 
            os.getenv('XUNFEI_APPID') or
            os.getenv('IFLYTEK_APP_ID')
        )
        self.api_key = (
            os.getenv('XUNFEI_API_KEY') or 
            os.getenv('XUNFEI_APIKEY') or
            os.getenv('IFLYTEK_API_KEY')
        )
        self.api_secret = (
            os.getenv('XUNFEI_API_SECRET') or 
            os.getenv('XUNFEI_APISECRET') or
            os.getenv('IFLYTEK_API_SECRET')
        )
        
        # 讯飞TTS WebSocket API地址（参考AuraRecruit项目的成功实现）
        # 使用WebSocket方式，这是讯飞TTS的正确调用方式
        # 注意：这个地址可能需要根据您的讯飞账号配置调整
        self.host = "cbm01.cn-huabei-1.xf-yun.com"
        self.path = "/v1/private/mcd9m97e6"
        
        # 如果上述地址不工作，可以尝试：
        # self.host = "tts-api.xfyun.cn"
        # self.path = "/v2/tts"
        
        # 检查配置
        if not self.app_id or not self.api_key or not self.api_secret:
            logger.warning("⚠️ 讯飞TTS配置不完整，将无法使用")
            logger.warning(f"   需要设置: XUNFEI_APP_ID, XUNFEI_API_KEY, XUNFEI_API_SECRET")
            logger.warning(f"   当前值: APP_ID={bool(self.app_id)}, API_KEY={bool(self.api_key)}, API_SECRET={bool(self.api_secret)}")
            self.enabled = False
        else:
            self.enabled = True
            logger.info(f"✅ 讯飞TTS服务已初始化: APP_ID={self.app_id[:10]}...")
    
    def _generate_auth_url(self) -> str:
        """
        生成WebSocket认证URL（参考AuraRecruit项目的实现）
        
        Returns:
            WebSocket URL字符串
        """
        # 生成RFC1123格式的时间戳
        date = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
        
        # 生成签名（使用GET方法，因为WebSocket连接使用GET）
        signature_origin = f"host: {self.host}\ndate: {date}\nGET {self.path} HTTP/1.1"
        signature_sha = hmac.new(
            self.api_secret.encode('utf-8'),
            signature_origin.encode('utf-8'),
            digestmod=hashlib.sha256
        ).digest()
        signature_sha_base64 = base64.b64encode(signature_sha).decode('utf-8')
        
        authorization_origin = f'api_key="{self.api_key}", algorithm="hmac-sha256", headers="host date request-line", signature="{signature_sha_base64}"'
        authorization = base64.b64encode(authorization_origin.encode('utf-8')).decode('utf-8')
        
        # 生成WebSocket URL
        return f"wss://{self.host}{self.path}?authorization={authorization}&date={quote(date)}&host={self.host}"
    
    async def synthesize(
        self,
        text: str,
        voice_type: str = "xiaoyan",  # 默认音色
        child_voice: bool = True,  # 是否使用萌童声音
        speed: int = 50,  # 语速 0-100
        pitch: int = 50,  # 音调 0-100
        volume: int = 50  # 音量 0-100
    ) -> Optional[bytes]:
        """
        合成语音
        
        Args:
            text: 要合成的文本
            voice_type: 音色类型
                - "xiaoyan": 小燕（女声，温柔）
                - "aisjiuxu": 许久（男声）
                - "aisxping": 小萍（女声）
                - "aisjinger": 靖儿（女声，适合儿童内容）
                - "aisxiaoqian": 小倩（女声）
                - "aisjinger": 靖儿（萌童声音，推荐）
            child_voice: 是否使用萌童声音（会调整voice_type）
            speed: 语速 0-100（默认50）
            pitch: 音调 0-100（默认50，萌童声音建议60-70）
            volume: 音量 0-100（默认50）
        
        Returns:
            音频文件字节流（MP3格式），失败返回None
        """
        if not self.enabled:
            logger.error("❌ 讯飞TTS服务未启用，请检查配置")
            return None
        
        if websockets is None:
            logger.error("❌ websockets库未安装，请运行: pip install websockets")
            return None
        
        try:
            # 如果使用萌童声音，选择适合的音色
            # 注意：AuraRecruit项目使用的是超拟人TTS，音色代码不同
            # 萌童声音可以使用：x5_lingxiaotang_flow（聆小糖-亲和女声）
            if child_voice:
                # 使用亲和女声模拟萌童声音
                voice_type = "x5_lingxiaotang_flow"  # 聆小糖-亲和女声（语音助手）
                # 萌童声音参数调整
                pitch = 65  # 提高音调，更接近儿童声音
                speed = 45  # 降低语速，更清晰
            else:
                # 默认使用专业男声
                voice_type = "x5_lingfeiyi_flow"  # 聆飞逸-专业男声
            
            logger.info(f"🎤 [讯飞TTS] ========== 开始合成语音 ==========")
            logger.info(f"🎤 [讯飞TTS] 文本长度: {len(text)} 字符")
            logger.info(f"🎤 [讯飞TTS] 文本内容: {text[:100]}...")
            logger.info(f"🎤 [讯飞TTS] 音色: {voice_type}")
            logger.info(f"🎤 [讯飞TTS] 萌童模式: {child_voice}")
            logger.info(f"🎤 [讯飞TTS] 参数配置: speed={speed}, pitch={pitch}, volume={volume}")
            logger.info(f"🎤 [讯飞TTS] APP_ID: {self.app_id[:10]}...")
            logger.info(f"🎤 [讯飞TTS] API_KEY: {self.api_key[:20]}...")
            logger.info(f"🎤 [讯飞TTS] API_SECRET: {'已设置' if self.api_secret else '未设置'}")
            
            # 生成WebSocket认证URL
            logger.info(f"🔗 [讯飞TTS] 生成认证URL...")
            ws_url = self._generate_auth_url()
            logger.info(f"🔗 [讯飞TTS] WebSocket URL: {ws_url[:150]}...")
            
            # 使用WebSocket连接（参考AuraRecruit项目的实现）
            # 明确禁用代理，直接连接讯飞服务器
            import os
            logger.info(f"🔧 [讯飞TTS] 检查代理设置...")
            # 临时清除代理环境变量（仅对此次连接有效）
            original_proxies = {}
            proxy_vars = ['HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy', 'SOCKS_PROXY', 'socks_proxy']
            for var in proxy_vars:
                if var in os.environ:
                    original_proxies[var] = os.environ[var]
                    logger.info(f"🔧 [讯飞TTS] 发现代理设置: {var}={os.environ[var][:50]}...")
                    del os.environ[var]
                    logger.info(f"🔧 [讯飞TTS] 已临时清除代理: {var}")
            
            if original_proxies:
                logger.info(f"🔧 [讯飞TTS] 共清除 {len(original_proxies)} 个代理环境变量")
            else:
                logger.info(f"🔧 [讯飞TTS] 未发现代理设置，直接连接")
            
            try:
                logger.info(f"📡 [讯飞TTS] 开始建立WebSocket连接...")
                logger.info(f"📡 [讯飞TTS] 目标地址: {self.host}{self.path}")
                # 使用create_connection明确禁用代理
                async with websockets.connect(
                    ws_url, 
                    ping_interval=None,
                    # 通过环境变量已清除代理，这里直接连接
                ) as ws:
                    logger.info(f"✅ [讯飞TTS] WebSocket连接成功")
                    # 构建请求消息（参考AuraRecruit项目的格式）
                    request_message = {
                    "header": {
                        "app_id": self.app_id,
                        "status": 2  # 2表示最后一块数据
                    },
                    "parameter": {
                        "tts": {
                            "vcn": voice_type,  # 音色
                            "speed": speed,  # 语速 0-100
                            "volume": volume,  # 音量 0-100
                            "pitch": pitch,  # 音调 0-100
                            "audio": {
                                "encoding": "lame",  # MP3编码
                                "sample_rate": 24000  # 采样率
                            }
                        }
                    },
                    "payload": {
                        "text": {
                            "encoding": "utf8",
                            "format": "plain",
                            "status": 2,  # 2表示最后一块数据
                            "seq": 0,
                            "text": base64.b64encode(text.encode('utf-8')).decode('utf-8')
                        }
                    }
                    }
                    
                    logger.info(f"📤 [讯飞TTS] 发送请求消息...")
                    await ws.send(json.dumps(request_message))
                    
                    # 接收音频数据（可能分多块）
                    chunks = []
                    while True:
                        response_text = await ws.recv()
                        response = json.loads(response_text)
                        
                        # 检查错误码
                        header = response.get("header", {})
                        code = header.get("code", 0)
                        if code != 0:
                            error_msg = header.get("message", "未知错误")
                            logger.error(f"❌ [讯飞TTS] 合成失败: code={code}, message={error_msg}")
                            return None
                        
                        # 提取音频数据
                        payload = response.get("payload", {})
                        audio_info = payload.get("audio", {})
                        audio_data = audio_info.get("audio")
                        
                        if audio_data:
                            chunks.append(base64.b64decode(audio_data))
                        
                        # 检查是否完成（status=2表示最后一块）
                        if audio_info.get("status") == 2:
                            break
                    
                    # 合并所有音频块
                    result = b"".join(chunks)
                    logger.info(f"✅ [讯飞TTS] ========== 合成成功 ==========")
                    logger.info(f"✅ [讯飞TTS] 音频大小: {len(result)} bytes")
                    logger.info(f"✅ [讯飞TTS] 音频块数: {len(chunks)}")
                    logger.info(f"✅ [讯飞TTS] =================================")
                    return result
            finally:
                # 恢复原始代理设置
                logger.info(f"🔧 [讯飞TTS] 恢复代理设置...")
                for var, value in original_proxies.items():
                    os.environ[var] = value
                    logger.info(f"🔧 [讯飞TTS] 已恢复代理: {var}")
                
        except ImportError as e:
            error_msg = str(e)
            logger.error(f"❌ [讯飞TTS] ========== 导入错误 ==========")
            logger.error(f"❌ [讯飞TTS] 错误类型: ImportError")
            logger.error(f"❌ [讯飞TTS] 错误信息: {error_msg}")
            logger.error(f"❌ [讯飞TTS] 可能原因: websockets库未安装或python-socks库未安装")
            logger.error(f"❌ [讯飞TTS] 解决方案: pip install websockets python-socks[asyncio]")
            logger.error(f"❌ [讯飞TTS] =================================")
            import traceback
            logger.error(f"❌ [讯飞TTS] 完整堆栈:\n{traceback.format_exc()}")
            return None
        except Exception as e:
            error_msg = str(e)
            error_type = type(e).__name__
            logger.error(f"❌ [讯飞TTS] ========== 合成异常 ==========")
            logger.error(f"❌ [讯飞TTS] 错误类型: {error_type}")
            logger.error(f"❌ [讯飞TTS] 错误信息: {error_msg}")
            logger.error(f"❌ [讯飞TTS] 文本内容: {text[:100]}...")
            logger.error(f"❌ [讯飞TTS] 音色配置: {voice_type}")
            logger.error(f"❌ [讯飞TTS] 萌童模式: {child_voice}")
            logger.error(f"❌ [讯飞TTS] Host: {self.host}")
            logger.error(f"❌ [讯飞TTS] Path: {self.path}")
            logger.error(f"❌ [讯飞TTS] APP_ID: {self.app_id[:10] if self.app_id else 'None'}...")
            logger.error(f"❌ [讯飞TTS] API_KEY: {self.api_key[:20] if self.api_key else 'None'}...")
            logger.error(f"❌ [讯飞TTS] =================================")
            import traceback
            logger.error(f"❌ [讯飞TTS] 完整堆栈跟踪:\n{traceback.format_exc()}")
            logger.error(f"❌ [讯飞TTS] =================================")
            logger.warning(f"⚠️ [讯飞TTS] 讯飞TTS失败，建议前端回退到flutter_tts模式")
            return None
                
        except Exception as e:
            logger.error(f"❌ [讯飞TTS] 合成异常: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())
            return None
    
    async def synthesize_to_file(
        self,
        text: str,
        output_path: str,
        child_voice: bool = True,
        **kwargs
    ) -> bool:
        """
        合成语音并保存到文件
        
        Args:
            text: 要合成的文本
            output_path: 输出文件路径
            child_voice: 是否使用萌童声音
            **kwargs: 其他参数（speed, pitch, volume等）
        
        Returns:
            成功返回True，失败返回False
        """
        audio_bytes = await self.synthesize(text, child_voice=child_voice, **kwargs)
        
        if audio_bytes is None:
            return False
        
        try:
            with open(output_path, 'wb') as f:
                f.write(audio_bytes)
            logger.info(f"✅ [讯飞TTS] 音频已保存: {output_path}")
            return True
        except Exception as e:
            logger.error(f"❌ [讯飞TTS] 保存文件失败: {e}")
            return False


# 创建单例
_xunfei_tts_service: Optional[XunfeiTTSService] = None


def get_xunfei_tts_service() -> Optional[XunfeiTTSService]:
    """获取讯飞TTS服务实例"""
    global _xunfei_tts_service
    if _xunfei_tts_service is None:
        _xunfei_tts_service = XunfeiTTSService()
    return _xunfei_tts_service if _xunfei_tts_service.enabled else None

