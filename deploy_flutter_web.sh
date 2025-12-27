#!/bin/bash
# SmartGuard Flutter Web编译和部署脚本（服务器端编译版本）
# 日期: 2025-12-27
# 说明: 在服务器上直接编译Flutter Web并部署，避免本地编译兼容性问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 SmartGuard Flutter Web 服务器端编译和部署${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 项目配置
FLUTTER_PROJECT_DIR="mobile_app"
SERVER_KEY="$HOME/.ssh/id_rsa_google_longterm"
SERVER_USER="support"
SERVER_HOST="34.87.2.104"
SERVER_FLUTTER_PATH="/home/support/flutter/bin/flutter"
SERVER_WECHAT_KIT_PATH="/home/support/wechat_kit"
SERVER_PROJECT_PATH="/home/support/smartguard"
DOMAIN="smartguard.gitagent.io"
FRONTEND_PORT=8080

# ========================================
# 步骤1: 检查本地项目
# ========================================
echo -e "${YELLOW}[1/7] 检查本地项目...${NC}"

if [ ! -d "$FLUTTER_PROJECT_DIR" ]; then
    echo -e "${RED}❌ 错误: 找不到Flutter项目目录${NC}"
    echo -e "   期望目录: $FLUTTER_PROJECT_DIR/"
    exit 1
fi

echo -e "${GREEN}✅ 本地项目目录存在${NC}"

# 检查API配置
API_CONFIG_FILE="$FLUTTER_PROJECT_DIR/lib/core/config/app_config.dart"
if [ ! -f "$API_CONFIG_FILE" ]; then
    echo -e "${RED}❌ API配置文件不存在${NC}"
    exit 1
fi

echo -e "${CYAN}检查API配置:${NC}"
API_URL=$(grep "baseUrl" "$API_CONFIG_FILE" | grep -v "//" | head -1)
echo "$API_URL"

if echo "$API_URL" | grep -q "smartguard.gitagent.io\|https://"; then
    echo -e "${GREEN}✅ API配置检查通过${NC}"
elif echo "$API_URL" | grep -q "localhost\|127.0.0.1"; then
    echo -e "${YELLOW}⚠️  警告: API配置为localhost，部署前需要修改为生产环境地址${NC}"
    read -p "是否继续部署? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# ========================================
# 步骤2: 上传Flutter项目到服务器
# ========================================
echo -e "${YELLOW}[2/7] 上传Flutter项目到服务器...${NC}"

# 打包项目（排除build目录和macOS系统文件）
echo -e "${CYAN}打包项目文件（排除macOS系统文件和构建产物）...${NC}"
cd "$FLUTTER_PROJECT_DIR"

# 清理macOS系统文件
find . -name "._*" -type f -delete 2>/dev/null || true
find . -type f -exec xattr -c {} \; 2>/dev/null || true

# 打包时排除系统文件和构建产物
tar --exclude='build' \
    --exclude='.dart_tool' \
    --exclude='*.iml' \
    --exclude='._*' \
    --exclude='.DS_Store' \
    --exclude='ios' \
    --exclude='android' \
    --exclude='macos' \
    --exclude='windows' \
    --exclude='linux' \
    --exclude='wechat_kit' \
    -czf ../flutter_project.tar.gz .
cd ..

# 显示打包文件大小
PACKAGE_SIZE=$(du -h flutter_project.tar.gz | awk '{print $1}')
echo -e "${CYAN}打包完成: ${PACKAGE_SIZE}${NC}"

# 上传到服务器
echo -e "${CYAN}上传到服务器...${NC}"
scp -i "$SERVER_KEY" \
    flutter_project.tar.gz \
    "${SERVER_USER}@${SERVER_HOST}:/tmp/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 项目已上传${NC}"
    rm -f flutter_project.tar.gz
else
    echo -e "${RED}❌ 上传失败${NC}"
    exit 1
fi
echo ""

# ========================================
# 步骤3: 在服务器上编译Flutter Web
# ========================================
echo -e "${YELLOW}[3/7] 在服务器上编译Flutter Web...${NC}"

ssh -i "$SERVER_KEY" "${SERVER_USER}@${SERVER_HOST}" << 'ENDSSH'
set -e

echo "🔧 准备编译环境..."

# Flutter路径
FLUTTER_BIN="/home/support/flutter/bin/flutter"
WECHAT_KIT_PATH="/home/support/wechat_kit"

# 检查Flutter
if [ ! -f "$FLUTTER_BIN" ]; then
    echo "❌ Flutter未找到: $FLUTTER_BIN"
    echo "请先安装Flutter SDK"
    exit 1
fi

echo "✅ Flutter路径: $FLUTTER_BIN"

# 检查wechat_kit
if [ -d "$WECHAT_KIT_PATH" ]; then
    echo "✅ wechat_kit路径: $WECHAT_KIT_PATH"
