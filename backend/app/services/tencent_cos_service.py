"""
腾讯云COS图片上传服务
参考 AuraRecruit 项目的实现
"""
from qcloud_cos import CosConfig, CosS3Client
import sys
from datetime import datetime
from pathlib import Path
import logging
from typing import Optional
import tempfile
import os

logger = logging.getLogger(__name__)


class TencentCOSClient:
    """腾讯云COS客户端"""
    
    def __init__(self):
        from app.core.config import settings
        
        self.settings = settings
        
        # 检查配置
        if not hasattr(self.settings, 'TENCENT_SECRET_ID') or not self.settings.TENCENT_SECRET_ID:
            logger.error("❌ 腾讯云COS凭证未配置 (TENCENT_SECRET_ID missing)")
            raise ValueError("Tencent COS credentials not configured: TENCENT_SECRET_ID")
        
        if not hasattr(self.settings, 'TENCENT_SECRET_KEY') or not self.settings.TENCENT_SECRET_KEY:
            logger.error("❌ 腾讯云COS凭证未配置 (TENCENT_SECRET_KEY missing)")
            raise ValueError("Tencent COS credentials not configured: TENCENT_SECRET_KEY")
        
        if not hasattr(self.settings, 'TENCENT_COS_BUCKET') or not self.settings.TENCENT_COS_BUCKET:
            logger.error("❌ 腾讯云COS Bucket未配置 (TENCENT_COS_BUCKET missing)")
            raise ValueError("TENCENT_COS_BUCKET not configured")
        
        # 初始化COS配置
        try:
            config = CosConfig(
                Region=getattr(self.settings, 'TENCENT_COS_REGION', 'ap-beijing'),
                SecretId=self.settings.TENCENT_SECRET_ID,
                SecretKey=self.settings.TENCENT_SECRET_KEY,
                Token=None,
                Scheme='https'
            )
            
            self.client = CosS3Client(config)
            self.bucket = self.settings.TENCENT_COS_BUCKET
            self.region = getattr(self.settings, 'TENCENT_COS_REGION', 'ap-beijing')
            self.prefix = getattr(self.settings, 'TENCENT_COS_IMAGE_PREFIX', 'smartguard/alerts/')
            
            logger.info(f"✅ 腾讯云COS服务初始化成功: Bucket={self.bucket}, Region={self.region}")
            
        except Exception as e:
            logger.error(f"❌ 腾讯云COS客户端初始化失败: {e}")
            raise
    
    def upload_image(
        self,
        image_bytes: bytes,
        patient_id: str,
        alert_id: Optional[str] = None,
        filename: Optional[str] = None
    ) -> dict:
        """
        上传图片到腾讯云COS
        
        Args:
            image_bytes: 图片字节流
            patient_id: 患者ID
            alert_id: 告警ID（可选）
            filename: 自定义文件名（可选）
        
        Returns:
            {
                "url": "https://bucket.cos.region.myqcloud.com/path/to/image.jpg",
                "key": "smartguard/alerts/20251227/patient_id/alert_id/image.jpg",
                "size": 1024000
            }
        """
        import time
        
        if not image_bytes:
            logger.error("❌ 上传失败: 图片数据为空")
            raise ValueError("Image bytes is empty")
        
        file_size = len(image_bytes)
        logger.info(f"📦 准备上传图片: size={file_size/1024:.2f}KB, patient_id={patient_id}")
        
        # 生成COS对象键
        date_str = datetime.now().strftime("%Y%m%d")
        if not filename:
            timestamp = datetime.now().strftime('%H%M%S')
            filename = f"{timestamp}.jpg"
        
        # 构建路径: smartguard/alerts/YYYYMMDD/patient_id/alert_id/filename
        if alert_id:
            key = f"{self.prefix}{date_str}/{patient_id}/{alert_id}/{filename}"
        else:
            key = f"{self.prefix}{date_str}/{patient_id}/{filename}"
        
        logger.info(f"🔑 目标COS Key: {key}")
        
        start_time = time.time()
        
        # 使用临时文件上传
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp_file:
                tmp_file.write(image_bytes)
                tmp_file_path = tmp_file.name
            
            try:
                # 上传文件
                response = self.client.upload_file(
                    Bucket=self.bucket,
                    LocalFilePath=tmp_file_path,
                    Key=key,
                    PartSize=1,  # 分块大小(MB)，图片通常较小
                    MAXThread=1,  # 并发线程数
                    EnableMD5=False
                )
                
                duration = time.time() - start_time
                
                # 生成访问URL
                url = f"https://{self.bucket}.cos.{self.region}.myqcloud.com/{key}"
                etag = response.get("ETag", "N/A")
                
                logger.info(f"✅ 图片上传成功! 耗时: {duration:.2f}s")
                logger.info(f"🔗 URL: {url}")
                logger.info(f"📋 ETag: {etag}")
                
                return {
                    "url": url,
                    "key": key,
                    "etag": etag,
                    "size": file_size
                }
            finally:
                # 清理临时文件
                if os.path.exists(tmp_file_path):
                    os.unlink(tmp_file_path)
                    
        except Exception as e:
            logger.error(f"❌ COS上传异常: {str(e)}")
            raise Exception(f"Failed to upload image to COS: {e}")
    
    def get_presigned_url(self, key: str, expires: int = 3600) -> str:
        """
        生成预签名URL（用于临时访问）
        
        Args:
            key: COS对象键
            expires: 有效期（秒）
        
        Returns:
            预签名URL字符串
        """
        try:
            url = self.client.get_presigned_download_url(
                Bucket=self.bucket,
                Key=key,
                Expired=expires
            )
            return url
        except Exception as e:
            logger.error(f"❌ 生成预签名URL失败: {e}")
            raise Exception(f"Failed to generate presigned URL: {e}")


# 单例
_cos_client: Optional[TencentCOSClient] = None


def get_cos_client() -> Optional[TencentCOSClient]:
    """获取COS客户端（如果配置了）"""
    global _cos_client
    if _cos_client is None:
        try:
            _cos_client = TencentCOSClient()
        except ValueError as e:
            logger.warning(f"⚠️ 腾讯云COS未配置，将跳过图片上传: {e}")
            return None
    return _cos_client

