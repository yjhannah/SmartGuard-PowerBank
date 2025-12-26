#!/bin/bash
# 环境检查脚本
# 检查当前 Python 环境和依赖版本

cd "$(dirname "$0")"

echo "=========================================="
echo "  环境检查 - SmartGuard PowerBank"
echo "=========================================="
echo ""

# 检查是否在虚拟环境中
if [ -z "$VIRTUAL_ENV" ]; then
    echo "⚠️  当前不在虚拟环境中"
    if [ -f "venv/bin/activate" ]; then
        echo "   建议执行: source venv/bin/activate"
    fi
else
    echo "✅ 当前在虚拟环境中: $VIRTUAL_ENV"
fi

echo ""
echo "Python 信息:"
echo "  版本: $(python3 --version)"
echo "  路径: $(which python3)"
echo ""

echo "关键依赖版本:"
for package in fastapi uvicorn openai httpx aiosqlite pydantic; do
    if pip show "$package" &>/dev/null; then
        VERSION=$(pip show "$package" | grep Version | awk '{print $2}')
        echo "  ✅ $package: $VERSION"
    else
        echo "  ❌ $package: 未安装"
    fi
done

echo ""
echo "项目路径:"
echo "  当前目录: $(pwd)"
echo "  虚拟环境: $(pwd)/venv"
echo "  数据库: $(pwd)/data/hospital_monitoring.db"
echo ""

# 检查数据库
if [ -f "data/hospital_monitoring.db" ]; then
    DB_SIZE=$(du -h data/hospital_monitoring.db | awk '{print $1}')
    echo "✅ 数据库文件存在 (大小: $DB_SIZE)"
else
    echo "⚠️  数据库文件不存在"
fi

echo ""
echo "环境变量:"
echo "  PYTHONPATH: ${PYTHONPATH:-未设置}"
echo "  ENV_ENCRYPTION_KEY: ${ENV_ENCRYPTION_KEY:+已设置 (长度: ${#ENV_ENCRYPTION_KEY})}"
echo "  USE_ONE_API: ${USE_ONE_API:-未设置}"
echo "  ONE_API_BASE_URL: ${ONE_API_BASE_URL:-未设置}"
echo ""

