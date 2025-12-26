#!/usr/bin/env python3
"""
测试One-API连接脚本
"""
import sys
import os
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.core.config import settings
from app.core.logging_config import setup_logging
from urllib.parse import urlparse
import socket
import subprocess
import platform
import asyncio
from openai import OpenAI
from datetime import datetime

# 初始化日志
logger = setup_logging(log_dir=str(project_root / "logs"), log_level="INFO")

def test_network_connection(host: str, port: int):
    """测试网络连接"""
    print("=" * 60)
    print("🔍 网络连接测试")
    print("=" * 60)
    
    # 1. DNS解析
    try:
        ip = socket.gethostbyname(host)
        print(f"✅ DNS解析成功: {host} -> {ip}")
    except socket.gaierror as e:
        print(f"❌ DNS解析失败: {host} - {e}")
        return False
    
    # 2. TCP连接测试
    try:
        print(f"🔍 测试TCP连接: {host}:{port}...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((host, port))
        sock.close()
        
        if result == 0:
            print(f"✅ TCP连接成功: {host}:{port}")
        else:
            print(f"❌ TCP连接失败: {host}:{port} (错误码: {result})")
            return False
    except Exception as e:
        print(f"❌ TCP连接测试异常: {e}")
        return False
    
    # 3. Ping测试
    try:
        print(f"🔍 测试Ping: {host}...")
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
            print(f"✅ Ping成功: {host}")
            # 提取IP地址
            import re
            ip_match = re.search(r'\((\d+\.\d+\.\d+\.\d+)\)', ping_result.stdout)
            if ip_match:
                print(f"📍 Ping解析IP: {ip_match.group(1)}")
        else:
            print(f"⚠️ Ping失败: {host} (可能被防火墙阻止)")
    except Exception as e:
        print(f"⚠️ Ping测试跳过: {e}")
    
    return True

async def test_oneapi_api_call():
    """测试One-API API调用"""
    print("=" * 60)
    print("🔍 One-API API调用测试")
    print("=" * 60)
    
    if not settings.one_api_base_url or not settings.one_api_key:
        print("❌ One-API未配置")
        print(f"   Base URL: {settings.one_api_base_url or '未设置'}")
        print(f"   API Key: {'已设置' if settings.one_api_key else '未设置'}")
        return False
    
    # 解析URL
    parsed_url = urlparse(settings.one_api_base_url)
    host = parsed_url.hostname
    port = parsed_url.port or (443 if parsed_url.scheme == 'https' else 80)
    
    # 显示配置信息
    api_key_display = f"{settings.one_api_key[:4]}...{settings.one_api_key[-4:]}" if len(settings.one_api_key) >= 8 else "***"
    print(f"📡 Base URL: {settings.one_api_base_url}")
    print(f"🌐 主机地址: {host}")
    print(f"🔌 端口: {port}")
    print(f"🔑 API Key: {api_key_display}")
    print(f"🤖 模型: {settings.one_api_gemini_vision_model}")
    print()
    
    # 先测试网络连接
    if not test_network_connection(host, port):
        print("❌ 网络连接失败，无法继续API测试")
        return False
    
    print()
    print("=" * 60)
    print("🚀 开始API调用测试...")
    print("=" * 60)
    
    try:
        # 创建客户端
        client = OpenAI(
            base_url=settings.one_api_base_url,
            api_key=settings.one_api_key,
            timeout=30.0  # 30秒超时用于测试
        )
        
        print(f"✅ OpenAI客户端创建成功")
        print(f"🔍 发送测试请求...")
        
        start_time = datetime.now()
        
        # 发送简单文本请求测试
        response = await asyncio.to_thread(
            lambda: client.chat.completions.create(
                model=settings.one_api_gemini_vision_model,
                messages=[
                    {
                        "role": "user",
                        "content": "你好，请回复'测试成功'"
                    }
                ],
                max_tokens=50,
                temperature=0.1
            )
        )
        
        duration = (datetime.now() - start_time).total_seconds()
        
        if response and response.choices:
            result_text = response.choices[0].message.content
            print(f"✅ API调用成功！")
            print(f"⏱️ 响应时间: {duration:.2f}秒")
            print(f"📝 响应内容: {result_text}")
            return True
        else:
            print(f"❌ API调用返回空响应")
            return False
            
    except Exception as e:
        duration = (datetime.now() - start_time).total_seconds() if 'start_time' in locals() else 0
        print(f"❌ API调用失败")
        print(f"⏱️ 失败时间: {duration:.2f}秒")
        print(f"❌ 错误类型: {type(e).__name__}")
        print(f"❌ 错误信息: {str(e)}")
        
        import traceback
        print(f"\n完整错误堆栈:")
        print(traceback.format_exc())
        return False

def main():
    """主函数"""
    print("=" * 60)
    print("One-API 连接测试工具")
    print("=" * 60)
    print()
    
    # 检查配置
    print("📋 配置检查:")
    print(f"   USE_ONE_API: {settings.use_one_api}")
    print(f"   ONE_API_BASE_URL: {settings.one_api_base_url or '未设置'}")
    print(f"   ONE_API_KEY: {'已设置' if settings.one_api_key else '未设置'}")
    print(f"   模型: {settings.one_api_gemini_vision_model}")
    print()
    
    if not settings.use_one_api:
        print("⚠️ USE_ONE_API设置为False，跳过测试")
        return
    
    if not settings.one_api_base_url or not settings.one_api_key:
        print("❌ One-API配置不完整，无法测试")
        return
    
    # 运行测试
    try:
        result = asyncio.run(test_oneapi_api_call())
        print()
        print("=" * 60)
        if result:
            print("✅ 测试完成：One-API连接成功！")
        else:
            print("❌ 测试完成：One-API连接失败！")
        print("=" * 60)
    except KeyboardInterrupt:
        print("\n⚠️ 测试被用户中断")
    except Exception as e:
        print(f"\n❌ 测试过程异常: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

