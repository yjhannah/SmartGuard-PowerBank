#!/bin/bash
# 重新编译 SmartGuard 移动应用
# 用于解决热重载无法更新配置常量的问题

set -e

cd "$(dirname "$0")"

echo "=========================================="
echo "  SmartGuard 移动应用 - 完全重新编译"
echo "=========================================="
echo ""

# 检查 Flutter 环境
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装或未在 PATH 中"
    echo "请先安装 Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter 版本:"
flutter --version | head -n 1
echo ""

# 步骤1: 清理构建缓存
echo "🗑️  步骤 1/4: 清理构建缓存..."
flutter clean
echo "✅ 清理完成"
echo ""

# 步骤2: 重新获取依赖
echo "📦 步骤 2/4: 重新获取依赖..."
flutter pub get
echo "✅ 依赖获取完成"
echo ""

# 步骤3: 检测可用设备
echo "📱 步骤 3/4: 检测可用设备..."
flutter devices

# 步骤4: 选择运行平台
echo ""
echo "=========================================="
echo "请选择运行平台:"
echo "  1) iOS 模拟器"
echo "  2) Android 模拟器/设备"
echo "  3) Chrome (Web)"
echo "  4) 仅构建，不运行"
echo "  5) 退出"
echo "=========================================="
read -p "请输入选项 (1-5): " choice

case $choice in
    1)
        echo ""
        echo "🚀 步骤 4/4: 在 iOS 模拟器上运行..."
        flutter run -d iPhone --verbose
        ;;
    2)
        echo ""
        echo "🚀 步骤 4/4: 在 Android 设备上运行..."
        flutter run -d android --verbose
        ;;
    3)
        echo ""
        echo "🚀 步骤 4/4: 在 Chrome 上运行..."
        flutter run -d chrome --verbose
        ;;
    4)
        echo ""
        echo "🔨 步骤 4/4: 仅构建..."
        echo "构建 Debug 版本..."
        
        # 检测平台并构建
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "构建 iOS..."
            flutter build ios --debug
        fi
        
        echo "构建 Android APK..."
        flutter build apk --debug
        
        echo "构建 Web..."
        flutter build web
        
        echo "✅ 构建完成"
        ;;
    5)
        echo "退出"
        exit 0
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "✅ 完成！"
echo "=========================================="
echo ""
echo "📋 验证修复:"
echo "1. 上传图片时查看控制台日志"
echo "2. 确认 URL 为: https://smartguard.gitagent.io/api/analysis/analyze"
echo "3. 确认响应状态码为: 200"
echo ""
echo "📖 详细信息请查看: URL_FIX_GUIDE.md"
echo ""

