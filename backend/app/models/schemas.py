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

