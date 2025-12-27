"""
Gemini AI 视觉分析服务
支持 One-API 模式和直接 Gemini API 模式
"""
import json
import logging
import base64
import re
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
        self.use_one_api = settings.use_one_api
        self.one_api_client = None
        self.gemini_client = None
        # 延迟初始化客户端，避免模块导入时的兼容性问题
        # 客户端将在第一次使用时初始化
    
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
            logger.info(f"🔍 [Gemini]## 患者详细提示词: {prompt}")
            logger.debug(f"🔍 [Gemini] 提示词长度: {len(prompt)} 字符")
            
            # 调用 AI 服务（优先使用One-API，带重试机制）
            api_start = datetime.now()
            max_retries = 2  # 最多重试2次，总共3次尝试
            timeout_seconds = 120  # 2分钟超时
            
            if self.use_one_api:
                # 延迟初始化客户端
                if not self.one_api_client and settings.one_api_base_url and settings.one_api_key:
                    try:
                        self.one_api_client = OpenAI(
                            base_url=settings.one_api_base_url,
                            api_key=settings.one_api_key
                        )
                        logger.info("✅ [延迟初始化] OpenAI 客户端已创建")
                    except Exception as e:
                        logger.error(f"❌ [延迟初始化] OpenAI 客户端创建失败: {e}")
                        return {
                            "error": f"AI服务初始化失败: {e}",
                            "status": "failed"
                        }
                
                if self.one_api_client:
                    logger.info(f"🔍 [Gemini] 使用One-API模式调用（超时: {timeout_seconds}秒，最多重试{max_retries}次）...")
                    result = await self._analyze_with_one_api_with_retry(image_bytes, prompt, max_retries, timeout_seconds)
                else:
                    logger.error(f"❌ [Gemini] One-API客户端未初始化")
                    return {
                        "error": "AI服务未配置",
                        "status": "failed"
                    }
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
            
            # 输出提示词的关键部分（吊瓶检测部分），方便确认最新提示词是否生效
            if "吊瓶监测" in prompt or "IV Drip Monitoring" in prompt:
                logger.info("=" * 80)
                logger.info("📋 [One-API] 提示词关键部分 - 吊瓶检测:")
                logger.info("=" * 80)
                # 提取吊瓶检测相关的提示词部分
                prompt_lines = prompt.split('\n')
                in_iv_drip_section = False
                iv_drip_lines = []
                for i, line in enumerate(prompt_lines):
                    if "### 5. 吊瓶监测" in line or "IV Drip Monitoring" in line:
                        in_iv_drip_section = True
                    if in_iv_drip_section:
                        iv_drip_lines.append(line)
                        # 如果遇到下一个章节或输出格式要求，停止
                        if (i < len(prompt_lines) - 1 and 
                            (prompt_lines[i+1].startswith("### ") or 
                             prompt_lines[i+1].startswith("## 输出格式要求"))):
                            break
                
                if iv_drip_lines:
                    logger.info('\n'.join(iv_drip_lines))
                else:
                    # 如果没找到，输出包含"吊瓶"或"iv_drip"的所有行
                    relevant_lines = [line for line in prompt_lines if "吊瓶" in line or "iv_drip" in line.lower() or "袋子" in line or "半满" in line]
                    if relevant_lines:
                        logger.info('\n'.join(relevant_lines[:50]))  # 最多输出50行
                    else:
                        logger.warning("⚠️ 未找到吊瓶检测相关的提示词内容")
                logger.info("=" * 80)
            
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

## 场景识别（第一步，必须首先执行）:
在开始具体检测之前，请先识别图片中的场景内容，这将决定需要执行哪些检测任务：

**场景类型判断：**
1. **场景A：病床或病人场景**
   - 如果图片中包含病床、病人、或病人在床上的画面
   - 需要执行检测任务1-5：跌倒检测、离床监测、活动异常识别、面部分析、吊瓶监测

2. **场景B：仅吊瓶场景**
   - 如果图片中只有吊瓶/输液设备，没有病床或病人
   - 只需要执行检测任务5：吊瓶监测

