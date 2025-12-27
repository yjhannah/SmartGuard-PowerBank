"""
Pydantic数据模型
用于API请求和响应验证
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class PatientCreate(BaseModel):
    patient_code: str
    full_name: str
    gender: Optional[str] = None
    age: Optional[int] = None
    admission_date: Optional[str] = None
    diagnosis: Optional[str] = None
    risk_level: str = "medium"
    ward_id: Optional[str] = None
    bed_number: Optional[str] = None


class PatientResponse(BaseModel):
    patient_id: str
    patient_code: str
    full_name: str
    gender: Optional[str]
    age: Optional[int]
    admission_date: Optional[str]
    diagnosis: Optional[str]
    risk_level: str
    ward_id: Optional[str]
    bed_number: Optional[str]
    is_hospitalized: bool


class MonitoringConfigUpdate(BaseModel):
    fall_detection_enabled: Optional[bool] = None
    bed_exit_detection_enabled: Optional[bool] = None
    facial_analysis_enabled: Optional[bool] = None
    abnormal_activity_enabled: Optional[bool] = None
    iv_drip_monitoring_enabled: Optional[bool] = None
    bed_exit_threshold_minutes: Optional[int] = None


class AlertAcknowledge(BaseModel):
    user_id: str


class AlertResolve(BaseModel):
    user_id: str
    resolution_notes: str


class AlertResponse(BaseModel):
    alert_id: str
    patient_id: str
    alert_type: str
    severity: str
    title: str
    description: str
    status: str
    created_at: str


class AnalysisResponse(BaseModel):
    status: str
    result_id: Optional[str] = None
    analysis: Optional[dict] = None
    error: Optional[str] = None


# 移动端相关模型
class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    user_id: str
    username: str
    role: str
    full_name: Optional[str] = None
    patient_id: Optional[str] = None
    token: Optional[str] = None  # 简单token，实际可用JWT


class QRCodeGenerateResponse(BaseModel):
    qr_code_url: str
    token: str
    expires_at: str


class QRCodeScanRequest(BaseModel):
    token: str
    user_id: str


class HealthReportResponse(BaseModel):
    report_date: str
    summary_text: str
    status_icon: str


class ActivityRecord(BaseModel):
    time: str
    activity_type: str
    value: Optional[float] = None
    medication_name: Optional[str] = None


class ActivityChartResponse(BaseModel):
    records: List[ActivityRecord]


class EmotionGaugeResponse(BaseModel):
    emotion_level: str  # positive, neutral, negative
    score: Optional[float] = None


class VoiceAlertRequest(BaseModel):
    patient_id: str
    alert_type: str
    message: str


class CallRequest(BaseModel):
    user_id: str
    patient_id: Optional[str] = None
    call_type: str  # nurse or message
    phone_number: Optional[str] = None
    message_content: Optional[str] = None