else
    echo "⚠️  wechat_kit未找到，将使用注释掉的依赖"
fi

# 设置PATH
export PATH="/home/support/flutter/bin:$PATH"

# 显示Flutter版本
echo ""
echo "📋 Flutter版本:"
$FLUTTER_BIN --version | head -3

# 解压项目
echo ""
echo "📦 解压项目..."
cd /tmp
rm -rf smartguard_mobile
mkdir -p smartguard_mobile
tar -xzf flutter_project.tar.gz -C smartguard_mobile/

# 进入项目目录
cd smartguard_mobile

# 清理macOS系统文件（._*文件）
echo ""
echo "🧹 清理macOS系统文件..."
find . -name "._*" -type f -delete 2>/dev/null || true
find . -type f -exec xattr -c {} \; 2>/dev/null || true
echo "✅ 清理完成"

# 配置wechat_kit依赖（服务器上有wechat_kit目录）
echo ""
echo "🔧 配置wechat_kit依赖..."
if [ -d "/home/support/wechat_kit" ]; then
    # 恢复wechat_kit依赖配置
    sed -i 's|# wechat_kit:|wechat_kit:|g' pubspec.yaml
    sed -i 's|#   path: ../wechat_kit|    path: /home/support/wechat_kit|g' pubspec.yaml
    echo "✅ wechat_kit依赖已配置"
else
    echo "⚠️  wechat_kit目录不存在，跳过配置"
fi

# 更新API配置为生产环境
echo ""
echo "🔧 更新API配置为生产环境..."
sed -i 's|http://localhost:8000|https://smartguard.gitagent.io|g' lib/core/config/app_config.dart
sed -i 's|ws://localhost:8000|wss://smartguard.gitagent.io|g' lib/core/config/app_config.dart
echo "✅ API配置已更新"

# 更新pubspec.yaml中的wechat_kit路径（如果存在）
if [ -d "$WECHAT_KIT_PATH" ]; then
    echo ""
    echo "🔧 更新wechat_kit依赖路径..."
    sed -i "s|# wechat_kit:|wechat_kit:|g" pubspec.yaml
    sed -i "s|#   path: ../wechat_kit|    path: $WECHAT_KIT_PATH|g" pubspec.yaml
    echo "✅ wechat_kit路径已更新"
fi

# 配置Web平台（如果未配置）
echo ""
echo "🔧 配置Web平台..."
if [ ! -d "web" ]; then
    echo "创建Web平台配置..."
    $FLUTTER_BIN create . --platforms web
fi

# 清理旧编译产物
echo ""
echo "🧹 清理旧编译产物..."
$FLUTTER_BIN clean
rm -rf build/web

# 获取依赖
echo ""
echo "📥 获取依赖..."
$FLUTTER_BIN pub get

# 编译Web版本
echo ""
echo "🔨 开始编译Flutter Web (release模式)..."
echo "⏰ 这可能需要2-5分钟，请耐心等待..."
$FLUTTER_BIN build web --release

# 检查编译结果
if [ ! -d "build/web" ]; then
    echo "❌ 编译失败: build/web目录不存在"
    exit 1
fi

echo ""
echo "✅ Flutter Web编译成功！"
echo ""
echo "📊 编译产物:"
ls -lh build/web/ | head -10

ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 服务器编译失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 服务器编译完成${NC}"
echo ""

# ========================================
# 步骤4: 备份现有文件
# ========================================
echo -e "${YELLOW}[4/7] 备份服务器现有文件...${NC}"

ssh -i "$SERVER_KEY" "${SERVER_USER}@${SERVER_HOST}" << 'ENDSSH'
# 创建备份目录
BACKUP_DIR="/tmp/smartguard_web_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

cd /home/support/smartguard

# 创建前端目录（如果不存在）
mkdir -p frontend

cd frontend

# 备份关键文件
echo "📦 备份以下文件:"
for file in index.html main.dart.js flutter.js version.json manifest.json; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/" 2>/dev/null
        echo "  ✓ $file"
    fi
done

# 备份目录
for dir in assets canvaskit; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$BACKUP_DIR/" 2>/dev/null
        echo "  ✓ $dir/"
    fi
done

