#!/usr/bin/env python3
"""
生产环境启动脚本
确保环境变量在应用启动前正确加载
"""
import os
import sys
from pathlib import Path

# 设置项目根目录
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# 加载加密环境变量（如果存在）
encrypted_file = project_root / '.env.encrypted'
key_file = project_root / '.env.encryption.key'

if encrypted_file.exists() and key_file.exists():
    try:
        from utils.env_encryption import decrypt_env_file, parse_env_content
        
        key = key_file.read_text().strip()
        content = decrypt_env_file(encrypted_file, key)
        env_vars = parse_env_content(content)
        
        # 加载到系统环境（不覆盖已存在的）
        for k, v in env_vars.items():
            if k not in os.environ:
                os.environ[k] = v
        
        print(f"✅ 已加载加密环境变量: {len(env_vars)} 个")
    except Exception as e:
        print(f"⚠️  加载加密环境变量失败: {e}")

# 确保 One-API 配置已设置
if not os.getenv('ONE_API_BASE_URL') or not os.getenv('ONE_API_KEY'):
    # 尝试从 .env.production 读取
    env_prod_file = project_root / '.env.production'
    if env_prod_file.exists():
        with open(env_prod_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    if key in ['USE_ONE_API', 'ONE_API_BASE_URL', 'ONE_API_KEY', 'ONE_API_GEMINI_MODEL', 'ONE_API_GEMINI_VISION_MODEL']:
                        if key not in os.environ:
                            os.environ[key] = value
    
    # 如果还是没有，使用默认值
    os.environ.setdefault('USE_ONE_API', 'true')
    os.environ.setdefault('ONE_API_BASE_URL', 'http://104.154.76.119:3000/v1')
    os.environ.setdefault('ONE_API_KEY', 'sk-7UokIik5JjNUPIft42A9E9F01f7d4738973aC119C5E26e2c')
    os.environ.setdefault('ONE_API_GEMINI_VISION_MODEL', 'gemini-2.0-flash-exp')

# 验证环境变量
print("\n📋 环境变量配置:")
print(f"  USE_ONE_API: {os.getenv('USE_ONE_API')}")
print(f"  ONE_API_BASE_URL: {os.getenv('ONE_API_BASE_URL')}")
print(f"  ONE_API_KEY: {os.getenv('ONE_API_KEY', '')[:10]}...{os.getenv('ONE_API_KEY', '')[-4:] if len(os.getenv('ONE_API_KEY', '')) > 14 else ''}")
print(f"  ONE_API_GEMINI_VISION_MODEL: {os.getenv('ONE_API_GEMINI_VISION_MODEL')}")
print("")

# 导入并启动应用
import uvicorn

port = int(os.getenv('PORT', '8001'))
print(f"🚀 启动服务在端口 {port}...")

uvicorn.run(
    "app.main:app",
    host="0.0.0.0",
    port=port,
    log_level="info"
)

