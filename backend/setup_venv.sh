#!/bin/bash
# 虚拟环境设置脚本
# 确保项目使用独立的虚拟环境，避免多项目冲突

set -e

cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"
VENV_DIR="${PROJECT_ROOT}/venv"
VENV_PYTHON="${VENV_DIR}/bin/python3"
VENV_PIP="${VENV_DIR}/bin/pip"

echo "=========================================="
echo "  虚拟环境设置 - SmartGuard PowerBank"
echo "=========================================="
echo ""
echo "项目路径: $PROJECT_ROOT"
echo "虚拟环境: $VENV_DIR"
echo ""

# 检查 Python 版本
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 Python3，请先安装 Python 3.10+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo "✅ Python 版本: $PYTHON_VERSION"

# 检查 Python 版本是否符合要求（3.10+）
PYTHON_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
PYTHON_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    echo "❌ Python 版本过低，需要 Python 3.10+"
    exit 1
fi

# 创建虚拟环境（如果不存在）
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv "$VENV_DIR"
    echo "✅ 虚拟环境创建完成"
else
    echo "✅ 虚拟环境已存在"
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source "${VENV_DIR}/bin/activate"

# 升级 pip
echo "📦 升级 pip..."
"$VENV_PIP" install --upgrade pip -q

# 安装依赖
if [ -f "${PROJECT_ROOT}/requirements.txt" ]; then
    echo "📦 安装项目依赖..."
    "$VENV_PIP" install -r "${PROJECT_ROOT}/requirements.txt" -q
    echo "✅ 依赖安装完成"
else
    echo "⚠️  未找到 requirements.txt"
fi

# 验证虚拟环境
echo ""
echo "=========================================="
echo "  虚拟环境验证"
echo "=========================================="
echo "Python 路径: $($VENV_PYTHON -c 'import sys; print(sys.executable)')"
echo "Python 版本: $($VENV_PYTHON --version)"
echo ""

# 检查关键包
echo "检查关键依赖包:"
for package in fastapi uvicorn openai aiosqlite; do
    if "$VENV_PIP" show "$package" &>/dev/null; then
        VERSION=$("$VENV_PIP" show "$package" | grep Version | awk '{print $2}')
        echo "  ✅ $package: $VERSION"
    else
        echo "  ❌ $package: 未安装"
    fi
done

echo ""
echo "=========================================="
echo "✅ 虚拟环境设置完成！"
echo "=========================================="
echo ""
echo "使用方式:"
echo "  1. 激活虚拟环境: source venv/bin/activate"
echo "  2. 启动服务: bash start_production.sh"
echo "  3. 或直接使用: ./start_production.sh (脚本会自动激活虚拟环境)"
echo ""