3. **场景C：生命监控设备场景**
   - 如果图片中包含心跳监护仪、心电图机、血氧仪、呼吸机等生命监控设备
   - 需要单独分析监控设备上的数据，重点关注：
     * 心跳/心率：是否变缓（<60次/分）、是否变平（直线，无心跳）
     * 血氧饱和度：是否下降（<90%）
     * 呼吸频率：是否异常（过快或过慢）
     * 血压：是否异常（过高或过低）
   - **特别注意**：如果心跳变平（直线），这表示病人可能濒临死亡，需要立即紧急通知家属到现场进行救护和临终陪伴！

**场景判断输出要求：**
在JSON输出的 `scene_type` 字段中标注场景类型："bed_patient"（病床/病人）、"iv_drip_only"（仅吊瓶）、"monitoring_device"（生命监控设备）

## 分析任务:
根据识别的场景，执行相应的检测任务。所有描述和状态值请使用中文:

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
**⚠️ 重要：准确识别患者情绪状态和皮肤异常，及时发现健康问题**

**🔍 皮肤颜色与异常检测（必须检测所有可见的身体部位）：**

**检测范围：**
- **面部**：面色、面部皮肤
- **手臂和手部**：前臂、手背、手掌等可见部位
- **腿部**：小腿、脚部等可见部位
- **其他可见部位**：任何在图片中可见的身体部位

**面部肤色分析：**
- **正常**：面色红润，肤色自然
- **苍白**：面色发白，缺乏血色，可能表示虚弱、失血或低血压
- **潮红**：面色发红，可能表示发热、高血压或情绪激动
- **紫绀**：面色发紫或发青，**这是严重缺氧的标志，必须立即告警！**

**身体其他部位皮肤异常检测（高优先级）：**
- **紫红色/紫蓝色斑块**：皮肤上出现紫红色、紫蓝色或深红色的斑块、瘀斑、紫癜
  - **可能原因**：出血性疾病、血小板减少、血管炎、过敏反应、药物反应等
  - **严重程度**：**高优先级，需要立即关注！**
  - **输出值**：`"skin_color": "异常"` 或 `"skin_color": "紫绀"`，并在description中详细描述
  
- **皮疹/红斑**：皮肤上出现红色、粉红色的皮疹、斑块
  - **可能原因**：过敏、感染、药物反应等
  - **输出值**：`"skin_color": "异常"`，并在description中详细描述

- **瘀斑/瘀血**：皮肤上出现青紫色、深紫色的瘀斑
  - **可能原因**：外伤、出血性疾病等
  - **输出值**：`"skin_color": "异常"`，并在description中详细描述

- **皮肤病变**：任何异常的皮肤颜色变化、斑块、病变
  - **必须详细描述**：位置（手臂/手部/腿部等）、颜色（紫红色/深红色/青紫色等）、大小、形状、数量
  - **输出值**：`"skin_color": "异常"`，并在description中详细描述

**🚨 关键判断原则：**
1. **全面检测**：不仅要检测面部，还要检测所有可见的身体部位（手臂、手部、腿部等）
2. **异常优先**：如果发现任何皮肤异常（紫红色斑块、皮疹、瘀斑等），**必须**标记为异常
3. **详细描述**：在description中必须详细描述：
   - 异常部位（如"前臂和手背"、"手臂"等）
   - 异常颜色（如"紫红色"、"深紫色"、"青紫色"等）
   - 异常特征（如"多个大小不一的斑块"、"形状不规则的病变"等）
   - 严重程度评估
4. **宁可过度识别**：如果无法确定是正常还是异常，优先选择"异常"，不要选择"正常"
5. **紫红色斑块特别关注**：如果看到紫红色、紫蓝色或深红色的斑块，这是**高优先级异常**，必须立即告警

**😔 情绪与表情识别（必须先检测人脸）：**

**⚠️ 重要前置判断：**
1. **首先判断图片中是否包含人脸**：
   - 仔细观察图片，确认是否能看到完整或部分的人脸（包括眼睛、鼻子、嘴巴等面部特征）
   - 如果图片中**没有检测到人脸**（例如只有手臂、腿部、身体其他部位，没有面部），则：
     - **必须设置**：`"expression": null` 或 `"expression": "无法判断"`
     - **必须设置**：`"emotion_confidence": 0.0`
     - **必须在description中说明**："图片中未检测到人脸，无法进行表情分析"
     - **绝对不能**：在没有检测到人脸的情况下，猜测或推断表情（如"担忧"、"中性"等）
   
