"""
图片代理接口
用于解决前端访问腾讯云COS图片的CORS跨域问题
"""
from fastapi import APIRouter, Query, HTTPException
from fastapi.responses import StreamingResponse
import httpx
import logging
from typing import Optional

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/images", tags=["images"])


@router.get("/proxy")
async def proxy_image(url: str = Query(..., description="图片URL")):
    """
    图片代理接口
    
    通过后端代理访问外部图片，解决CORS跨域问题
    
    Args:
        url: 要代理的图片URL（需要URL编码）
    
    Returns:
        图片流响应
    """
    if not url:
        raise HTTPException(status_code=400, detail="URL参数不能为空")
    
    # 验证URL是否为腾讯云COS地址（安全限制）
    allowed_domains = [
        "cos.na-siliconvalley.myqcloud.com",
        "cos.ap-beijing.myqcloud.com",
        "cos.ap-shanghai.myqcloud.com",
        "cos.ap-guangzhou.myqcloud.com",
        "cos.ap-chengdu.myqcloud.com",
        "portraitquest-1253756459.cos.na-siliconvalley.myqcloud.com",
    ]
    
    url_lower = url.lower()
    if not any(domain in url_lower for domain in allowed_domains):
        logger.warning(f"⚠️ 拒绝代理非授权域名: {url}")
        raise HTTPException(
            status_code=403,
            detail="只能代理腾讯云COS图片"
        )
    
    try:
        logger.info(f"🖼️ 代理图片: {url}")
        
        # 使用httpx异步请求图片
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url, follow_redirects=True)
            response.raise_for_status()
            
            # 获取Content-Type
            content_type = response.headers.get("Content-Type", "image/jpeg")
            
            # 返回图片流
            return StreamingResponse(
                iter([response.content]),
                media_type=content_type,
                headers={
                    "Cache-Control": "public, max-age=3600",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET",
                }
            )
            
    except httpx.TimeoutException:
        logger.error(f"❌ 图片代理超时: {url}")
        raise HTTPException(status_code=504, detail="图片加载超时")
    except httpx.HTTPStatusError as e:
        logger.error(f"❌ 图片代理HTTP错误: {e.response.status_code} - {url}")
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"图片加载失败: {e.response.status_code}"
        )
    except Exception as e:
        logger.error(f"❌ 图片代理异常: {str(e)} - {url}")
        raise HTTPException(status_code=500, detail=f"图片代理失败: {str(e)}")

