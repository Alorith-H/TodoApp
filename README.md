# ✅ Todo App

一个简洁美观、丝滑流畅的待办事项应用，使用 **Flutter** 构建，支持 **Android** 和 **Windows** 桌面端。

> 灵感来源于 Microsoft To Do，但更轻量、更高效。

---

## 功能特性

| 功能 | 说明 |
|------|------|
| 📝 **任务管理** | 添加、编辑、删除任务，支持标题和详细描述 |
| ✅ **勾选完成** | 点击复选框标记完成，丝滑动效 + 异步写库（零延迟） |
| 🗂️ **分类标签** | 自定义标签（图标 + 颜色），按标签筛选任务 |
| 📅 **截止日期** | 为任务设置截止日期，自动归类为「逾期 / 今天 / 明天 / 本周 / 以后」 |
| 🔄 **每日重复** | 开启后每天 0 点自动生成该任务 |
| 🔍 **搜索** | 按标题实时搜索任务 |
| 🎨 **主题定制** | 切换深色/浅色模式 + 自定义主题色 |
| 📌 **滑动删除** | 右滑删除，支持撤销 |
| 🚀 **丝滑体验** | 全部操作先本地刷新、后异步写库，交互不卡顿 |

---

## 截图

| 浅色模式 | 深色模式 | 任务编辑 |
|---------|---------|---------|
| *(装好 App 后自行体验)* | *(装好 App 后自行体验)* | *(装好 App 后自行体验)* |

---

## 快速开始

### 环境要求

- Flutter SDK ≥ 3.22
- Android Studio / Xcode（按平台需求）
- Android SDK 或 Windows 开发工具

### 克隆 & 运行

```bash
# 克隆仓库
git clone https://github.com/Alorith-H/TodoApp.git
cd TodoApp

# 安装依赖
flutter pub get

# 运行（默认连接设备）
flutter run

# 编译 Android APK
flutter build apk --debug
```

### 编译提示

如果你在中国大陆，编译 APK 时建议设置镜像源加速：

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter build apk --debug
```

---

## 技术栈

- **框架**: Flutter 3.32 (Dart 3.8, Material 3)
- **数据库**: 原生 `sqflite`（Android） / `sqflite_common_ffi`（桌面）
- **状态管理**: `setState` + 局部刷新模式
- **持久化**: `shared_preferences`（设置）、`sqflite`（任务数据）
- **构建**: Gradle 8.12 + AGP 8.5.0
- **镜像**: 华为云 Maven（中国区编译）

### 数据库方案

| 平台 | 驱动 | 说明 |
|------|------|------|
| Android / iOS | `sqflite` | 原生 SQLite 实现 |
| Windows / macOS / Linux | `sqflite_common_ffi` | FFI 加载系统 sqlite3 |

---

## 项目结构

```
TodoApp/
├── lib/
│   ├── main.dart                 # 入口 & 主题配置
│   ├── db_init.dart              # 桌面端 FFI 初始化
│   ├── database/
│   │   └── database_helper.dart  # 数据库 CRUD（按平台分流）
│   ├── models/
│   │   ├── task.dart             # 任务模型
│   │   ├── category.dart         # 分类模型
│   │   └── settings_model.dart   # 设置模型
│   └── screens/
│       ├── home_screen.dart      # 主页面（任务列表）
│       ├── task_form_screen.dart # 添加/编辑任务
│       └── settings_screen.dart  # 设置页面
├── android/                      # Android 平台配置
├── windows/                      # Windows 平台配置
├── ios/                          # iOS 平台配置
├── web/                          # Web 平台配置
├── macos/                        # macOS 平台配置
├── linux/                        # Linux 平台配置
└── pubspec.yaml                  # 依赖配置
```

---

## 开发路线

- [x] 基础任务 CRUD
- [x] 分类标签系统
- [x] 截止日期 & 自动分组
- [x] 每日重复任务
- [x] 深色/浅色主题
- [x] 自定义主题色
- [x] 丝滑交互优化
- [ ] 通知提醒
- [ ] 小组件 (Android Widget)
- [ ] 同步（WebDAV / 自建后端）
- [ ] 多选批量操作

---

## License

MIT License — 随便用，欢迎 PR。