2. **只有在确认检测到人脸后，才进行表情分析**：
   - 如果检测到人脸，继续下面的表情识别流程
   - 如果未检测到人脸，跳过表情识别，只进行皮肤异常检测

**判断标准（按优先级和严重程度，仅在检测到人脸时执行）：**

**1. 痛苦表情（高优先级）：**
- **特征**：眉头紧锁、紧闭双眼、嘴角下拉、面部肌肉紧张
- **判断依据**：明显的疼痛表现，如皱眉、咬牙、面部扭曲
- **输出值**：`"expression": "痛苦"`

**2. 恐惧表情（高优先级）：**
- **特征**：眼睛睁大、瞳孔放大、眉毛上扬、嘴巴张开
- **判断依据**：明显的恐惧或惊恐表现
- **输出值**：`"expression": "恐惧"`

**3. 焦虑表情（中优先级）：**
- **特征**：眉头微皱、眼神不安、频繁眨眼、嘴唇紧张
- **判断依据**：明显的焦虑或紧张表现
- **输出值**：`"expression": "焦虑"`

**4. 担忧/沮丧表情（中优先级）：**
- **特征**：眉头紧锁、眼神向下、嘴角下垂、表情严肃或悲伤
- **判断依据**：明显的担忧、沮丧或悲伤表现，但不如痛苦那么强烈
- **常见表现**：老年人表情严肃、眼神忧虑、眉头微皱、整体表情沉重
- **输出值**：`"expression": "担忧"` 或 `"expression": "沮丧"`

**5. 悲伤表情（中优先级）：**
- **特征**：嘴角明显下垂、眼神无神、眉头微皱、整体表情低落
- **判断依据**：明显的悲伤或情绪低落表现
- **输出值**：`"expression": "悲伤"`

**6. 中性表情（正常）：**
- **特征**：面部表情自然、放松，无明显情绪波动
- **判断依据**：表情平静，无明显负面情绪表现
- **输出值**：`"expression": "中性"`

**🚨 关键判断原则：**
1. **仔细观察面部细节**：眉头、眼神、嘴角、面部肌肉紧张程度
2. **优先识别负面情绪**：如果表情明显不正常（如严肃、忧虑、悲伤），**绝对不能**判定为"中性"
3. **老年人表情特点**：老年人可能因为疾病、疼痛或心理压力而表情严肃或忧虑，这**不是**中性表情
4. **宁可过度识别**：如果无法确定是"中性"还是"担忧/沮丧"，优先选择"担忧"或"沮丧"，不要选择"中性"
5. **结合上下文**：如果患者处于疾病状态，表情严肃或忧虑更可能是负面情绪，而非中性

**📋 输出要求：**
- **如果未检测到人脸**：
  - `expression` **必须**设置为 `null`
  - `emotion_confidence` **必须**设置为 `0.0`
  - `description` **必须**说明："图片中未检测到人脸，无法进行表情分析"
  - **绝对不能**在没有检测到人脸的情况下猜测表情
  
- **如果检测到人脸**：
  - `expression` 字段必须准确反映患者当前的情绪状态
  - 如果表情明显不正常（严肃、忧虑、悲伤），必须选择相应的负面情绪，**不能**选择"中性"
  - `emotion_confidence` 应该反映识别的置信度（0-1）
  - 在 `description` 中详细描述观察到的面部特征和判断依据
"""
        
        if 'iv_drip' in detection_modes:
            prompt += """
### 5. 吊瓶监测 (IV Drip Monitoring)
**⚠️ 极其重要：检测吊瓶是否空的关键判断标准**

**🚨 核心判断原则（必须严格遵守）：**
1. **必须观察上半部分的袋子或玻璃瓶**，而不是末端滴液管（滴液管有液体不代表吊瓶未空）
2. **如果袋子/玻璃瓶的上半部分已经空了，无论下半部分或滴液管是否有液体，都代表吊瓶已经空了，这是危险情况！**
3. **如果液体已经流到滴液管里，但袋子/玻璃瓶上半部分已空，说明袋子已经空了，必须立即警告！**

