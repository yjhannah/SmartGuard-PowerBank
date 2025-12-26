"""
环境变量加密工具模块
使用 Fernet 对称加密算法加密环境变量文件
"""
from pathlib import Path
from typing import Dict, Optional
from cryptography.fernet import Fernet, InvalidToken
import logging

logger = logging.getLogger(__name__)


def generate_encryption_key() -> str:
    """生成新的 Fernet 加密密钥"""
    key = Fernet.generate_key()
    return key.decode('utf-8')


def encrypt_env_file(env_file: Path, encrypted_file: Path, key: str) -> None:
    """加密环境变量文件"""
    try:
        # 读取明文内容
        with open(env_file, 'rb') as f:
            plaintext = f.read()
        
        # 使用 Fernet 加密
        fernet = Fernet(key.encode('utf-8'))
        encrypted_data = fernet.encrypt(plaintext)
        
        # 保存加密文件
        with open(encrypted_file, 'wb') as f:
            f.write(encrypted_data)
        
        logger.info(f"✅ 环境变量文件已加密: {encrypted_file}")
    except Exception as e:
        logger.error(f"❌ 加密失败: {e}")
        raise


def decrypt_env_file(encrypted_file: Path, key: str) -> str:
    """解密环境变量文件并返回内容"""
    try:
        # 读取加密内容
        with open(encrypted_file, 'rb') as f:
            encrypted_data = f.read()
        
        # 使用 Fernet 解密
        fernet = Fernet(key.encode('utf-8'))
        plaintext = fernet.decrypt(encrypted_data)
        
        return plaintext.decode('utf-8')
    except InvalidToken:
        logger.error("❌ 解密失败: 无效的密钥或文件已损坏")
        raise
    except Exception as e:
        logger.error(f"❌ 解密失败: {e}")
        raise


def parse_env_content(content: str) -> Dict[str, str]:
    """解析 .env 文件内容为字典"""
    env_vars = {}
    for line in content.split('\n'):
        line = line.strip()
        
        # 跳过空行和注释
        if not line or line.startswith('#'):
            continue
        
        # 解析 KEY=VALUE 格式
        if '=' in line:
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()
            
            # 移除引号
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            elif value.startswith("'") and value.endswith("'"):
                value = value[1:-1]
            
            env_vars[key] = value
    
    return env_vars


def load_encrypted_env(
    encrypted_file: Optional[Path] = None,
    key: Optional[str] = None,
    key_file: Optional[Path] = None
) -> Dict[str, str]:
    """
    加载加密的环境变量文件
    
    Args:
        encrypted_file: 加密文件路径
        key: 加密密钥（字符串）
        key_file: 密钥文件路径
    
    Returns:
        解析后的环境变量字典
    """
    import os
    
    # 获取项目根目录
    project_root = Path(__file__).parent.parent
    
    # 默认加密文件路径
    if encrypted_file is None:
        encrypted_file = project_root / '.env.encrypted'
    
    # 获取加密密钥
    if key is None:
        # 优先从环境变量获取
        key = os.getenv('ENV_ENCRYPTION_KEY')
        
        # 其次从密钥文件获取
        if key is None:
            if key_file is None:
                key_file = project_root / '.env.encryption.key'
            
            if key_file.exists():
                key = key_file.read_text().strip()
    
    if not key:
        raise ValueError("未找到加密密钥，请设置 ENV_ENCRYPTION_KEY 环境变量或提供密钥文件")
    
    if not encrypted_file.exists():
        logger.warning(f"⚠️ 加密文件不存在: {encrypted_file}")
        return {}
    
    # 解密文件
    content = decrypt_env_file(encrypted_file, key)
    
    # 解析环境变量
    env_vars = parse_env_content(content)
    
    logger.info(f"✅ 已加载 {len(env_vars)} 个环境变量")
    
    return env_vars

