# 测试账号和注册说明

## 📋 测试账号

### 默认测试账号（如果数据库已初始化）

| 角色 | 用户名 | 密码 | 说明 |
|------|--------|------|------|
| 护士 | `nurse001` | `nurse123` | 护士工作站账号 |
| 家属1 | `family001` | `family123` | 家属端账号 |
| 家属2 | `family002` | `family123` | 家属端账号 |
| **患者1** | `patient001` | `patient123` | **患者端账号（关联患者P001）** |
| **患者2** | `patient002` | `patient123` | **患者端账号（关联患者P002）** |
| 家属 | `test_family` | `test123` | 家属端账号（需运行创建脚本） |

## 🔐 邮箱注册功能

### API端点
- **URL**: `POST /api/auth/register`
- **Content-Type**: `application/json`

### 请求格式

```json
{
  "username": "新用户名",
  "password": "密码",
  "email": "user@example.com",
  "full_name": "用户全名（可选）",
  "phone": "手机号（可选）",
  "role": "family"
}
```

### 请求参数说明

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `username` | string | ✅ | 用户名（唯一） |
| `password` | string | ✅ | 密码 |
| `email` | string | ✅ | 邮箱地址（唯一，需验证格式） |
| `full_name` | string | ❌ | 用户全名 |
| `phone` | string | ❌ | 手机号 |
| `role` | string | ❌ | 用户角色，可选值：`nurse`, `doctor`, `family`, `admin`, `patient`（默认：`family`） |

### 响应格式

**成功响应 (200)**:
```json
{
  "user_id": "uuid",
  "username": "新用户名",
  "email": "user@example.com",
  "role": "family",
  "message": "注册成功！请使用用户名和密码登录。"
}
```

**错误响应 (400/500)**:
```json
{
  "detail": "错误信息"
}
```

### 错误情况

- `400`: 邮箱格式不正确
- `400`: 用户名已存在
- `400`: 该邮箱已被注册
- `400`: 角色无效
- `500`: 服务器内部错误

## 📝 使用示例

### 使用curl注册

```bash
curl -X POST https://smartguard.gitagent.io/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser",
    "password": "password123",
    "email": "newuser@example.com",
    "full_name": "新用户",
    "phone": "13800000000",
    "role": "family"
  }'
```

### 使用JavaScript注册

```javascript
fetch('https://smartguard.gitagent.io/api/auth/register', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    username: 'newuser',
    password: 'password123',
    email: 'newuser@example.com',
    full_name: '新用户',
    phone: '13800000000',
    role: 'family'
  })
})
.then(response => response.json())
.then(data => console.log('注册成功:', data))
.catch(error => console.error('注册失败:', error));
```

## 🔧 创建测试用户脚本

如果数据库中没有测试用户，可以运行以下脚本创建：

```bash
cd backend
python scripts/create_test_users.py
```

该脚本会创建以下测试账号：
- `test_patient` / `test123` (病患角色)
- `test_family` / `test123` (家属角色)
- `nurse001` / `nurse123` (护士角色)
- `family001` / `family123` (家属角色)
- `family002` / `family123` (家属角色)

## 🔑 登录API

### API端点
- **URL**: `POST /api/auth/login`
- **Content-Type**: `application/json`

### 请求格式

```json
{
  "username": "用户名",
  "password": "密码"
}
```

### 响应格式

**成功响应 (200)**:
```json
{
  "user_id": "uuid",
  "username": "用户名",
  "role": "family",
  "full_name": "用户全名",
  "patient_id": null,
  "token": "登录token"
}
```

**错误响应 (401)**:
```json
{
  "detail": "用户名或密码错误"
}
```

## ⚠️ 注意事项

1. **密码安全**: 当前使用SHA256哈希，生产环境建议使用bcrypt
2. **邮箱验证**: 注册时验证邮箱格式，但不发送验证邮件（Demo模式）
3. **角色限制**: 注册时默认角色为`family`，其他角色可能需要管理员授权
4. **唯一性**: 用户名和邮箱必须唯一