echo ""
echo "💾 备份完成: $BACKUP_DIR"
if [ -n "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
    echo "📊 备份内容:"
    ls -lh "$BACKUP_DIR/" | head -10
else
    echo "ℹ️  无现有文件需要备份"
fi

ENDSSH

echo ""

# ========================================
# 步骤5: 部署Flutter Web
# ========================================
echo -e "${YELLOW}[5/7] 部署Flutter Web...${NC}"

ssh -i "$SERVER_KEY" "${SERVER_USER}@${SERVER_HOST}" << 'ENDSSH'
set -e

echo "🚀 开始部署..."

# 源目录和目标目录
SOURCE_DIR="/tmp/smartguard_mobile/build/web"
TARGET_DIR="/home/support/smartguard/frontend"

# 检查源目录
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ 源目录不存在: $SOURCE_DIR"
    exit 1
fi

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 复制Flutter Web文件
echo "📋 复制Flutter Web文件..."
cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"

# 设置权限
echo "🔒 设置文件权限..."
cd "$TARGET_DIR"
chmod 644 *.html 2>/dev/null || true
chmod 644 *.js 2>/dev/null || true
chmod 644 *.json 2>/dev/null || true
chmod -R 755 assets/ 2>/dev/null || true
chmod -R 755 canvaskit/ 2>/dev/null || true

echo ""
echo "✅ 部署完成！"
echo ""
echo "📊 部署后的关键文件:"
ls -lh | grep -E "index.html|main.dart.js|flutter.js" | head -5

# 清理临时文件
echo ""
echo "🧹 清理临时文件..."
rm -rf /tmp/smartguard_mobile
rm -f /tmp/flutter_project.tar.gz

ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 部署失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 部署成功${NC}"
echo ""

# ========================================
# 步骤6: 重启前端服务（如果需要）
# ========================================
echo -e "${YELLOW}[6/7] 检查前端服务...${NC}"

ssh -i "$SERVER_KEY" "${SERVER_USER}@${SERVER_HOST}" << ENDSSH
set -e

echo "🔍 检查前端服务状态..."

# 检查nginx配置（如果使用nginx）
if command -v nginx &> /dev/null; then
    echo "检测到nginx，检查配置..."
    if [ -f "/etc/nginx/sites-available/smartguard" ] || [ -f "/etc/nginx/conf.d/smartguard.conf" ]; then
        echo "✅ nginx配置存在"
        echo "🔄 重新加载nginx配置..."
        sudo nginx -t && sudo systemctl reload nginx 2>/dev/null || echo "⚠️  nginx重载失败，请手动检查"
    fi
fi

# 如果使用Python HTTP服务器
if lsof -ti:$FRONTEND_PORT > /dev/null 2>&1; then
    echo "🔄 重启前端服务（端口 $FRONTEND_PORT）..."
    lsof -ti:$FRONTEND_PORT | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# 启动服务（如果需要）
if ! lsof -ti:$FRONTEND_PORT > /dev/null 2>&1; then
    echo "🚀 启动前端服务..."
    cd /home/support/smartguard/frontend
    nohup python3 -m http.server $FRONTEND_PORT > frontend.log 2>&1 &
    sleep 3
    
    if lsof -ti:$FRONTEND_PORT > /dev/null 2>&1; then
        echo "✅ 前端服务已启动 (端口 $FRONTEND_PORT)"
    else
        echo "⚠️  前端服务启动失败（可能由nginx提供服务）"
    fi
else
    echo "✅ 前端服务已在运行"
fi

ENDSSH

echo -e "${GREEN}✅ 前端服务检查完成${NC}"
echo ""

# ========================================
# 步骤7: 验证部署
# ========================================
echo -e "${YELLOW}[7/7] 验证部署...${NC}"

echo -e "${CYAN}等待服务器处理...${NC}"
sleep 3

echo -e "${CYAN}测试访问:${NC}"
echo ""

# 测试主页
echo "1. 测试 Flutter Web 应用:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "   ${GREEN}✅ HTTP $HTTP_CODE - 访问正常${NC}"
else
    echo -e "   ${YELLOW}⚠️  HTTP $HTTP_CODE - 访问异常（可能需要等待DNS或nginx配置）${NC}"
fi

# 检查Flutter标识
echo ""
echo "2. 验证Flutter Web标识:"
if curl -s "https://$DOMAIN/" 2>/dev/null | grep -q "flutter\|canvaskit"; then
    echo -e "   ${GREEN}✅ 检测到Flutter Web标识${NC}"
else
    echo -e "   ${YELLOW}⚠️  未检测到Flutter标识（可能缓存或nginx配置）${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SmartGuard Flutter Web部署完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}📱 访问地址:${NC}"
echo "  🌐 Flutter Web应用: https://$DOMAIN/"
echo "  📚 API文档: https://$DOMAIN/docs"
echo "  ❤️ 健康检查: https://$DOMAIN/health"
echo ""

echo -e "${YELLOW}⚠️  重要提示:${NC}"
echo "  • 首次访问可能需要3-5秒加载Flutter框架"
echo "  • 如果看到旧页面，请强制刷新（Ctrl+Shift+R 或 Cmd+Shift+R）"
echo "  • 清空浏览器缓存后再测试以确保加载最新版本"
echo "  • 备份位置: /tmp/smartguard_web_backup_*"
echo ""

echo -e "${GREEN}🎉 部署成功完成！${NC}"
echo ""

