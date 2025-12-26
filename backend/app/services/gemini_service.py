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
import google.generativeai as genai
from app.core.config import settings

logger = logging.getLogger(__name__)


class GeminiVisionAnalyzer:
    """Gemini 视觉分析器"""
    
    def __init__(self):
        self.use_one_api = settings.use_one_api
        self.one_api_client = None
        self.gemini_client = None
        
        # 初始化客户端
        if self.use_one_api and settings.one_api_base_url and settings.one_api_key:
            # One-API 模式（使用 OpenAI 客户端）
            self.one_api_client = OpenAI(
                base_url=settings.one_api_base_url,
                api_key=settings.one_api_key
            )
            logger.info("✅ 使用 One-API 模式连接 Gemini")
        elif settings.gemini_api_key:
            # 直接 Gemini API 模式
            genai.configure(api_key=settings.gemini_api_key)
            self.gemini_client = genai.GenerativeModel(settings.one_api_gemini_vision_model)
            logger.info("✅ 使用直接 Gemini API 模式")
        else:
            logger.warning("⚠️ 未配置 Gemini API，AI 分析功能将不可用")
    
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
        try:
            # 构建提示词
            prompt = self._build_analysis_prompt(patient_context, detection_modes)
            
            # 调用 AI 服务
            if self.use_one_api and self.one_api_client:
                result = await self._analyze_with_one_api(image_bytes, prompt)
            elif self.gemini_client:
                result = await self._analyze_with_gemini(image_bytes, prompt)
            else:
                return {
                    "error": "AI服务未配置",
                    "status": "failed"
                }
            
            # 解析结果
            parsed_result = self._parse_response(result)
            return parsed_result
            
        except Exception as e:
            logger.error(f"❌ AI分析失败: {e}")
            return {
                "error": str(e),
                "status": "failed"
            }
    
    async def _analyze_with_one_api(self, image_bytes: bytes, prompt: str) -> str:
        """使用 One-API 调用 Gemini"""
        # 将图片转换为 base64
        image_base64 = base64.b64encode(image_bytes).decode('utf-8')
        image_data_url = f"data:image/jpeg;base64,{image_base64}"
        
        # 调用 OpenAI 兼容接口
        response = self.one_api_client.chat.completions.create(
            model=settings.one_api_gemini_vision_model,
            messages=[
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
            ],
            temperature=0.1,
            max_tokens=2048
        )
        
        return response.choices[0].message.content
    
    async def _analyze_with_gemini(self, image_bytes: bytes, prompt: str) -> str:
        """直接使用 Gemini API"""
        # 转换图片
        image = Image.open(BytesIO(image_bytes))
        
        response = self.gemini_client.generate_content(
            [prompt, image],
            generation_config={
                "temperature": 0.1,
                "top_p": 0.8,
                "top_k": 40,
                "max_output_tokens": 2048,
            }
        )
        
        return response.text
    
    def _build_analysis_prompt(
        self,
        patient_context: Dict,
        detection_modes: List[str]
    ) -> str:
        """构建结构化提示词"""
        
        prompt = f"""你是一个专业的医疗监护AI助手,正在分析医院病房监控画面。

## 患者信息:
- 姓名: {patient_context.get('name', '未知')}
- 年龄: {patient_context.get('age', '未知')}
- 诊断: {patient_context.get('diagnosis', '未知')}
- 风险等级: {patient_context.get('risk_level', 'medium')}

## 分析任务:
请仔细分析图像,检测以下场景(如果启用):

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
请严格按照以下JSON格式输出,不要添加任何额外文字:
```json
{
    "timestamp": "当前分析时间",
    "overall_status": "normal/attention/critical",
    "detections": {
        "fall": {
            "detected": true/false,
            "confidence": 0.95,
            "description": "具体描述",
            "severity": "critical/high/medium/low"
        },
        "bed_exit": {
            "patient_in_bed": true/false,
            "location": "bed/bathroom/room",
            "duration_estimate": "估算离床时长"
        },
        "activity": {
            "type": "normal/struggling/rigid/crawling/none",
            "description": "活动描述",
            "abnormal": true/false
        },
        "facial_analysis": {
            "skin_color": "normal/pale/flushed/cyanotic",
            "expression": "neutral/pain/fear/distress",
            "emotion_confidence": 0.85
        },
        "iv_drip": {
            "detected": true/false,
            "fluid_level": "full/half/low/empty",
            "needs_replacement": true/false
        }
    },
    "recommended_action": "immediate_alert/monitor/none",
    "alert_message": "如果需要告警,生成简短中文告警信息"
}
```

重要提示:
1. 确保输出是有效的JSON格式
2. 置信度分数范围0-1
3. 如果无法判断某项,设置为null
4. 优先考虑患者安全,宁可过度告警
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