**🔍 关键判断逻辑（按优先级）：**
- **情况1（最高优先级）**：袋子/玻璃瓶完全空了 → `fluid_level: "已打完"`, `completely_empty: true`, `needs_phone_call: true`
- **情况2（紧急警告）**：袋子/玻璃瓶上半部分已空（即使下半部分或滴液管还有液体） → `fluid_level: "袋子空"`, `bag_empty: true`, `needs_emergency_alert: true`
- **情况3（正常）**：袋子/玻璃瓶基本充满，上半部分有液体 → `fluid_level: "满"`

**❌ 错误判断（必须避免）：**
- **绝对不能**：看到袋子/玻璃瓶上半部分已空，却判定为"半满"
- **绝对不能**：看到液体在滴液管里，就认为吊瓶未空（滴液管有液体但袋子空 = 危险！）

**✅ 液体剩余量判断标准（严格按照以下标准）：**
- **"满"**：袋子/玻璃瓶基本充满，**上半部分有液体**，下半部分也有液体
- **"半满"**：**只有当袋子/玻璃瓶还有一半左右液体，且上半部分还有液体时，才能判定为"半满"**
  - 如果上半部分已空，即使看起来"半满"，也必须判定为"袋子空"，不能判定为"半满"！
- **"袋子空"**：袋子/玻璃瓶上半部分已空，即使下半部分或滴液管还有液体，这也是危险情况
  - **必须设置**：`bag_empty: true`, `needs_emergency_alert: true`
  - **必须设置**：`fluid_level: "袋子空"`（不能设置为"半满"）
- **"已打完"**：袋子/玻璃瓶完全空了，滴液管也没有液体
  - **必须设置**：`completely_empty: true`, `needs_phone_call: true`
  - **必须设置**：`fluid_level: "已打完"`

**🚨 紧急程度判断（必须严格遵守）：**
- **袋子/玻璃瓶上半部分空** = 紧急警告（立即通知家属和护士）
  - 即使看起来"半满"，只要上半部分空，就必须判定为"袋子空"
  - 必须设置：`bag_empty: true`, `needs_emergency_alert: true`, `fluid_level: "袋子空"`
- **袋子/玻璃瓶完全空** = 电话呼叫（最高优先级）
  - 必须设置：`completely_empty: true`, `needs_phone_call: true`, `fluid_level: "已打完"`

**📋 输出要求（必须严格遵守）：**
1. 如果检测到袋子/玻璃瓶上半部分已空，`fluid_level` **必须**设置为"袋子空"，**绝对不能**设置为"半满"
2. 必须同时设置 `bag_empty: true` 和 `needs_emergency_alert: true`
3. 如果完全空了，`fluid_level` **必须**设置为"已打完"，并设置 `completely_empty: true` 和 `needs_phone_call: true`
4. 在 `description` 字段中，必须详细描述：
   - 袋子/玻璃瓶上半部分的液体情况（有/无/部分）
   - 袋子/玻璃瓶下半部分的液体情况
   - 滴液管中的液体情况
   - 你的判断依据（为什么判定为"满"/"半满"/"袋子空"/"已打完"）
   - 如果判定为"袋子空"或"已打完"，必须说明危险程度
"""
        
        # 添加生命监控设备检测
        prompt += """
### 6. 生命监控设备分析 (Vital Signs Monitoring)
**⚠️ 极其重要：生命监控设备数据分析**

**🔍 需要检测的设备类型：**
- 心跳监护仪/心电图机：显示心率、心电图波形
- 血氧仪：显示血氧饱和度（SpO2）
- 呼吸机：显示呼吸频率、呼吸模式
- 血压监测仪：显示血压值
- 其他生命体征监测设备

**🚨 关键生命体征判断（按紧急程度）：**

**情况1（最高优先级 - 濒临死亡）：**
- **心跳变平（直线）**：心电图显示为直线，无心跳波形
  - 这表示病人可能已经心脏骤停或濒临死亡
  - **必须立即**：通知家属到现场进行救护和临终陪伴
  - **必须设置**：`heart_rate_flat: true`, `critical_life_threat: true`, `needs_family_notification: true`, `needs_emergency_rescue: true`
  - **必须设置**：`overall_status: "紧急"`, `recommended_action: "立即告警"`

**情况2（紧急警告）：**
- **心跳变缓**：心率 < 60次/分（心动过缓）
  - **必须设置**：`heart_rate_slow: true`, `needs_emergency_alert: true`
- **血氧下降**：血氧饱和度 < 90%
  - **必须设置**：`oxygen_low: true`, `needs_emergency_alert: true`
