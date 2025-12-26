#!/usr/bin/env python3
"""
环境变量加密脚本
用于加密 .env 文件为 .env.encrypted
支持密钥验证、备份和恢复功能
"""
import sys
import argparse
from pathlib import Path
from utils.env_encryption import generate_encryption_key, encrypt_env_file, decrypt_env_file, load_encrypted_env, parse_env_content

def encrypt_command(args):
    """加密命令"""
    project_root = Path(__file__).parent.parent
    env_file = project_root / (args.env_file or '.env')
    encrypted_file = project_root / (args.output or f'{env_file.name}.encrypted')
    key_file = project_root / '.env.encryption.key'
    
    # 检查明文文件是否存在
    if not env_file.exists():
        print(f"❌ 错误: 找不到文件 {env_file}")
        print("请先创建 .env 文件")
        sys.exit(1)
    
    # 检查密钥文件
    if key_file.exists() and not args.new_key:
        key = key_file.read_text().strip()
        print(f"✅ 使用现有密钥文件: {key_file}")
    else:
        # 生成新密钥
        if key_file.exists() and args.new_key:
            backup_key = project_root / f'.env.encryption.key.backup'
            backup_key.write_bytes(key_file.read_bytes())
            print(f"✅ 已备份旧密钥: {backup_key}")
        
        key = generate_encryption_key()
        key_file.write_text(key)
        key_file.chmod(0o600)  # 仅所有者可读写
        print(f"✅ 已生成新密钥: {key_file}")
        print(f"⚠️  请妥善保管密钥文件，不要提交到 Git")
    
    # 备份旧加密文件
    if encrypted_file.exists() and not args.force:
        backup_file = project_root / f'{encrypted_file.name}.backup'
        backup_file.write_bytes(encrypted_file.read_bytes())
        print(f"✅ 已备份旧加密文件: {backup_file}")
    
    # 加密文件
    try:
        encrypt_env_file(env_file, encrypted_file, key)
        print(f"✅ 加密完成: {encrypted_file}")
        
        # 验证加密文件
        try:
            env_vars = load_encrypted_env(encrypted_file, key)
            print(f"✅ 验证成功: 包含 {len(env_vars)} 个环境变量")
            
            # 显示关键变量（不显示值）
            important_vars = ['USE_ONE_API', 'ONE_API_KEY', 'GEMINI_API_KEY', 'DATABASE_URL']
            found_vars = [v for v in important_vars if v in env_vars]
            if found_vars:
                print(f"✅ 关键变量: {', '.join(found_vars)}")
        except Exception as e:
            print(f"❌ 验证失败: {e}")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ 加密失败: {e}")
        sys.exit(1)

def verify_command(args):
    """验证命令"""
    project_root = Path(__file__).parent.parent
    encrypted_file = project_root / (args.encrypted_file or '.env.encrypted')
    key_file = project_root / '.env.encryption.key'
    
    if not encrypted_file.exists():
        print(f"❌ 错误: 找不到加密文件 {encrypted_file}")
        sys.exit(1)
    
    # 获取密钥
    key = None
    if args.key:
        key = args.key
    elif key_file.exists():
        key = key_file.read_text().strip()
    else:
        import os
        key = os.getenv('ENV_ENCRYPTION_KEY')
    
    if not key:
        print("❌ 错误: 未找到加密密钥")
        print("请提供密钥文件、环境变量 ENV_ENCRYPTION_KEY 或使用 --key 参数")
        sys.exit(1)
    
    try:
        env_vars = load_encrypted_env(encrypted_file, key)
        print(f"✅ 验证成功: 加密文件有效")
        print(f"✅ 包含 {len(env_vars)} 个环境变量")
        return 0
    except Exception as e:
        print(f"❌ 验证失败: {e}")
        return 1

def decrypt_command(args):
    """解密命令（仅用于调试）"""
    project_root = Path(__file__).parent.parent
    encrypted_file = project_root / (args.encrypted_file or '.env.encrypted')
    key_file = project_root / '.env.encryption.key'
    
    if not encrypted_file.exists():
        print(f"❌ 错误: 找不到加密文件 {encrypted_file}")
        sys.exit(1)
    
    # 获取密钥
    key = None
    if args.key:
        key = args.key
    elif key_file.exists():
        key = key_file.read_text().strip()
    else:
        import os
        key = os.getenv('ENV_ENCRYPTION_KEY')
    
    if not key:
        print("❌ 错误: 未找到加密密钥")
        sys.exit(1)
    
    try:
        content = decrypt_env_file(encrypted_file, key)
        if args.output:
            output_file = Path(args.output)
            output_file.write_text(content)
            print(f"✅ 已解密到: {output_file}")
        else:
            print("=== 解密内容 ===")
            print(content)
    except Exception as e:
        print(f"❌ 解密失败: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='环境变量加密工具')
    subparsers = parser.add_subparsers(dest='command', help='命令')
    
    # 加密命令
    encrypt_parser = subparsers.add_parser('encrypt', help='加密环境变量文件')
    encrypt_parser.add_argument('--env-file', help='输入文件（默认: .env）')
    encrypt_parser.add_argument('--output', help='输出文件（默认: .env.encrypted）')
    encrypt_parser.add_argument('--new-key', action='store_true', help='生成新密钥')
    encrypt_parser.add_argument('--force', action='store_true', help='覆盖现有文件')
    
    # 验证命令
    verify_parser = subparsers.add_parser('verify', help='验证加密文件')
    verify_parser.add_argument('--encrypted-file', help='加密文件（默认: .env.encrypted）')
    verify_parser.add_argument('--key', help='加密密钥')
    
    # 解密命令
    decrypt_parser = subparsers.add_parser('decrypt', help='解密文件（调试用）')
    decrypt_parser.add_argument('--encrypted-file', help='加密文件（默认: .env.encrypted）')
    decrypt_parser.add_argument('--key', help='加密密钥')
    decrypt_parser.add_argument('--output', help='输出文件（默认: 打印到控制台）')
    
    args = parser.parse_args()
    
    if not args.command:
        # 默认执行加密
        encrypt_command(argparse.Namespace(env_file=None, output=None, new_key=False, force=False))
    elif args.command == 'encrypt':
        encrypt_command(args)
    elif args.command == 'verify':
        sys.exit(verify_command(args))
    elif args.command == 'decrypt':
        decrypt_command(args)

if __name__ == '__main__':
    main()

