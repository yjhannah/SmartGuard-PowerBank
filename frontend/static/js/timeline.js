/**
 * 时间线组件
 * 参考: doc/情绪识别数据保存与时间线回放方案.md
 * 
 * 功能：显示分析历史时间线，支持时间戳回放
 */
class TimelineComponent {
    constructor(containerId, options = {}) {
        this.container = document.getElementById(containerId);
        this.options = {
            onItemClick: options.onItemClick || null,
            formatTimestamp: options.formatTimestamp || this.formatTimestamp,
            ...options
        };
    }

    /**
     * 渲染时间线
     * @param {Array} events - 事件数组
     */
    render(events) {
        if (!this.container) {
            console.error('时间线容器不存在');
            return;
        }

        if (!events || events.length === 0) {
            this.container.innerHTML = this.buildEmptyState();
            return;
        }

        // 按时间戳排序
        const sortedEvents = [...events].sort((a, b) => {
            const aTs = this.getTimestamp(a);
            const bTs = this.getTimestamp(b);
            return aTs - bTs;
        });

        // 构建时间线HTML
        let html = '<div class="timeline">';
        sortedEvents.forEach((event, index) => {
            html += this.buildTimelineItem(event, index);
        });
        html += '</div>';

        this.container.innerHTML = html;

        // 绑定点击事件
        this.bindClickEvents();
    }

    /**
     * 构建时间线项
     * @param {Object} event - 事件对象
     * @param {number} index - 索引
     * @returns {string} HTML字符串
     */
    buildTimelineItem(event, index) {
        const timestampMs = this.getTimestamp(event);
        const formattedTime = this.options.formatTimestamp(timestampMs);
        const status = this.getEventStatus(event);
        const detectionType = this.getDetectionType(event);
        const severity = this.getSeverity(event);

        return `
            <div class="timeline-item ${severity}" data-index="${index}" data-timestamp="${timestampMs}">
                <div style="display: flex; justify-content: space-between; align-items: start;">
                    <div style="flex: 1;">
                        <div style="font-weight: 600; margin-bottom: 4px;">
                            ${formattedTime}
                        </div>
                        <div style="font-size: 14px; color: #cbd5e1; margin-bottom: 4px;">
                            类型: ${detectionType}
                        </div>
                        <div style="font-size: 12px; color: #94a3b8;">
                            状态: ${status}
                        </div>
                    </div>
                    <button class="btn btn-primary" style="padding: 4px 8px; font-size: 12px;" 
                            onclick="timelineComponent.seekToTimestamp(${timestampMs})">
                        跳转
                    </button>
                </div>
            </div>
        `;
    }

    /**
     * 构建空状态
     * @returns {string} HTML字符串
     */
    buildEmptyState() {
        return `
            <div class="empty-state">
                <div style="text-align: center; padding: 40px; color: #94a3b8;">
                    <div style="font-size: 48px; margin-bottom: 16px;">📊</div>
                    <div>暂无分析记录</div>
                </div>
            </div>
        `;
    }

    /**
     * 获取时间戳
     * @param {Object} event - 事件对象
     * @returns {number} 时间戳（毫秒）
     */
    getTimestamp(event) {
        // 从analysis_data中获取timestamp_ms
        if (event.analysis_data) {
            const data = typeof event.analysis_data === 'string' 
                ? JSON.parse(event.analysis_data) 
                : event.analysis_data;
            if (data.timestamp_ms !== undefined) {
                return data.timestamp_ms;
            }
        }
        // 如果没有相对时间戳，使用绝对时间计算（简化处理）
        if (event.timestamp) {
            return new Date(event.timestamp).getTime();
        }
        return 0;
    }

    /**
     * 获取事件状态
     * @param {Object} event - 事件对象
     * @returns {string} 状态
     */
    getEventStatus(event) {
        if (event.analysis_data) {
            const data = typeof event.analysis_data === 'string' 
                ? JSON.parse(event.analysis_data) 
                : event.analysis_data;
            return data.overall_status || 'normal';
        }
        return 'normal';
    }

    /**
     * 获取检测类型
     * @param {Object} event - 事件对象
     * @returns {string} 检测类型
     */
    getDetectionType(event) {
        return event.detection_type || 'general';
    }

    /**
     * 获取严重度
     * @param {Object} event - 事件对象
     * @returns {string} 严重度
     */
    getSeverity(event) {
        const status = this.getEventStatus(event);
        if (status === 'critical') return 'critical';
        if (status === 'attention') return 'high';
        return 'medium';
    }

    /**
     * 格式化时间戳
     * @param {number} timestampMs - 时间戳（毫秒）
     * @returns {string} 格式化后的时间（MM:SS）
     */
    formatTimestamp(timestampMs) {
        const seconds = Math.floor(timestampMs / 1000);
        const minutes = Math.floor(seconds / 60);
        const remainingSeconds = seconds % 60;
        return `${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}`;
    }

    /**
     * 绑定点击事件
     */
    bindClickEvents() {
        if (!this.options.onItemClick) return;

        const items = this.container.querySelectorAll('.timeline-item');
        items.forEach(item => {
            item.addEventListener('click', (e) => {
                if (e.target.tagName === 'BUTTON') return; // 跳过按钮点击
                const timestamp = parseInt(item.dataset.timestamp);
                if (this.options.onItemClick) {
                    this.options.onItemClick(timestamp, item);
                }
            });
        });
    }

    /**
     * 跳转到指定时间戳
     * @param {number} timestampMs - 时间戳（毫秒）
     */
    seekToTimestamp(timestampMs) {
        if (this.options.onItemClick) {
            this.options.onItemClick(timestampMs, null);
        } else {
            console.log(`跳转到时间点: ${this.formatTimestamp(timestampMs)}`);
        }
    }

    /**
     * 高亮指定时间戳的项
     * @param {number} timestampMs - 时间戳（毫秒）
     */
    highlightItem(timestampMs) {
        const items = this.container.querySelectorAll('.timeline-item');
        items.forEach(item => {
            const itemTimestamp = parseInt(item.dataset.timestamp);
            if (Math.abs(itemTimestamp - timestampMs) < 1000) { // 1秒内
                item.style.background = '#1e3a5f';
                item.style.border = '2px solid #3b82f6';
            } else {
                item.style.background = '';
                item.style.border = '';
            }
        });
    }
}

