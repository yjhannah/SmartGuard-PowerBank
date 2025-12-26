/**
 * API调用封装
 */
const API_BASE_URL = window.location.origin;

class ApiClient {
    constructor(baseUrl = API_BASE_URL) {
        this.baseUrl = baseUrl;
    }

    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const config = {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        };

        try {
            const response = await fetch(url, config);
            const data = await response.json();
            
            if (!response.ok) {
                throw new Error(data.detail || `HTTP ${response.status}`);
            }
            
            return data;
        } catch (error) {
            console.error(`API请求失败: ${endpoint}`, error);
            throw error;
        }
    }

    async get(endpoint) {
        return this.request(endpoint, { method: 'GET' });
    }

    async post(endpoint, data) {
        return this.request(endpoint, {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    async put(endpoint, data) {
        return this.request(endpoint, {
            method: 'PUT',
            body: JSON.stringify(data)
        });
    }

    async uploadFile(endpoint, file, params = {}) {
        const formData = new FormData();
        formData.append('file', file);
        
        Object.keys(params).forEach(key => {
            formData.append(key, params[key]);
        });

        const url = `${this.baseUrl}${endpoint}`;
        const response = await fetch(url, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || `HTTP ${response.status}`);
        }

        return await response.json();
    }
}

// 创建全局实例
const api = new ApiClient();

// API方法
const apiMethods = {
    // 患者相关
    getPatients: (wardId, isHospitalized) => {
        const params = new URLSearchParams();
        if (wardId) params.append('ward_id', wardId);
        if (isHospitalized !== undefined) params.append('is_hospitalized', isHospitalized);
        return api.get(`/api/patients?${params}`);
    },
    
    getPatient: (patientId) => api.get(`/api/patients/${patientId}`),
    
    getLiveStatus: (patientId) => api.get(`/api/patients/${patientId}/live-status`),
    
    // 分析相关
    analyzeImage: (file, patientId, cameraId, timestampMs) => {
        const params = {
            patient_id: patientId,
            camera_id: cameraId || ''
        };
        if (timestampMs !== undefined) {
            params.timestamp_ms = timestampMs;
        }
        return api.uploadFile('/api/analysis/analyze', file, params);
    },
    
    getAnalysisHistory: (patientId, startDate, endDate, limit = 100) => {
        const params = new URLSearchParams();
        if (startDate) params.append('start_date', startDate);
        if (endDate) params.append('end_date', endDate);
        params.append('limit', limit);
        return api.get(`/api/analysis/history/${patientId}?${params}`);
    },
    
    // 告警相关
    getAlerts: (patientId, status, severity, limit = 50) => {
        const params = new URLSearchParams();
        if (patientId) params.append('patient_id', patientId);
        if (status) params.append('status', status);
        if (severity) params.append('severity', severity);
        params.append('limit', limit);
        return api.get(`/api/alerts?${params}`);
    },
    
    acknowledgeAlert: (alertId, userId) => {
        return api.post(`/api/alerts/${alertId}/acknowledge`, { user_id: userId });
    },
    
    resolveAlert: (alertId, userId, resolutionNotes) => {
        return api.post(`/api/alerts/${alertId}/resolve`, {
            user_id: userId,
            resolution_notes: resolutionNotes
        });
    }
};

