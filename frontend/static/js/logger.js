/**
 * 前端日志组件
 */
class FrontendLogger {
    constructor(containerId, options = {}) {
        this.container = document.getElementById(containerId);
        this.options = {
            maxLogs: options.maxLogs || 100,
            autoScroll: options.autoScroll !== false,
            showTimestamp: options.showTimestamp !== false,
            ...options
        };
        this.logs = [];
        this.init();
    }
    
    init() {
        if (!this.container) {
            console.error(`FrontendLogger: 容器 ${this.containerId} 不存在`);
            return;
        }
        
        this.container.innerHTML = `
            <div class="logger-header">
                <span>前端日志</span>
                <button class="btn-clear-logs" onclick="window.logger?.clear()">清空</button>
            </div>
            <div class="logger-content" id="${this.containerId}_content"></div>
        `;
        
        this.content = document.getElementById(`${this.containerId}_content`);
    }
    
    log(message, type = 'info') {
        const timestamp = this.options.showTimestamp 
            ? new Date().toLocaleTimeString() 
            : '';
        
        const logEntry = {
            timestamp,
            message,
            type,
            id: Date.now() + Math.random()
        };
        
        this.logs.push(logEntry);
        
        // 限制日志数量
        if (this.logs.length > this.options.maxLogs) {
            this.logs.shift();
        }
        
        this.render();
    }
    
    info(message) {
        this.log(message, 'info');
    }
    
    success(message) {
        this.log(message, 'success');
    }
    
    warning(message) {
        this.log(message, 'warning');
    }
    
    error(message) {
        this.log(message, 'error');
    }
    
    render() {
        if (!this.content) return;
        
        this.content.innerHTML = this.logs.map(log => `
            <div class="log-entry log-${log.type}">
                ${this.options.showTimestamp ? `<span class="log-time">${log.timestamp}</span>` : ''}
                <span class="log-message">${this.escapeHtml(log.message)}</span>
            </div>
        `).join('');
        
        if (this.options.autoScroll) {
            this.content.scrollTop = this.content.scrollHeight;
        }
    }
    
    clear() {
        this.logs = [];
        this.render();
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    show() {
        if (this.container) {
            this.container.style.display = 'block';
        }
    }
    
    hide() {
        if (this.container) {
            this.container.style.display = 'none';
        }
    }
}

