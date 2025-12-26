"""
配置加载模块
自动加载加密的环境变量文件
"""
import os
import logging
from pathlib import Path
from typing import Optional
from pydantic_settings import BaseSettings
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from utils.env_encryption import load_encrypted_env

logger = logging.getLogger(__name__)

# 项目根目录
project_root = Path(__file__).parent.parent.parent


class Settings(BaseSettings):
    """应用配置"""
    
    # 数据库配置
    database_url: str = "sqlite:///./data/hospital_monitoring.db"
    
    # One-API 配置（用于 Gemini）
    use_one_api: bool = True
    one_api_base_url: Optional[str] = None
    one_api_key: Optional[str] = None
    one_api_gemini_model: str = "gemini-2.0-flash"
    one_api_gemini_vision_model: str = "gemini-2.0-flash-exp"
    
    # 直接 Gemini API 配置（备用）
    gemini_api_key: Optional[str] = None
    
    # 服务器配置
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    
    # CORS配置
    cors_origins: list = ["*"]
    
    class Config:
        env_file = ".env"
        case_sensitive = False


def load_encrypted_env_vars():
    """加载加密的环境变量文件到系统环境"""
    try:
        encrypted_file = project_root / '.env.encrypted'
        key_file = project_root / '.env.encryption.key'
        
        # 尝试加载加密环境变量
        env_vars = load_encrypted_env(
            encrypted_file=encrypted_file,
            key_file=key_file if key_file.exists() else None
        )
        
        # 加载到系统环境（不覆盖已存在的）
        for key, value in env_vars.items():
            if key not in os.environ:
                os.environ[key] = value
        
        logger.info(f"✅ 已加载加密环境变量: {len(env_vars)} 个")
        return True
    except Exception as e:
        logger.warning(f"⚠️ 加载加密环境变量失败: {e}，将使用系统环境变量")
        return False


# 模块加载时自动执行
load_encrypted_env_vars()

# 创建全局配置实例（BaseSettings 会自动从环境变量读取）
settings = Settings()

# 从环境变量覆盖配置（确保环境变量优先）
# 注意：BaseSettings 应该已经读取了环境变量，这里再次覆盖以确保正确
if os.getenv('USE_ONE_API'):
    settings.use_one_api = os.getenv('USE_ONE_API').lower() == 'true'
if os.getenv('ONE_API_BASE_URL'):
    settings.one_api_base_url = os.getenv('ONE_API_BASE_URL')
if os.getenv('ONE_API_KEY'):
    settings.one_api_key = os.getenv('ONE_API_KEY')
if os.getenv('ONE_API_GEMINI_MODEL'):
    settings.one_api_gemini_model = os.getenv('ONE_API_GEMINI_MODEL')
if os.getenv('ONE_API_GEMINI_VISION_MODEL'):
    settings.one_api_gemini_vision_model = os.getenv('ONE_API_GEMINI_VISION_MODEL')
if os.getenv('GEMINI_API_KEY'):
    settings.gemini_api_key = os.getenv('GEMINI_API_KEY')
if os.getenv('DATABASE_URL'):
    settings.database_url = os.getenv('DATABASE_URL')

# 记录最终配置（用于调试）
logger.debug(f"🔧 [配置] USE_ONE_API: {settings.use_one_api}")
logger.debug(f"🔧 [配置] ONE_API_BASE_URL: {settings.one_api_base_url}")
logger.debug(f"🔧 [配置] ONE_API_KEY: {'已设置' if settings.one_api_key else '未设置'}")
logger.debug(f"🔧 [配置] ONE_API_GEMINI_VISION_MODEL: {settings.one_api_gemini_vision_model}")

