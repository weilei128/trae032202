# 个人收支记账系统接口文档

## 统一响应格式

所有接口返回统一的JSON格式：

```json
{
    "code": 200,
    "msg": "成功",
    "data": {...}
}
```

- `code`: 状态码，200表示成功，其他表示失败
- `msg`: 提示信息
- `data`: 返回数据

## 错误码说明

| 错误码 | 说明 |
|-------|------|
| 200 | 成功 |
| 400 | 参数错误 |
| 401 | 未登录 |
| 500 | 服务器错误 |

---

## 用户模块

### 1. 用户注册

**接口地址**: `POST /api/user/register`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|-------|------|-----|------|
| account | string | 是 | 账号（手机号或邮箱） |
| password | string | 是 | 密码（6-20位） |
| nickname | string | 否 | 昵称 |

**请求示例**:
```json
{
    "account": "13800138000",
    "password": "123456",
    "nickname": "小明"
}
```

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": null
}
```

### 2. 用户登录

**接口地址**: `POST /api/user/login`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|-------|------|-----|------|
| account | string | 是 | 账号 |
| password | string | 是 | 密码 |

**请求示例**:
```json
{
    "account": "13800138000",
    "password": "123456"
}
```

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "token": "abc123def456..."
    }
}
```

### 3. 修改密码

**接口地址**: `POST /api/user/changePassword`

**请求头**: `Authorization: {token}`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|-------|------|-----|------|
| oldPassword | string | 是 | 原密码 |
| newPassword | string | 是 | 新密码（6-20位） |

**请求示例**:
```json
{
    "oldPassword": "123456",
    "newPassword": "654321"
}
```

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": null
}
```

### 4. 获取用户信息

**接口地址**: `GET /api/user/info`

**请求头**: `Authorization: {token}`

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "id": 1,
        "account": "13800138000",
        "nickname": "小明"
    }
}
```

---

## 记账模块

### 1. 添加收支记录

**接口地址**: `POST /api/record/add`

**请求头**: `Authorization: {token}`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|-------|------|-----|------|
| amount | number | 是 | 金额（必须为正数） |
| type | string | 是 | 类型（收入/支出） |
| category | string | 是 | 分类 |
| remark | string | 否 | 备注 |

**分类说明**:
- 收入分类: 薪资、奖金、投资收益、其他收入
- 支出分类: 餐饮、购物、交通、娱乐、医疗、教育、住房、其他支出

**请求示例**:
```json
{
    "amount": 100.50,
    "type": "支出",
    "category": "餐饮",
    "remark": "午餐"
}
```

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "id": 1,
        "userId": 1,
        "amount": 100.50,
        "type": "支出",
        "category": "餐饮",
        "remark": "午餐",
        "createTime": "2024-03-20T12:00:00",
        "updateTime": "2024-03-20T12:00:00"
    }
}
```

### 2. 修改收支记录

**接口地址**: `POST /api/record/update`

**请求头**: `Authorization: {token}`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|-------|------|-----|------|
| id | number | 是 | 记录ID |
| amount | number | 是 | 金额 |
| type | string | 是 | 类型 |
| category | string | 是 | 分类 |
| remark | string | 否 | 备注 |

**请求示例**:
```json
{
    "id": 1,
    "amount": 150.00,
    "type": "支出",
    "category": "餐饮",
    "remark": "午餐和晚餐"
}
```

### 3. 删除收支记录

**接口地址**: `DELETE /api/record/{id}`

**请求头**: `Authorization: {token}`

**路径参数**: `id` - 记录ID

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": null
}
```

### 4. 查询收支记录

**接口地址**: `GET /api/record/list`

**请求头**: `Authorization: {token}`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|-------|------|-----|------|
| startDate | string | 否 | 开始日期（格式：yyyy-MM-dd） |
| endDate | string | 否 | 结束日期 |
| type | string | 否 | 类型（收入/支出） |
| category | string | 否 | 分类 |
| page | number | 否 | 页码（默认1） |
| pageSize | number | 否 | 每页条数（默认10） |

**请求示例**: `GET /api/record/list?type=支出&page=1&pageSize=10`

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "list": [
            {
                "id": 1,
                "userId": 1,
                "amount": 100.50,
                "type": "支出",
                "category": "餐饮",
                "remark": "午餐",
                "createTime": "2024-03-20T12:00:00",
                "updateTime": "2024-03-20T12:00:00"
            }
        ],
        "total": 15,
        "page": 1,
        "pageSize": 10
    }
}
```

### 5. 获取分类列表

**接口地址**: `GET /api/record/categories`

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "incomeCategories": ["薪资", "奖金", "投资收益", "其他收入"],
        "expenseCategories": ["餐饮", "购物", "交通", "娱乐", "医疗", "教育", "住房", "其他支出"]
    }
}
```

---

## 统计模块

### 1. 周统计

**接口地址**: `GET /api/stats/weekly`

**请求头**: `Authorization: {token}`

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "totalIncome": 5000.00,
        "totalExpense": 1500.00,
        "balance": 3500.00
    }
}
```

### 2. 月统计

**接口地址**: `GET /api/stats/monthly`

**请求头**: `Authorization: {token}`

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "totalIncome": 10000.00,
        "totalExpense": 5000.00,
        "balance": 5000.00
    }
}
```

### 3. 分类统计

**接口地址**: `GET /api/stats/category`

**请求头**: `Authorization: {token}`

**请求参数**:
| 参数名 | 类型 | 必填 | 说明 |
|-------|------|-----|------|
| type | string | 否 | 类型筛选（收入/支出） |

**请求示例**: `GET /api/stats/category?type=支出`

**返回示例**:
```json
{
    "code": 200,
    "msg": "成功",
    "data": {
        "list": [
            {
                "category": "餐饮",
                "amount": 1500.00,
                "percentage": "30.00"
            },
            {
                "category": "购物",
                "amount": 1000.00,
                "percentage": "20.00"
            }
        ],
        "total": 5000.00
    }
}
```
