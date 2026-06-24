# Todo App - 开发需求文档

## 项目概述
一个美观简洁的待办事项应用，功能对标微软Todo，但UI更简洁美观。使用Flutter开发，本地存储优先。

## 技术栈
- Flutter 3.32.0
- sqflite (本地SQLite数据库)
- intl (日期格式化)
- flutter_local_notifications (可选：通知提醒)
- Google Fonts (美观字体)

## 功能需求

### 1. 任务管理
- 添加任务（标题必填，描述可选）
- 编辑任务（标题、描述、截止日期、分类）
- 删除任务（左滑删除，带确认）
- 标记完成/未完成（点击复选框）
- 任务详情页（点击任务进入查看/编辑）

### 2. 分类系统
- 预置分类：工作、个人、购物、学习
- 每个分类有：名称、图标、颜色
- 任务可以分配到分类
- 按分类筛选

### 3. 截止日期
- 设置截止日期（日期选择器）
- 显示"今天"、"明天"、"本周"、"逾期"分组
- 逾期任务自动置顶

### 4. 搜索
- 搜索框实时搜索任务标题
- 搜索时高亮匹配文字

### 5. UI/UX 要求
- Material Design 3 风格
- 圆角卡片设计
- 柔和的渐变背景
- 平滑动画（列表插入/删除动画）
- 深色模式支持
- 响应式布局（适配不同窗口大小）

## 数据模型

```dart
class Task {
  int? id;
  String title;
  String? description;
  int categoryId;       // 关联分类ID
  DateTime? dueDate;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;
}
```

```dart
class Category {
  int? id;
  String name;
  String icon;          // emoji 图标
  String color;         // 十六进制颜色值
  int taskCount;        // 非持久化，动态计算
}
```

## 页面结构
1. **主页** - 任务列表（按日期分组）+ 分类筛选栏
2. **添加/编辑任务** - 底部弹出表单
3. **分类管理** - 编辑/管理分类

## 数据库表结构
```sql
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  category_id INTEGER DEFAULT 1,
  due_date TEXT,
  is_completed INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  completed_at TEXT
);

CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color TEXT NOT NULL
);
```