- **呼吸异常**：呼吸频率过快（>30次/分）或过慢（<10次/分）
  - **必须设置**：`respiration_abnormal: true`, `needs_emergency_alert: true`

**情况3（注意）：**
- **血压异常**：血压过高或过低
  - **必须设置**：`blood_pressure_abnormal: true`

**📋 输出要求：**
1. 如果检测到心跳变平（直线），必须在 `description` 中详细描述：
   - 心电图显示的状态（直线/波形）
   - 心率数值（如果有显示）
   - 其他生命体征状态
   - 判断依据和危险程度
2. 必须设置相应的告警标志
3. 如果心跳变平，`alert_message` 必须包含："病人心跳变平，可能濒临死亡，需要立即通知家属到现场进行救护和临终陪伴！"
"""
        
        prompt += """

## 输出格式要求:
请严格按照以下JSON格式输出,不要添加任何额外文字。所有文本内容必须使用中文:
```json
{
    "timestamp": "当前分析时间",
    "scene_type": "bed_patient/iv_drip_only/monitoring_device",
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
            "skin_color": "正常/苍白/潮红/紫绀/异常",
            "expression": "中性/痛苦/恐惧/焦虑/担忧/沮丧/悲伤/null",
            "emotion_confidence": 0.85,
            "description": "详细描述观察到的面部和身体皮肤特征、情绪判断依据和异常情况（中文）。如果发现皮肤异常，必须详细描述异常部位、颜色、大小、形状等。如果未检测到人脸，必须说明'图片中未检测到人脸，无法进行表情分析'"
        },
        "iv_drip": {
            "detected": true/false,
            "fluid_level": "满/半满/袋子空/已打完",
            "bag_empty": true/false,
            "completely_empty": true/false,
            "needs_replacement": true/false,
            "needs_emergency_alert": true/false,
            "needs_phone_call": true/false
        },
        "vital_signs": {
            "detected": true/false,
            "heart_rate": 数值或null,
            "heart_rate_slow": true/false,
            "heart_rate_flat": true/false,
            "oxygen_saturation": 数值或null,
            "oxygen_low": true/false,
            "respiration_rate": 数值或null,
            "respiration_abnormal": true/false,
            "blood_pressure": "数值或null",
            "blood_pressure_abnormal": true/false,
            "critical_life_threat": true/false,
            "needs_family_notification": true/false,
            "needs_emergency_rescue": true/false,
            "description": "详细描述监控设备显示的数据和状态（中文）"
        }
    },
    "recommended_action": "立即告警/监控/无",
    "alert_message": "如果需要告警,生成简短中文告警信息"
}
```

重要提示:
1. **首先执行场景识别**：根据图片内容判断场景类型（病床/病人、仅吊瓶、生命监控设备）
2. **根据场景调整检测任务**：
   - 场景A（病床/病人）：执行检测任务1-5
   - 场景B（仅吊瓶）：只执行检测任务5（吊瓶监测）
   - 场景C（生命监控设备）：执行检测任务6（生命监控设备分析），如果同时有病床/病人，也执行1-5
3. 确保输出是有效的JSON格式
4. 所有文本内容必须使用中文，包括description、location、duration_estimate等字段
5. overall_status的值必须是"正常"、"注意"或"紧急"（中文）
6. 置信度分数范围0-1
7. 如果无法判断某项,设置为null
8. 优先考虑患者安全,宁可过度告警
9. 所有描述性文本必须使用中文，不要使用英文
10. **特别注意**：如果检测到心跳变平（直线），必须立即设置为最高优先级告警，并通知家属到现场

## 详细日志输出要求（用于调试和问题追踪）:
在description字段中，请详细描述你的观察和判断过程，特别是对于吊瓶检测：
- **吊瓶检测时**：必须详细描述你观察到的袋子/玻璃瓶状态：
  * 袋子/玻璃瓶上半部分的液体情况（有/无/部分）
  * 袋子/玻璃瓶下半部分的液体情况
  * 滴液管中的液体情况
  * 你的判断依据（为什么判定为"满"/"半满"/"袋子空"/"已打完"）
  * 如果判定为"袋子空"或"已打完"，必须说明危险程度和需要采取的行动
