# Personal Growth Workbench

一个面向 Windows 桌面的离线优先个人成长管理工作台：把任务、目标、课程安排、日历、习惯、学习修炼和随手记录集中在一个本地应用中，并通过可选的外部 API 获取 AI 新闻简报。
跳转至Release页面安装personal_growth_workbench.exe文件，双击进行安装即可快速使用，链接如下：
https://github.com/fengfegn/personal_growth_workbench/releases
## ✨ Features

- **工作台首页**：聚合今日任务、最多三项今日重点、目标进度和最近的重要日子。
- **任务与目标**：支持任务优先级、备注、截止时间、目标关联、目标层级和里程碑；关联任务或里程碑变化时会同步目标进度。
- **课程与日历**：提供 7 天周视图、5 个时间段、课程备注、重要日子、生日/纪念日年度重复、节假日以及任务/随心记标记。
- **习惯养成**：每日打卡、归档/恢复、连续统计，以及按月或按年查看的完成率热力图。
- **图灵修炼**：记录学习与锻炼时长，管理功法阶段、阶段考核和境界突破试炼，支持倒计时与全屏计时。
- **随心记与热点**：随心记支持标签、搜索、置顶、收藏、归档和文本/图片/音频/视频/链接等内容块；热点模块支持当天 AI 简报缓存和按需刷新。

## 🧭 Architecture

当前代码采用按功能拆分的 Flutter 分层结构：

```text
Flutter UI / GoRouter
        ↓
Riverpod Providers
        ↓
Feature Repository + Domain Models
        ↓
Drift / SQLite（本地业务数据）
        ↓
本地 UI 状态刷新
```

外部服务只参与可选流程：

```text
热点页
  ↓ 手动更新
AI 简报接口（tech / money / hot）
  ↓
本地相关性过滤 + 当日缓存
  ↓ 可选
OpenAI 兼容模型筛选 / 详情接口
```

应用通过 `flutter_secure_storage` 保存 API Key；普通配置和业务数据写入本地 Drift/SQLite。API Key 不写入普通设置 JSON，也不写入日志或模型提示词。

## 📦 Project Structure

```text
personal_growth_workbench_spec/
├── lib/
│   ├── app/                       # 应用主题、路由和桌面导航壳
│   ├── core/                      # Drift 数据库、日期、日志和错误基础设施
│   ├── features/                  # 按功能组织的 domain/data/application/presentation
│   │   ├── dashboard/             # 首页聚合
│   │   ├── tasks/                 # 任务与今日重点
│   │   ├── goals/                 # 目标、层级和里程碑
│   │   ├── courses/               # 课程周视图、导入和导出
│   │   ├── calendar/              # 月历、节日和重要日子
│   │   ├── cultivation/           # 图灵修炼、计时和进阶
│   │   ├── habits/                # 习惯、打卡和热力图
│   │   ├── quick_notes/            # 随心记和内容块编辑器
│   │   ├── hotspots/               # AI 简报、信息源和缓存
│   │   ├── ai/                    # AI 配置与安全存储
│   │   ├── profile/               # 用户昵称
│   │   └── settings/              # 应用设置页
│   └── main.dart                  # ProviderScope 和应用入口
├── assets/fonts/                  # 随应用打包的 Noto Sans SC 字体
├── test/                          # Repository、领域逻辑和 Widget 测试
├── windows/                       # Windows Runner 与插件注册
├── installer/setup.iss            # Inno Setup 安装脚本
├── scripts/fetch_article_content.py # 热点正文抓取辅助脚本
├── project_docs/                  # 本地产品、架构和开发记录
├── pubspec.yaml                   # Flutter/Dart 依赖与资源声明
├── pubspec.lock                   # 依赖锁定版本
└── analysis_options.yaml          # Dart 静态分析配置
```

`lib/core/database/app_database.dart` 定义 Drift 表和迁移，当前 schema version 为 `11`；`app_database.g.dart` 是 Drift 生成文件，请不要手工编辑。工作区中的 `project_docs/` 和 `scripts/` 当前被 `.gitignore` 排除，若要通过 Git 分发热点正文抓取能力，应确认这些文件是否需要纳入版本控制。

## 🛠️ Installation

### Prerequisites

- Flutter SDK，且其 Dart SDK 满足 `pubspec.yaml` 中的约束：`^3.12.2`。
- Windows 桌面开发环境，并已启用 Windows target：

  ```bash
  flutter config --enable-windows-desktop
  flutter devices
  ```

