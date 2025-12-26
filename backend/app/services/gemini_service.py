"""
Gemini AI 视觉分析服务
支持 One-API 模式和直接 Gemini API 模式
"""
import json
import logging
import base64
from typing import Dict, List, Optional
from io import BytesIO
from PIL import Image
from openai import OpenAI
from app.core.config import settings

# 可选导入google.generativeai（仅在直接API模式需要）
try:
    import google.generativeai as genai
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False
    genai = None

logger = logging.getLogger(__name__)


class GeminiVisionAnalyzer:
    """Gemini 视觉分析器"""
    
    def __init__(self):
        import urllib.parse
        from urllib.parse import urlparse
        
        self.use_one_api = settings.use_one_api
        self.one_api_client = None
        self.gemini_client = None
        
        # 初始化客户端（延迟初始化，避免模块导入时出错）
        self._init_clients()
            
            # 解析URL获取IP地址和端口
            try:
                parsed_url = urlparse(settings.one_api_base_url)
                host = parsed_url.hostname
                port = parsed_url.port or (443 if parsed_url.scheme == 'https' else 80)
                
                # 显示密钥（前4位+后4位，中间隐藏）
                api_key_display = self._mask_api_key(settings.one_api_key)
                
                logger.info("=" * 60)
                logger.info("✅ [初始化] 使用 One-API 模式连接 Gemini")
                logger.info(f"📡 [One-API] Base URL: {settings.one_api_base_url}")
                logger.info(f"🌐 [One-API] 主机地址: {host}")
                logger.info(f"🔌 [One-API] 端口: {port}")
                logger.info(f"🔑 [One-API] API Key: {api_key_display}")
                logger.info(f"🤖 [One-API] 模型: {settings.one_api_gemini_vision_model}")
                logger.info("=" * 60)
                
                # 测试网络连接
                self._test_network_connection(host, port)
                
            except Exception as e:
                logger.warning(f"⚠️ [初始化] 解析URL失败: {e}")
                logger.info("✅ [初始化] 使用 One-API 模式连接 Gemini")
                
        elif settings.gemini_api_key:
            # 直接 Gemini API 模式
            if not GENAI_AVAILABLE:
                logger.warning("⚠️ google-generativeai 未安装，无法使用直接API模式")
            else:
                genai.configure(api_key=settings.gemini_api_key)
                self.gemini_client = genai.GenerativeModel(settings.one_api_gemini_vision_model)
                
                # 显示密钥（前4位+后4位，中间隐藏）
                api_key_display = self._mask_api_key(settings.gemini_api_key)
                
                logger.info("=" * 60)
                logger.info("✅ [初始化] 使用直接 Gemini API 模式")
                logger.info(f"🌐 [Gemini] API端点: https://generativelanguage.googleapis.com")
                logger.info(f"🔌 [Gemini] 端口: 443 (HTTPS)")
                logger.info(f"🔑 [Gemini] API Key: {api_key_display}")
                logger.info(f"🤖 [Gemini] 模型: {settings.one_api_gemini_vision_model}")
                logger.info("=" * 60)
                
                # 测试网络连接
                self._test_network_connection("generativelanguage.googleapis.com", 443)
        else:
            logger.warning("⚠️ 未配置 Gemini API，AI 分析功能将不可用")
    
    def _mask_api_key(self, api_key: str) -> str:
        """隐藏API密钥的中间部分"""
        if not api_key or len(api_key) < 8:
            return "***"
        return f"{api_key[:4]}...{api_key[-4:]}"
    
    def _test_network_connection(self, host: str, port: int):
        """测试网络连接"""
        import socket
        import subprocess
        
        try:
            logger.info(f"🔍 [网络测试] 开始测试连接到 {host}:{port}...")
            
            # 方法1: 使用socket测试TCP连接
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)  # 5秒超时
            result = sock.connect_ex((host, port))
            sock.close()
            
            if result == 0:
                logger.info(f"✅ [网络测试] TCP连接成功: {host}:{port}")
            else:
                logger.warning(f"⚠️ [网络测试] TCP连接失败: {host}:{port} (错误码: {result})")
            
            # 方法2: 尝试ping（如果可用）
            try:
                import platform
                if platform.system().lower() == 'windows':
                    ping_cmd = ['ping', '-n', '2', host]
                else:
                    ping_cmd = ['ping', '-c', '2', host]
                
                ping_result = subprocess.run(
                    ping_cmd,
                    capture_output=True,
                    timeout=5,
                    text=True
                )
                
                if ping_result.returncode == 0:
                    logger.info(f"✅ [网络测试] Ping成功: {host}")
                    # 提取IP地址
                    import re
                    ip_match = re.search(r'\((\d+\.\d+\.\d+\.\d+)\)', ping_result.stdout)
                    if ip_match:
                        logger.info(f"📍 [网络测试] 解析IP地址: {ip_match.group(1)}")
                else:
                    logger.warning(f"⚠️ [网络测试] Ping失败: {host}")
            except Exception as ping_error:
                logger.debug(f"🔍 [网络测试] Ping测试跳过: {ping_error}")
            
        except socket.gaierror as e:
            logger.error(f"❌ [网络测试] DNS解析失败: {host} - {e}")
        except socket.timeout:
            logger.warning(f"⚠️ [网络测试] 连接超时: {host}:{port}")
        except Exception as e:
            logger.warning(f"⚠️ [网络测试] 连接测试失败: {e}")
    
    async def analyze_hospital_scene(
        self,
        image_bytes: bytes,
        patient_context: Dict,
        detection_modes: List[str]
    ) -> Dict:
        """
        分析医院病房场景
        
        Args:
            image_bytes: 图片字节流
            patient_context: 患者上下文信息
            detection_modes: 检测模式列表 ['fall', 'bed_exit', 'facial', 'activity', 'iv_drip']
        
        Returns:
            AI分析结果字典
        """
        import traceback
        from datetime import datetime
        
        try:
            logger.info(f"🔍 [Gemini] 开始分析医院场景")
            logger.info(f"🔍 [Gemini] 图片大小: {len(image_bytes)} bytes")
            logger.info(f"🔍 [Gemini] 检测模式: {detection_modes}")
            logger.info(f"🔍 [Gemini] 患者上下文: {patient_context}")
            
            # 构建提示词
            logger.info(f"🔍 [Gemini] 构建分析提示词...")
            prompt = self._build_analysis_prompt(patient_context, detection_modes)
            logger.debug(f"🔍 [Gemini] 提示词长度: {len(prompt)} 字符")
            
            # 调用 AI 服务（优先使用One-API，带重试机制）
            api_start = datetime.now()
            max_retries = 2  # 最多重试2次，总共3次尝试
            timeout_seconds = 120  # 2分钟超时
            
            if self.use_one_api and self.one_api_client:
                logger.info(f"🔍 [Gemini] 使用One-API模式调用（超时: {timeout_seconds}秒，最多重试{max_retries}次）...")
                result = await self._analyze_with_one_api_with_retry(image_bytes, prompt, max_retries, timeout_seconds)
            elif self.gemini_client:
                logger.warning(f"⚠️ [Gemini] One-API未配置，使用直接Gemini API模式调用（超时: {timeout_seconds}秒，最多重试{max_retries}次）...")
                result = await self._analyze_with_gemini_with_retry(image_bytes, prompt, max_retries, timeout_seconds)
            else:
                logger.error(f"❌ [Gemini] AI服务未配置")
                return {
                    "error": "AI服务未配置",
                    "status": "failed"
                }
            
            api_duration = (datetime.now() - api_start).total_seconds()
            logger.info(f"🔍 [Gemini] API调用完成，耗时: {api_duration:.2f}秒")
            logger.debug(f"🔍 [Gemini] 原始响应长度: {len(result) if isinstance(result, str) else 'N/A'} 字符")
            
            # 解析结果
            logger.info(f"🔍 [Gemini] 解析AI响应...")
            parsed_result = self._parse_response(result)
            
            if "error" in parsed_result:
                logger.error(f"❌ [Gemini] 解析失败: {parsed_result.get('error')}")
                logger.debug(f"❌ [Gemini] 原始响应: {result[:500]}...")
            else:
                logger.info(f"✅ [Gemini] 解析成功，整体状态: {parsed_result.get('overall_status', 'unknown')}")
            
            return parsed_result
            
        except Exception as e:
            error_trace = traceback.format_exc()
            logger.error(f"❌ [Gemini] AI分析失败")
            logger.error(f"❌ [Gemini] 异常类型: {type(e).__name__}")
            logger.error(f"❌ [Gemini] 异常消息: {str(e)}")
            logger.error(f"❌ [Gemini] 完整堆栈跟踪:\n{error_trace}")
            
            return {
                "error": str(e),
                "error_type": type(e).__name__,
                "error_traceback": error_trace,
                "status": "failed"
            }
    
    async def _analyze_with_one_api_with_retry(
        self, 
        image_bytes: bytes, 
        prompt: str, 
        max_retries: int = 2,
        timeout_seconds: int = 120
    ) -> str:
        """使用 One-API 调用 Gemini（带重试机制）"""
        last_exception = None
        
        for attempt in range(max_retries + 1):  # 总共 max_retries + 1 次尝试
            try:
                if attempt > 0:
                    wait_time = min(2 ** attempt, 10)  # 指数退避，最多等待10秒
                    logger.info(f"🔄 [One-API] 第 {attempt + 1} 次尝试（等待 {wait_time} 秒后重试）...")
                    import asyncio
                    await asyncio.sleep(wait_time)
                else:
                    logger.info(f"🔍 [One-API] 第 {attempt + 1} 次尝试...")
                
                result = await self._analyze_with_one_api(image_bytes, prompt, timeout_seconds)
                if attempt > 0:
                    logger.info(f"✅ [One-API] 重试成功！")
                return result
                
            except (TimeoutError, Exception) as e:
                last_exception = e
                logger.warning(f"⚠️ [One-API] 第 {attempt + 1} 次尝试失败: {type(e).__name__}: {str(e)}")
                
                if attempt < max_retries:
                    logger.info(f"🔄 [One-API] 将在下次重试...")
                else:
                    logger.error(f"❌ [One-API] 所有 {max_retries + 1} 次尝试均失败")
        
        # 所有重试都失败，抛出最后一个异常
        raise last_exception
    
    async def _analyze_with_one_api(self, image_bytes: bytes, prompt: str, timeout_seconds: int = 120) -> str:
        """使用 One-API 调用 Gemini"""
        import asyncio
        import traceback
        from datetime import datetime
        
        import urllib.parse
        from urllib.parse import urlparse
        
        try:
            # 解析URL获取详细信息
            parsed_url = urlparse(settings.one_api_base_url)
            host = parsed_url.hostname
            port = parsed_url.port or (443 if parsed_url.scheme == 'https' else 80)
            api_key_display = self._mask_api_key(settings.one_api_key)
            
            logger.info(f"🔍 [One-API] 准备调用API...")
            logger.info(f"🔍 [One-API] Base URL: {settings.one_api_base_url}")
            logger.info(f"🌐 [One-API] 目标地址: {host}:{port}")
            logger.info(f"🔑 [One-API] API Key: {api_key_display}")
            logger.info(f"🤖 [One-API] 模型: {settings.one_api_gemini_vision_model}")
            logger.info(f"⏱️ [One-API] 超时设置: {timeout_seconds}秒")
            
            # 将图片转换为 base64
            logger.info(f"🔍 [One-API] 步骤1/3: 转换图片为base64...")
            convert_start = datetime.now()
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            image_data_url = f"data:image/jpeg;base64,{image_base64}"
            convert_duration = (datetime.now() - convert_start).total_seconds()
            logger.info(f"🔍 [One-API] Base64转换完成，耗时: {convert_duration:.3f}秒")
            logger.info(f"🔍 [One-API] Base64长度: {len(image_base64)} 字符")
            logger.info(f"🔍 [One-API] Data URL长度: {len(image_data_url)} 字符")
            
            # 准备请求消息
            logger.info(f"🔍 [One-API] 步骤2/3: 准备请求消息...")
            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": image_data_url}
                        }
                    ]
                }
            ]
            logger.info(f"🔍 [One-API] 消息数量: {len(messages)}")
            logger.info(f"🔍 [One-API] 提示词长度: {len(prompt)} 字符")
            
            # 调用 OpenAI 兼容接口（添加超时）
            logger.info(f"🔍 [One-API] 步骤3/3: 发送请求到API...")
            logger.info(f"🔍 [One-API] 请求开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}")
            
            api_start = datetime.now()
            
            try:
                # 将同步调用包装为异步，并添加超时
                def sync_create():
                    return self.one_api_client.chat.completions.create(
                        model=settings.one_api_gemini_vision_model,
                        messages=messages,
                        temperature=0.1,
                        max_tokens=2048
                    )
                
                response = await asyncio.wait_for(
                    asyncio.to_thread(sync_create),
                    timeout=float(timeout_seconds)  # 可配置的超时时间
                )
                
                api_duration = (datetime.now() - api_start).total_seconds()
                logger.info(f"✅ [One-API] API调用成功，耗时: {api_duration:.2f}秒")
                
                # 检查响应
                if not response or not hasattr(response, 'choices') or not response.choices:
                    raise ValueError("API返回空响应或无效响应")
                
                if not response.choices[0].message.content:
                    raise ValueError("响应中没有内容")
                
                result = response.choices[0].message.content
                logger.info(f"✅ [One-API] 响应文本长度: {len(result)} 字符")
                logger.debug(f"🔍 [One-API] 响应预览: {result[:200]}...")
                
                return result
                
            except asyncio.TimeoutError:
                api_duration = (datetime.now() - api_start).total_seconds()
                logger.error(f"❌ [One-API] API调用超时 (耗时: {api_duration:.2f}秒，超时限制: {timeout_seconds}秒)")
                raise TimeoutError(f"One-API调用超时，超过{timeout_seconds}秒未响应")
            
        except Exception as e:
            error_trace = traceback.format_exc()
            logger.error(f"❌ [One-API] API调用失败")
            logger.error(f"❌ [One-API] 异常类型: {type(e).__name__}")
            logger.error(f"❌ [One-API] 异常消息: {str(e)}")
            logger.error(f"❌ [One-API] 完整堆栈跟踪:\n{error_trace}")
            raise
    
    async def _analyze_with_gemini_with_retry(
        self, 
        image_bytes: bytes, 
        prompt: str, 
        max_retries: int = 2,
        timeout_seconds: int = 120
    ) -> str:
        """直接使用 Gemini API（带重试机制）"""
        last_exception = None
        
        for attempt in range(max_retries + 1):  # 总共 max_retries + 1 次尝试
            try:
                if attempt > 0:
                    wait_time = min(2 ** attempt, 10)  # 指数退避，最多等待10秒
                    logger.info(f"🔄 [Gemini-Direct] 第 {attempt + 1} 次尝试（等待 {wait_time} 秒后重试）...")
                    import asyncio
                    await asyncio.sleep(wait_time)
                else:
                    logger.info(f"🔍 [Gemini-Direct] 第 {attempt + 1} 次尝试...")
                
                result = await self._analyze_with_gemini(image_bytes, prompt, timeout_seconds)
                if attempt > 0:
                    logger.info(f"✅ [Gemini-Direct] 重试成功！")
                return result
                
            except (TimeoutError, Exception) as e:
                last_exception = e
                logger.warning(f"⚠️ [Gemini-Direct] 第 {attempt + 1} 次尝试失败: {type(e).__name__}: {str(e)}")
                
                if attempt < max_retries:
                    logger.info(f"🔄 [Gemini-Direct] 将在下次重试...")
                else:
                    logger.error(f"❌ [Gemini-Direct] 所有 {max_retries + 1} 次尝试均失败")
        
        # 所有重试都失败，抛出最后一个异常
        raise last_exception
    
    async def _analyze_with_gemini(self, image_bytes: bytes, prompt: str, timeout_seconds: int = 120) -> str:
        """直接使用 Gemini API"""
        import asyncio
        import traceback
        from datetime import datetime
        
        try:
            api_key_display = self._mask_api_key(settings.gemini_api_key) if settings.gemini_api_key else "未配置"
            
            logger.info(f"🔍 [Gemini-Direct] 准备调用直接Gemini API...")
            logger.info(f"🌐 [Gemini-Direct] 目标地址: generativelanguage.googleapis.com:443")
            logger.info(f"🔑 [Gemini-Direct] API Key: {api_key_display}")
            logger.info(f"🤖 [Gemini-Direct] 模型: {settings.one_api_gemini_vision_model}")
            logger.info(f"⏱️ [Gemini-Direct] 超时设置: {timeout_seconds}秒")
            
            # 转换图片
            logger.info(f"🔍 [Gemini-Direct] 步骤1/3: 转换图片格式...")
            convert_start = datetime.now()
            image = Image.open(BytesIO(image_bytes))
            convert_duration = (datetime.now() - convert_start).total_seconds()
            logger.info(f"🔍 [Gemini-Direct] 图片转换完成，耗时: {convert_duration:.3f}秒")
            logger.info(f"🔍 [Gemini-Direct] 图片尺寸: {image.size}")
            
            # 准备生成配置
            logger.info(f"🔍 [Gemini-Direct] 步骤2/3: 准备生成配置...")
            generation_config = {
                "temperature": 0.1,
                "top_p": 0.8,
                "top_k": 40,
                "max_output_tokens": 2048,
            }
            logger.info(f"🔍 [Gemini-Direct] 生成配置: {generation_config}")
            logger.info(f"🔍 [Gemini-Direct] 提示词长度: {len(prompt)} 字符")
            
            # 调用API（使用asyncio.to_thread将同步调用转为异步，并添加超时）
            logger.info(f"🔍 [Gemini-Direct] 步骤3/3: 发送请求到Gemini API...")
            logger.info(f"🔍 [Gemini-Direct] 请求开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}")
            
            api_start = datetime.now()
            
            # 使用asyncio.wait_for添加超时（60秒）
            try:
                # 将同步调用包装为异步
                def sync_generate():
                    return self.gemini_client.generate_content(
                        [prompt, image],
                        generation_config=generation_config
                    )
                
                response = await asyncio.wait_for(
                    asyncio.to_thread(sync_generate),
                    timeout=float(timeout_seconds)  # 可配置的超时时间
                )
                
                api_duration = (datetime.now() - api_start).total_seconds()
                logger.info(f"✅ [Gemini-Direct] API调用成功，耗时: {api_duration:.2f}秒")
                
                # 检查响应
                if not response:
                    raise ValueError("API返回空响应")
                
                if not hasattr(response, 'text') or not response.text:
                    logger.warning(f"⚠️ [Gemini-Direct] 响应中没有text属性")
                    logger.warning(f"⚠️ [Gemini-Direct] 响应对象: {type(response)}")
                    logger.warning(f"⚠️ [Gemini-Direct] 响应属性: {dir(response)}")
                    
                    # 尝试获取其他可能的响应内容
                    if hasattr(response, 'candidates') and response.candidates:
                        candidate = response.candidates[0]
                        if hasattr(candidate, 'content') and hasattr(candidate.content, 'parts'):
                            text_parts = [part.text for part in candidate.content.parts if hasattr(part, 'text')]
                            if text_parts:
                                result_text = ''.join(text_parts)
                                logger.info(f"✅ [Gemini-Direct] 从candidates中提取文本，长度: {len(result_text)} 字符")
                                return result_text
                    
                    raise ValueError("无法从响应中提取文本内容")
                
                result_text = response.text
                logger.info(f"✅ [Gemini-Direct] 响应文本长度: {len(result_text)} 字符")
                logger.debug(f"🔍 [Gemini-Direct] 响应预览: {result_text[:200]}...")
                
                return result_text
                
            except asyncio.TimeoutError:
                api_duration = (datetime.now() - api_start).total_seconds()
                logger.error(f"❌ [Gemini-Direct] API调用超时 (耗时: {api_duration:.2f}秒，超时限制: {timeout_seconds}秒)")
                raise TimeoutError(f"Gemini API调用超时，超过{timeout_seconds}秒未响应")
            
        except Exception as e:
            error_trace = traceback.format_exc()
            logger.error(f"❌ [Gemini-Direct] API调用失败")
            logger.error(f"❌ [Gemini-Direct] 异常类型: {type(e).__name__}")
            logger.error(f"❌ [Gemini-Direct] 异常消息: {str(e)}")
            logger.error(f"❌ [Gemini-Direct] 完整堆栈跟踪:\n{error_trace}")
            raise
    
    def _build_analysis_prompt(
        self,
        patient_context: Dict,
        detection_modes: List[str]
    ) -> str:
        """构建结构化提示词"""
        
        prompt = f"""你是一个专业的医疗监护AI助手,正在分析医院病房监控画面。请使用中文回复所有内容。

## 患者信息:
- 姓名: {patient_context.get('name', '未知')}
- 年龄: {patient_context.get('age', '未知')}
- 诊断: {patient_context.get('diagnosis', '未知')}
- 风险等级: {patient_context.get('risk_level', 'medium')}

## 分析任务:
请仔细分析图像,检测以下场景(如果启用)。所有描述和状态值请使用中文:

"""
        
        if 'fall' in detection_modes:
            prompt += """
### 1. 跌倒检测 (Fall Detection)
- 检测患者是否处于跌倒状态(身体在地面、非正常姿势)
- 判断是否有跌倒迹象(失衡、倾斜)
- 置信度评分(0-1)
"""
        
        if 'bed_exit' in detection_modes:
            prompt += """
### 2. 离床监测 (Bed Exit Detection)
- 判断患者是否在床上
- 如果离床,判断位置(床边、卫生间、房间其他区域)
- 评估是否需要预警
"""
        
        if 'prolonged_bed' in detection_modes or 'activity' in detection_modes:
            prompt += """
### 3. 活动异常识别 (Activity Analysis)
- 检测异常活动:剧烈挣扎、长时间僵直不动、异常爬行
- 评估活动强度和持续时间
- 判断是否有突发疾病迹象
"""
        
        if 'facial' in detection_modes:
            prompt += """
### 4. 面色与表情分析 (Facial Analysis)
- 分析面部肤色:正常、苍白、潮红、紫绀(缺氧)
- 识别表情:中性、痛苦(皱眉、紧闭双眼)、恐惧、焦虑
- 评估情绪状态
"""
        
        if 'iv_drip' in detection_modes:
            prompt += """
### 5. 吊瓶监测 (IV Drip Monitoring)
- 检测是否有输液吊瓶
- 判断液体剩余量(满、半满、接近打完、已打完)
- 评估是否需要更换
"""
        
        prompt += """

## 输出格式要求:
请严格按照以下JSON格式输出,不要添加任何额外文字。所有文本内容必须使用中文:
```json
{
    "timestamp": "当前分析时间",
    "overall_status": "正常/注意/紧急",
    "detections": {
        "fall": {
            "detected": true/false,
            "confidence": 0.95,
            "description": "具体描述（中文）",
            "severity": "紧急/高/中/低"
        },
        "bed_exit": {
            "patient_in_bed": true/false,
            "location": "床上/卫生间/房间",
            "duration_estimate": "估算离床时长（中文）"
        },
        "activity": {
            "type": "正常/挣扎/僵直/爬行/无活动",
            "description": "活动描述（中文）",
            "abnormal": true/false
        },
        "facial_analysis": {
            "skin_color": "正常/苍白/潮红/紫绀",
            "expression": "中性/痛苦/恐惧/焦虑",
            "emotion_confidence": 0.85
        },
        "iv_drip": {
            "detected": true/false,
            "fluid_level": "满/半满/接近打完/已打完",
            "needs_replacement": true/false
        }
    },
    "recommended_action": "立即告警/监控/无",
    "alert_message": "如果需要告警,生成简短中文告警信息"
}
```

重要提示:
1. 确保输出是有效的JSON格式
2. 所有文本内容必须使用中文，包括description、location、duration_estimate等字段
3. overall_status的值必须是"正常"、"注意"或"紧急"（中文）
4. 置信度分数范围0-1
5. 如果无法判断某项,设置为null
6. 优先考虑患者安全,宁可过度告警
7. 所有描述性文本必须使用中文，不要使用英文
"""
        
        return prompt
    
    def _parse_response(self, response_text: str) -> Dict:
        """解析AI返回的结果"""
        try:
            # 提取JSON部分
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            
            if json_start == -1 or json_end == 0:
                logger.warning("未找到JSON格式的响应")
                return {
                    "error": "No JSON found in response",
                    "raw_response": response_text
                }
            
            json_str = response_text[json_start:json_end]
            result = json.loads(json_str)
            
            return result
        except json.JSONDecodeError as e:
            logger.error(f"JSON解析失败: {e}")
            return {
                "error": f"Parse error: {str(e)}",
                "raw_response": response_text
            }
        except Exception as e:
            logger.error(f"解析响应失败: {e}")
            return {
                "error": f"Parse error: {str(e)}",
                "raw_response": response_text
            }


# 创建全局实例
gemini_analyzer = GeminiVisionAnalyzer()