- **示例描述格式**：
  * "袋子/玻璃瓶上半部分已空，下半部分有少量液体，滴液管中有液体，判定为袋子空，需要立即警告"
  * "袋子/玻璃瓶完全空了，滴液管中也没有液体，判定为已打完，需要电话呼叫"
  * "袋子/玻璃瓶基本充满，上半部分有液体，判定为满，状态正常"
- **其他检测项**：同样需要在description中详细描述观察到的现象和判断依据
"""
        
        return prompt
    
    def _parse_response(self, response_text: str) -> Dict:
        """解析AI返回的结果，支持多种JSON格式修复"""
        try:
            # 提取JSON部分（尝试多种方式）
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            
            if json_start == -1 or json_end == 0:
                logger.warning("未找到JSON格式的响应")
                return {
                    "error": "No JSON found in response",
                    "raw_response": response_text
                }
            
            json_str = response_text[json_start:json_end]
            
            # 尝试直接解析
            try:
                result = json.loads(json_str)
                return result
            except json.JSONDecodeError as e:
                logger.warning(f"首次JSON解析失败，尝试修复: {e}")
                
                # 修复常见JSON格式问题
                fixed_json = json_str
                
                # 1. 移除代码块标记（如果存在）
                fixed_json = re.sub(r'```json\s*', '', fixed_json)
                fixed_json = re.sub(r'```\s*$', '', fixed_json)
                fixed_json = re.sub(r'^```\s*', '', fixed_json)
                
                # 2. 移除单行注释（// 开头的行）
                fixed_json = re.sub(r'//.*?$', '', fixed_json, flags=re.MULTILINE)
                
                # 3. 移除多行注释（/* ... */）
                fixed_json = re.sub(r'/\*.*?\*/', '', fixed_json, flags=re.DOTALL)
                
                # 4. 修复单引号为双引号（但要小心字符串内的引号）
                # 先处理属性名和值的单引号
                fixed_json = re.sub(r"'(\w+)':", r'"\1":', fixed_json)  # 属性名
                fixed_json = re.sub(r":\s*'([^']*)'", r': "\1"', fixed_json)  # 字符串值
                
                # 5. 移除尾随逗号（在 } 或 ] 之前）
                fixed_json = re.sub(r',(\s*[}\]])', r'\1', fixed_json)
                
                # 6. 修复布尔值（true/false可能被引号包围）
                fixed_json = re.sub(r':\s*"true"', r': true', fixed_json)
                fixed_json = re.sub(r':\s*"false"', r': false', fixed_json)
                fixed_json = re.sub(r':\s*"null"', r': null', fixed_json)
                
                # 7. 修复未加引号的属性名（如果存在）
                # 这个比较复杂，先尝试其他修复
                
                # 再次尝试解析
                try:
                    result = json.loads(fixed_json)
                    logger.info("JSON修复成功")
                    return result
                except json.JSONDecodeError as e2:
                    logger.error(f"JSON修复后仍失败: {e2}")
                    logger.debug(f"原始JSON (前500字符): {json_str[:500]}")
                    logger.debug(f"修复后JSON (前500字符): {fixed_json[:500]}")
                    
                    # 尝试使用更宽松的解析方式
                    # 使用 ast.literal_eval 作为最后手段（但只适用于Python字面量）
                    try:
                        import ast
                        # 将单引号字符串转换为双引号
                        python_literal = fixed_json.replace("'", '"')
                        result = ast.literal_eval(python_literal)
                        if isinstance(result, dict):
                            logger.info("使用ast.literal_eval解析成功")
                            return result
                    except:
                        pass
                    
                    # 如果所有方法都失败，返回错误
                    return {
                        "error": f"Parse error: {str(e2)}",
                        "raw_response": response_text,
                        "json_attempt": json_str[:500],
                        "fixed_attempt": fixed_json[:500]
                    }
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON解析失败: {e}")
            logger.debug(f"响应文本 (前1000字符): {response_text[:1000]}")
            return {
                "error": f"Parse error: {str(e)}",
                "raw_response": response_text[:1000]  # 只返回前1000字符避免过长
            }
        except Exception as e:
            logger.error(f"解析响应失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                "error": f"Parse error: {str(e)}",
                "raw_response": response_text[:1000]
            }


# 创建全局实例
gemini_analyzer = GeminiVisionAnalyzer()

