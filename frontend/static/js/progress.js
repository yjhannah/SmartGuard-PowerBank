/**
 * 进度条组件
 */
class ProgressBar {
    constructor(containerId, options = {}) {
        this.container = document.getElementById(containerId);
        this.options = {
            showPercentage: options.showPercentage !== false,
            showSteps: options.showSteps !== false,
            steps: options.steps || [],
            ...options
        };
        this.currentStep = 0;
        this.progress = 0;
        this.init();
    }
    
    init() {
        if (!this.container) {
            console.error(`ProgressBar: 容器 ${this.containerId} 不存在`);
            return;
        }
        
        this.container.innerHTML = `
            <div class="progress-container">
                <div class="progress-bar-wrapper">
                    <div class="progress-bar" id="${this.containerId}_bar">
                        <div class="progress-fill" id="${this.containerId}_fill"></div>
                    </div>
                    ${this.options.showPercentage ? `<span class="progress-text" id="${this.containerId}_text">0%</span>` : ''}
                </div>
                ${this.options.showSteps && this.options.steps.length > 0 ? `
                    <div class="progress-steps" id="${this.containerId}_steps">
                        ${this.options.steps.map((step, index) => `
                            <div class="progress-step ${index === 0 ? 'active' : ''}" data-step="${index}">
                                <span class="step-number">${index + 1}</span>
                                <span class="step-label">${step}</span>
                            </div>
                        `).join('')}
                    </div>
                ` : ''}
            </div>
        `;
        
        this.bar = document.getElementById(`${this.containerId}_bar`);
        this.fill = document.getElementById(`${this.containerId}_fill`);
        this.text = document.getElementById(`${this.containerId}_text`);
        this.steps = document.querySelectorAll(`#${this.containerId}_steps .progress-step`);
    }
    
    setProgress(percentage, stepIndex = null) {
        this.progress = Math.max(0, Math.min(100, percentage));
        
        if (this.fill) {
            this.fill.style.width = `${this.progress}%`;
        }
        
        if (this.text && this.options.showPercentage) {
            this.text.textContent = `${Math.round(this.progress)}%`;
        }
        
        if (stepIndex !== null && this.steps) {
            this.setStep(stepIndex);
        }
    }
    
    setStep(stepIndex) {
        if (!this.steps || stepIndex < 0 || stepIndex >= this.steps.length) {
            return;
        }
        
        this.currentStep = stepIndex;
        
        this.steps.forEach((step, index) => {
            step.classList.remove('active', 'completed');
            if (index < stepIndex) {
                step.classList.add('completed');
            } else if (index === stepIndex) {
                step.classList.add('active');
            }
        });
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
    
    reset() {
        this.setProgress(0);
        this.setStep(0);
    }
}

