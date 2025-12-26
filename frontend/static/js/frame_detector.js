/**
 * 帧差检测器 - Layer 1 智能采样
 * 参考: doc/视频分析成本优化算法方案.md
 * 
 * 功能：检测画面变化，只有变化显著时才上传分析
 * 预期效果：减少70-75%的无效API调用
 */
class FrameChangeDetector {
    constructor(threshold = 0.15) {
        this.lastFrameData = null;
        this.threshold = threshold; // 变化阈值 15%
        this.samplingCanvas = null;
        this.stats = {
            totalFrames: 0,
            uploadedFrames: 0,
            skippedFrames: 0
        };
    }

    /**
     * 判断当前帧是否应该上传分析
     * @param {HTMLImageElement|File|Blob} imageSource - 图片源（可以是img元素、File对象或Blob）
     * @returns {Promise<boolean>} 是否应该上传
     */
    async shouldAnalyze(imageSource) {
        this.stats.totalFrames++;

        // 创建降采样画布用于快速检测
        if (!this.samplingCanvas) {
            this.samplingCanvas = document.createElement('canvas');
            this.samplingCanvas.width = 160;  // 降采样到160x120加速检测
            this.samplingCanvas.height = 120;
        }

        const ctx = this.samplingCanvas.getContext('2d');
        
        // 将图片源绘制到画布
        try {
            let img;
            if (imageSource instanceof HTMLImageElement) {
                img = imageSource;
            } else if (imageSource instanceof File || imageSource instanceof Blob) {
                img = await this.fileToImage(imageSource);
            } else {
                console.warn('不支持的图片源类型');
                return true; // 未知类型，保守处理，允许上传
            }

            ctx.drawImage(img, 0, 0, 160, 120);
            const currentData = ctx.getImageData(0, 0, 160, 120).data;
            const currentDataArray = new Uint8Array(currentData);

            // 首帧必须分析
            if (this.lastFrameData === null) {
                this.lastFrameData = currentDataArray;
                this.stats.uploadedFrames++;
                return true;
            }

            // 计算帧差
            const difference = this.calculateFrameDifference(currentDataArray);

            if (difference > this.threshold) {
                this.lastFrameData = currentDataArray;
                this.stats.uploadedFrames++;
                return true;
            } else {
                this.stats.skippedFrames++;
                return false;
            }
        } catch (error) {
            console.error('帧差检测失败:', error);
            // 检测失败保守处理，允许上传
            return true;
        }
    }

    /**
     * 计算两帧的像素差异
     * @param {Uint8Array} currentData - 当前帧数据
     * @returns {number} 差异比例 (0-1)
     */
    calculateFrameDifference(currentData) {
        if (!this.lastFrameData || this.lastFrameData.length !== currentData.length) {
            return 1.0;
        }

        let diffSum = 0;
        const pixelCount = currentData.length / 4; // RGBA，每4个字节一个像素

        for (let i = 0; i < currentData.length; i += 4) {
            // 只比较 RGB，忽略 Alpha
            const rDiff = Math.abs(currentData[i] - this.lastFrameData[i]);
            const gDiff = Math.abs(currentData[i + 1] - this.lastFrameData[i + 1]);
            const bDiff = Math.abs(currentData[i + 2] - this.lastFrameData[i + 2]);
            diffSum += (rDiff + gDiff + bDiff) / 3;
        }

        // 计算平均差异（归一化到0-1）
        const avgDiff = diffSum / (pixelCount * 255);
        return avgDiff;
    }

    /**
     * 将File/Blob转换为Image对象
     * @param {File|Blob} file - 文件对象
     * @returns {Promise<HTMLImageElement>}
     */
    fileToImage(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            const url = URL.createObjectURL(file);
            
            img.onload = () => {
                URL.revokeObjectURL(url);
                resolve(img);
            };
            
            img.onerror = () => {
                URL.revokeObjectURL(url);
                reject(new Error('图片加载失败'));
            };
            
            img.src = url;
        });
    }

    /**
     * 重置检测器（开始新的监控会话）
     */
    reset() {
        this.lastFrameData = null;
        this.stats = {
            totalFrames: 0,
            uploadedFrames: 0,
            skippedFrames: 0
        };
    }

    /**
     * 获取统计信息
     * @returns {Object} 统计信息
     */
    getStats() {
        const uploadRate = this.stats.totalFrames > 0 
            ? (this.stats.uploadedFrames / this.stats.totalFrames * 100).toFixed(1)
            : 0;
        
        const reductionRate = this.stats.totalFrames > 0
            ? (this.stats.skippedFrames / this.stats.totalFrames * 100).toFixed(1)
            : 0;

        return {
            ...this.stats,
            uploadRate: `${uploadRate}%`,
            reductionRate: `${reductionRate}%`
        };
    }

    /**
     * 设置变化阈值
     * @param {number} threshold - 新阈值 (0-1)
     */
    setThreshold(threshold) {
        if (threshold >= 0 && threshold <= 1) {
            this.threshold = threshold;
        } else {
            console.warn('阈值必须在0-1之间');
        }
    }
}