- Python 3（可选）：源码中的通用热点生成流程可调用 `scripts/fetch_article_content.py` 抓取文章正文；当前 `/hotspots` 的 AI 简报列表/详情路径不依赖 Python。Python 不可用时，通用流程会回退到信息源已有的标题或摘要。

项目没有 `requirements.txt`、`package.json` 或 `environment.yml`；Dart/Flutter 依赖全部由 `pubspec.yaml` 管理。

### Install dependencies

```bash
cd personal_growth_workbench_spec
flutter pub get
```

## 🚀 Quick Start

如果不想clone整个项目源码，可以只安装Personal Growth Workbench.exe文件，具体在Release下。

当前验证目标是 Windows 桌面：

```bash
cd personal_growth_workbench_spec
flutter pub get
flutter run -d windows
```

也可以直接构建 Windows 版本：

```bash
flutter build windows --release
```

构建产物位于 `build/windows/x64/runner/Release/`。若已安装 Inno Setup，可在完成 Release 构建后执行：

```bash
iscc installer/setup.iss
```

安装脚本会读取上述 Release 目录，并生成 Windows 安装包到 `installer/output/`。



## 🧩 Usage

### 任务、目标和日历

从左侧导航进入对应页面即可：

| Route | 功能 |
| --- | --- |
| `/` | 首页工作台 |
| `/tasks` | 今日任务、优先级、截止时间和今日重点 |
| `/goals` | 目标层级、里程碑和进度 |
| `/courses` | 课程周视图、课程导入/导出 |
| `/calendar` | 月历、节日、任务、随心记和重要日子 |
| `/habits` | 习惯打卡、统计和热力图 |
| `/cultivation` | 学习/锻炼计时、功法和境界进阶 |
| `/quick-notes` | 随心记时间线和文章式编辑器 |
| `/hotspots` | 当日 AI 简报缓存和手动更新 |
| `/settings` | 主题、AI 与信息源配置 |

### 课程导入与导出

在“课程安排”页面的菜单中：

- 导入支持 Markdown、CSV、JSON，以及标准 `.xlsx` 文件的第一张工作表。
- 导入会先解析并显示预览，确认后才写入本地数据库；相同课程和相同 session 时间会去重，相邻连续节次会合并。
- 支持导出完整 JSON 和当前周 Markdown。
- `.xls` 文件可以被文件选择器选中，但当前解析器只直接读取 `.xlsx`；旧式 `.xls` 请先另存为 CSV、Markdown 或 `.xlsx`。

### 配置 AI 热点

热点页的正常使用需要用户自行提供外部服务凭据，项目不附带 API Key：

1. 打开“设置”，在 AI 配置中选择 ChatGPT、DeepSeek 或 Kimi，填写 endpoint、model 和 API Key，启用后可先点击“测试 AI 连接”。
2. 在信息源中新增并启用 AI 简报列表接口。当前热点简报读取的是 endpoint 路径包含 `/fapigw/aibrief/list` 的信息源；
API申请网址：https://www.juhe.cn/docs/api/id/850
每日有10次免费请求调用

3. 回到“今日热点”，点击“更新”。列表请求按 `tech`、`money`、`hot` 三类获取并写入当天本地缓存；打开文章详情时才按需请求详情内容。

热点请求预算默认每天 `10` 次，可在设置中调整为 `1`～`100` 次。一次列表更新预留 `3` 次请求，首次打开一篇没有缓存正文的文章再使用 `1` 次；预算按本地日期重置。

如果没有配置 AI 或信息源，核心任务、目标、课程、日历、习惯、修炼和随心记功能仍可使用。

## 💾 Data and Storage

- 首次启动会在系统应用文档目录创建 `personal_growth_workbench.sqlite`。
- 业务数据包括任务、目标、里程碑、随心记、课程、日历事件、修炼记录、习惯打卡和热点缓存。
- 应用采用本地优先写入；删除操作在多数业务模块中采用软删除，以保留关联或历史数据。
- 图片、音频和视频内容块保存为本地路径或 URL 引用，不会自动把外部媒体复制进仓库。
- 仓库不包含内置数据集、预置数据库、模型权重或公开 checkpoint；AI 能力依赖用户配置的外部服务。

## 🧪 Development and Tests

安装依赖后运行静态分析和完整测试：

```bash
dart analyze lib test
flutter test --no-pub
```

测试覆盖数据库迁移与 Repository、任务/目标联动、课程解析与导入、日历、随心记、习惯统计、修炼结算、AI 客户端、热点过滤和关键页面 Widget 行为。

如需重新生成 Drift 代码，可使用项目已有的开发依赖：

```bash
dart run build_runner build --delete-conflicting-outputs
```


