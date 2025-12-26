"""
日志配置模块
配置日志系统，支持文件输出和控制台输出，使用北京时间
"""
import logging
import sys
from pathlib import Path
from datetime import datetime
import pytz

# 北京时间时区
BEIJING_TZ = pytz.timezone('Asia/Shanghai')


class BeijingTimeFormatter(logging.Formatter):
    """使用北京时间的日志格式化器"""
    
    def formatTime(self, record, datefmt=None):
        """格式化时间为北京时间"""
        dt = datetime.fromtimestamp(record.created, tz=BEIJING_TZ)
        if datefmt:
            return dt.strftime(datefmt)
        return dt.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]  # 精确到毫秒


def setup_logging(log_dir: str = "logs", log_level: str = "INFO"):
    """
    配置日志系统
    
    Args:
        log_dir: 日志目录路径
        log_level: 日志级别
    """
    # 创建日志目录
    log_path = Path(log_dir)
    log_path.mkdir(parents=True, exist_ok=True)
    
    # 日志文件名（按日期）
    today = datetime.now(BEIJING_TZ).strftime('%Y-%m-%d')
    log_file = log_path / f"smartguard_{today}.log"
    error_log_file = log_path / f"smartguard_error_{today}.log"
    
    # 日志格式
    detailed_format = '%(asctime)s [%(levelname)-8s] [%(name)s:%(lineno)d] %(message)s'
    simple_format = '%(asctime)s [%(levelname)-8s] %(message)s'
    
    # 创建格式化器
    formatter = BeijingTimeFormatter(detailed_format, datefmt='%Y-%m-%d %H:%M:%S.%f')
    console_formatter = BeijingTimeFormatter(simple_format, datefmt='%Y-%m-%d %H:%M:%S')
    
    # 获取根日志记录器
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper()))
    
    # 清除现有的处理器
    root_logger.handlers.clear()
    
    # 文件处理器 - 所有日志（追加模式，不清空）
    file_handler = logging.FileHandler(log_file, encoding='utf-8', mode='a')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)
    
    # 文件处理器 - 错误日志（追加模式，不清空）
    error_file_handler = logging.FileHandler(error_log_file, encoding='utf-8', mode='a')
    error_file_handler.setLevel(logging.ERROR)
    error_file_handler.setFormatter(formatter)
    root_logger.addHandler(error_file_handler)
    
    # 控制台处理器
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, log_level.upper()))
    console_handler.setFormatter(console_formatter)
    root_logger.addHandler(console_handler)
    
    # 配置第三方库的日志级别
    logging.getLogger('uvicorn').setLevel(logging.INFO)
    logging.getLogger('uvicorn.access').setLevel(logging.WARNING)
    logging.getLogger('fastapi').setLevel(logging.INFO)
    
    logger = logging.getLogger(__name__)
    logger.info(f"✅ 日志系统已初始化")
    logger.info(f"📁 日志目录: {log_path.absolute()}")
    logger.info(f"📄 日志文件: {log_file}")
    logger.info(f"📄 错误日志: {error_log_file}")
    logger.info(f"🕐 时区: 北京时间 (Asia/Shanghai)")
    
    return logger

