/**
 * 批量上传器 - Layer 4 批处理优化
 * 参考: doc/视频分析成本优化算法方案.md
 * 
 * 功能：累积多帧后批量上传，减少网络请求
 * 预期效果：减少网络开销，提高处理效率
 */
class BatchUploader {
    constructor(batchSize = 5, maxWaitTime = 15000) {
        this.buffer = [];
        this.batchSize = batchSize; // 批量大小：累积5帧
        this.maxWaitTime = maxWaitTime; // 最大等待时间：15秒
        this.lastUploadTime = Date.now();
        this.uploadTimer = null;
        this.isUploading = false;
    }

    /**
     * 添加帧到缓冲区
     * @param {File} file - 图片文件
     * @param {string} patientId - 患者ID
     * @param {string} cameraId - 摄像头ID（可选）
     * @param {number} timestampMs - 时间戳（毫秒）
     * @returns {Promise} 上传结果（如果触发批量上传）
     */
    async addFrame(file, patientId, cameraId = null, timestampMs = 0) {
        const frameData = {
            file: file,
            patientId: patientId,
            cameraId: cameraId,
            timestampMs: timestampMs,
            addedAt: Date.now()
        };

        this.buffer.push(frameData);

        // 检查是否需要上传
        const shouldUpload = 
            this.buffer.length >= this.batchSize || 
            (Date.now() - this.lastUploadTime) > this.maxWaitTime;

        if (shouldUpload && !this.isUploading) {
            return await this.uploadBatch();
        }

        // 设置超时上传
        if (!this.uploadTimer && this.buffer.length > 0) {
            this.uploadTimer = setTimeout(() => {
                if (!this.isUploading && this.buffer.length > 0) {
                    this.uploadBatch();
                }
            }, this.maxWaitTime);
        }

        return null;
    }

    /**
     * 批量上传
     * @returns {Promise<Array>} 上传结果数组
     */
    async uploadBatch() {
        if (this.isUploading || this.buffer.length === 0) {
            return [];
        }

        this.isUploading = true;
        
        // 清除超时定时器
        if (this.uploadTimer) {
            clearTimeout(this.uploadTimer);
            this.uploadTimer = null;
        }

        // 复制缓冲区并清空
        const framesToUpload = [...this.buffer];
        this.buffer = [];
        this.lastUploadTime = Date.now();

        try {
            // 调用批量上传API
            const results = await this.uploadFrames(framesToUpload);
            this.isUploading = false;
            return results;
        } catch (error) {
            console.error('批量上传失败:', error);
            // 上传失败，将帧重新加入缓冲区（可选：限制重试次数）
            // this.buffer.unshift(...framesToUpload);
            this.isUploading = false;
            throw error;
        }
    }

    /**
     * 上传帧数据到后端
     * @param {Array} frames - 帧数据数组
     * @returns {Promise<Array>} 分析结果数组
     */
    async uploadFrames(frames) {
        const formData = new FormData();
        
        // 准备批量上传数据
        const frameData = frames.map((frame, index) => ({
            patient_id: frame.patientId,
            camera_id: frame.cameraId || '',
            timestamp_ms: frame.timestampMs
        }));

        // 添加所有文件
        frames.forEach((frame, index) => {
            formData.append(`files`, frame.file);
        });

        // 添加元数据
        formData.append('frames', JSON.stringify(frameData));

        // 调用批量分析API
        const response = await fetch('/api/analysis/batch', {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || `HTTP ${response.status}`);
        }

        return await response.json();
    }

    /**
     * 强制上传缓冲区中的所有帧
     * @returns {Promise<Array>} 上传结果
     */
    async flush() {
        if (this.buffer.length === 0) {
            return [];
        }
        return await this.uploadBatch();
    }

    /**
     * 重置上传器
     */
    reset() {
        if (this.uploadTimer) {
            clearTimeout(this.uploadTimer);
            this.uploadTimer = null;
        }
        this.buffer = [];
        this.isUploading = false;
        this.lastUploadTime = Date.now();
    }

    /**
     * 获取缓冲区状态
     * @returns {Object} 状态信息
     */
    getStatus() {
        return {
            bufferSize: this.buffer.length,
            isUploading: this.isUploading,
            timeSinceLastUpload: Date.now() - this.lastUploadTime,
            batchSize: this.batchSize,
            maxWaitTime: this.maxWaitTime
        };
    }
}

