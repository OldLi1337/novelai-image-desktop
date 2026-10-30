<!-- release-summary: current-version-only; downloads: Latest -->
# Langbai NovelAI Studio（个人修改版）

> [!IMPORTANT]
> **这是我按自己的需求修改的个人版本，不是原作者发布的官方版本。** 本仓库 fork 自 [2786886095/novelai-image-desktop](https://github.com/2786886095/novelai-image-desktop)，在原项目源码的基础上按我自己的使用需求增改并精简了部分功能，具体见[与原版的区别](#changes)。这个版本的问题请在本仓库反馈，不要提交给原作者。

**下载入口：** [GitHub Latest](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) 提供当前发行说明与实际附件；安装方式与限制见下方下载区。

### 从一句灵感，到一组作品。

NovelAI 图像创作工作台，Windows / macOS 桌面版，界面为简体中文；第三方诊断日志保留原文。

![芙宁娜主题宣传插画，软件界面为视觉示意](./docs/assets/readme/furina-workbench.png)

<a href="https://github.com/OldLi1337/novelai-image-desktop/releases/latest"><img src="https://img.shields.io/badge/下载最新版-GitHub-2563EB?style=for-the-badge&amp;labelColor=2563EB" width="216" alt="下载最新版 · GitHub" /></a>
&nbsp; **[首次使用教程](./docs/guide/GETTING_STARTED.md)** · **[查看全部功能](./docs/guide/FEATURES.md)**

> 需配置自己的 **NovelAI Persistent API Token**，生成费用与模型权限以 NovelAI 账号为准。[反推、转换等可选 AI 服务需另行配置](./docs/guide/GETTING_STARTED.md#optional)。

[![Release](https://img.shields.io/github/v/release/OldLi1337/novelai-image-desktop?color=2563eb)](https://github.com/OldLi1337/novelai-image-desktop/releases/latest)
[![Build](https://github.com/OldLi1337/novelai-image-desktop/actions/workflows/build.yml/badge.svg)](https://github.com/OldLi1337/novelai-image-desktop/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/Code-MIT-586069)](./LICENSE)

<a id="changes"></a>
## 与原版的区别

以原项目 2.6.7 的源码为基础，到当前发行版为止改了下面这些地方。每次发行的完整说明见[更新记录](./docs/RELEASE_NOTES.md)，更早的记录见 [docs/history](./docs/history/)。

### 新增与改进

- **增强改为官方倍率**：「生成 → 增强」改为与 NovelAI 官方一致的 1× / 1.5× / MAX。原来的 2× 对 832×1216 等常见尺寸会超过官方像素上限而无法执行；1.5× 按官方方式对齐 64 像素网格（832×1216 → 1280×1856）。
- **提示词库常驻显示**：正面提示词框下方常驻「正面预设 / 保存当前 / 自定义提词」，负面提示词框下方常驻「负面提示词库 / 保存当前」，不再藏在工具栏的「更多」菜单里。
- **正面预设可追加**：正面预设新增「追加到当前提示词」，与负面词库一致；角色预设会追加到现有角色之后。
- **提示词标签**：正面预设、负面词库和自定义提词块都可以设置标签，可按标签筛选，搜索同时匹配名称、内容和标签，输入 `#标签` 可精确筛选。标签会随设置、负面词库导入导出和数据备份恢复一起保留。
- **提示词联想修复**：在输入框内任意位置点击、移动光标、按 Esc、点击外部或失去焦点时联想列表都会关闭；选中的标签总是替换触发联想的那个词；回车选择当前高亮的项，列表在静止的鼠标下弹出或滚动时不会误选；列表不会被面板遮挡；补全多词标签和带权重的写法时不再重复已输入的词。
- **账户无法解密时仍可启动**：上次使用的账户在本机无法解密时（例如从其他电脑复制了设置），软件会取消选择该账户并正常启动，不再停在启动页。
- **其他修正**：下拉菜单中长名称的排版；几处直接显示内部键名的文字；在线参考目录无法访问时改读安装包内置的目录；错误提示去掉英文的 “Error invoking remote method” 前缀；备份恢复时账户验证失败或凭据无法解密会给出中文原因。

### 精简

- **只保留桌面端**：删除 Android、iOS 与 Linux 客户端及其构建配置，只提供 Windows 与 macOS 安装包。
- **删除生图智能体**：移除「生图智能体」标签页（聊天式生图助手及其模型服务商配置、对话记录）。设置中的「本地 MCP 服务」保留，Claude Code、Codex 等外部智能体仍可通过 MCP 调用本软件。
- **删除本地 Agent 组件**：移除仅 Windows 的本地 Agent（Studio Harness）组件及其插件、组件下载与更新。
- **删除本地 ComfyUI**：移除本地 ComfyUI 工作台、环境引导与相关设置；读取 ComfyUI / SD 图片中的生成参数不受影响。
- **删除软件内更新**：软件不再检查、下载或安装更新，新版本请从 Latest 手动下载。
- **删除用不到的 AI 模型运行库**：移除原项目里就无法进入的旧「目标图评分」界面，以及只有它使用的内置模型运行库，Windows 程序目录约减小 42 MB；画风实验室里的目标画风自动迭代与随机画师串抽卡不受影响。
- **只保留简体中文界面**：移除繁体中文、英语、日语、韩语界面与语言切换；提示词翻译仍可选择英语、日语等目标语言，中文标签转换不受影响。
- **关于页**：移除原作者的 QQ、交流群与赞赏码，项目链接改为本仓库，保留原项目的 MIT 版权声明。

### 从原版换到本版

- 直接覆盖安装原版即可，设置、历史、作品和保存的提示词原样沿用；原项目及旧版本导出的设置和 `.naisbackup` 备份也能导入。安装前请先关闭正在运行的旧版。
- 已删除功能的数据会被忽略（例如生图智能体和本地 ComfyUI 里保存的内容），界面语言统一为简体中文。
- 换装前建议先在原版「设置 → 备份与恢复」导出一份备份。装了本版后不要再用原版打开同一份数据：原版不认识本版新增的标签，重新保存时会把标签丢掉。
- 原版的软件内更新只会检查原项目的发行版，不会推送本版本；本版本也没有软件内更新，以后的新版本请到 Latest 手动下载。

<a id="quick-start"></a>
## 先完成你的第一张图

1. **下载客户端**：从[下载区](#download)选择适合系统的安装包。普通使用者不需要安装 Node.js，也不需要运行源码命令。
2. **连接账号**：打开「设置 → API 配置」，按软件内图文教程获取并填写 Token，点击「保存账号」完成验证，再用「刷新积分」确认余额。
3. **开始创作**：进入「生成」，选择账号可用模型，输入提示词，检查尺寸、张数与预计费用，然后生成。结果会保存到输出目录并进入历史与素材。

第一次使用可以从一段简单的英文提示词开始，其余参数先保留默认值：

```text
1girl, solo, blue hair, blue eyes, white dress, garden, sunlight, smile
```

连接失败、Token 获取方式和结果保存位置见[首次使用教程](./docs/guide/GETTING_STARTED.md)。先跑通一次生成，再配置可选的 AI 和标签服务。

<a id="features"></a>
## 按创作任务找到工具

| 你想做什么 | 使用功能 | 从哪里开始 |
| --- | --- | --- |
| 从描述生成图片，或调整已有图片 | 文生图、图生图、角色提示词与位置 | [生成与修图](./docs/guide/FEATURES.md#generation) |
| 批量制作连续画面并挑选终稿 | 漫画生成器、分镜参数、候选图、主图 ZIP | [漫画与批量任务](./docs/guide/FEATURES.md#comic) |
| 让角色或氛围更接近参考 | 精准参考、氛围迁移、在线参考目录、预设库 | [角色参考](./docs/guide/FEATURES.md#reference) |
| 找到合适的描述和画风 | 灵感胶囊、反推、转换、画风实验室、个人法典 | [提示词与画风](./docs/guide/FEATURES.md#prompt) |
| 复用一张图的生成参数 | 原数据读取、在线画廊、兼容参数选择应用 | [素材与参数复用](./docs/guide/FEATURES.md#reuse) |
| 整理结果、继续迭代 | 历史分组、参数复用、锁种变体、重命名、ZIP 导出 | [记录与管理](./docs/guide/FEATURES.md#manage) |

### 分镜与参考，各有自己的工作流

- **漫画生成器**：导入逐行 Tag 或 JSON/CSV 分镜，统一全局风格与负面词，再单独微调某个分镜。每个分镜可以生成多张候选、追加尝试、选定主图，最后只导出选中的主图。
- **角色参考预设库**：按游戏、角色与形态寻找参考，将精准参考或氛围迁移配置保存为预设，分组管理、导入导出，下次创作直接复用。参考效果取决于所用模型及参数，并不保证每张图完全一致。

<a id="screenshots"></a>
## 看看实际工作台

下面是**原项目 2026-08-30 / v2.0.1 的历史实际界面截图**，仅展示旧版布局，不代表本版本的当前界面；功能与入口以当前安装包为准。顶部芙宁娜配图是宣传插画，不作为功能截图。

![生成工作台：左侧提示词与参数、中间画布、右侧历史与素材](./docs/assets/readme/workbench-light.png)

<details>
<summary>展开查看设置与外观</summary>

![设置中心：主题与工作台布局配置](./docs/assets/readme/settings-light.png)

</details>

<a id="download"></a>
## 下载与安装

这里提供的是本修改版的安装包；原版请到[原项目](https://github.com/2786886095/novelai-image-desktop)获取，两者的区别见[与原版的区别](#changes)。

### Latest · 当前发行文件

[最新发行说明与附件](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) · [更新记录](./docs/RELEASE_NOTES.md) · [默认分支源码](https://github.com/OldLi1337/novelai-image-desktop/tree/main)

| 平台 | 下载入口 | 在 Latest 附件中选择 |
| --- | --- | --- |
| Windows x64 · 安装版 | [安装版](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) | 文件名含 Setup 的 EXE；安装前备份设置与作品 |
| Windows x64 · 便携版 | [便携版](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) | 不含 Setup 的便携 EXE；下载新包替换，便携版不等于零痕迹 |
| macOS · Intel / Apple Silicon | [Universal DMG](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) / [ZIP](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) | 通用 DMG 或 ZIP；签名 / 公证状态以 Latest 说明为准 |

附件的 SHA256 以 [Latest](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) 发行页各附件显示的摘要为准，签名和安装限制见 Latest 的说明；首页不写死发行版本、日期标签、校验文件名或带版本的安装包名。

**请手动下载安装。** 软件内不提供更新检查或自动更新；新版本请从 Latest 下载对应平台的安装包。

安装包未在 Windows / Mac 真机上做安装验收；Windows 包未做代码签名，macOS 包未签名、未公证，详见 [Latest](https://github.com/OldLi1337/novelai-image-desktop/releases/latest) 的说明。

Windows 便携版与安装版共享本机用户数据目录 `%APPDATA%\novelai-image-desktop\`。**便携版不等于零痕迹，也不是所有数据都写在程序旁边。** 更换包前建议备份设置和作品。

各平台文件统一从 GitHub 下载，按上表手动安装；换包前的备份与数据位置见[安装与更新](./docs/guide/GETTING_STARTED.md#updates)。

<a id="faq"></a>
## 常见问题

<details>
<summary><b>软件开源，是不是就能免费生图？</b></summary>

客户端代码开源不等于 NovelAI 服务免费。需要自己的 NovelAI 账号、Token 和对应模型权限；Anlas、订阅额度与实际扣费以官方为准。软件显示的预计费用用于辅助判断。

</details>

<details>
<summary><b>只想生成图片，也要配置反推和转换 API 吗？</b></summary>

不需要。基础 NovelAI 生图先配置 NovelAI Token 即可。图片反推使用视觉模型 API，提示词转换使用文本模型 API；这些是可选能力，费用与连接状态分别计算。

</details>

<details>
<summary><b>能读取 ComfyUI / SD 图片参数，是不是也能运行这些模型？</b></summary>

原数据工具只读取图片保留的元数据，不会因读取而执行模型。兼容的提示词、尺寸、Seed 等可应用到 NovelAI；模型、VAE、LoRA 和工作流信息用于查看；软件本身不运行 SD 模型或 ComfyUI 工作流。

</details>

更多连接、保存与报错排查见[首次使用教程](./docs/guide/GETTING_STARTED.md#troubleshooting)。

<a id="privacy"></a>
## 数据与连接方式

- 客户端通过 API 连接 NovelAI，不依赖网页登录自动化、Cookie 抓取或浏览器点击。
- 桌面端由 Electron 主进程处理 NovelAI 请求，渲染进程不直接持有 Token；凭据与设置保存在本机配置中。
- 生成会将提示词与所需参考图片发送给 NovelAI；使用反推或转换时，相应输入会发送到你配置的模型服务。在线画廊、参考目录和 Tag/MCP 服务各自访问对应数据源。
- 原数据读取在本地完成，不调用生图接口、不消耗 Anlas；部分离线词库和已保存的参考预设也可离线查看。**离线查看不代表离线生图。**
- 提交 Issue 前请移除 Token、API Key、私人对话与敏感图片。

<a id="development"></a>
## 给开发者

桌面端：Electron + React + TypeScript。

[源码运行与构建](./docs/guide/DEVELOPMENT.md) · [贡献指南](./CONTRIBUTING.md) · [第三方声明](./THIRD_PARTY_NOTICES.md) · [MIT 代码许可证](./LICENSE)

<a id="community"></a>
## 交流与反馈

这里只处理本修改版的问题：[提交问题](https://github.com/OldLi1337/novelai-image-desktop/issues/new) · [查看已有问题](https://github.com/OldLi1337/novelai-image-desktop/issues)。原版的问题请到[原项目](https://github.com/2786886095/novelai-image-desktop)反馈。

---

本仓库修改自 [2786886095/novelai-image-desktop](https://github.com/2786886095/novelai-image-desktop)，感谢原作者的开源工作。代码沿用原项目的 MIT 许可证并保留原版权声明，见 [LICENSE](./LICENSE)。

看板娘为《原神》角色芙宁娜，宣传图为 AI 生成的非官方同人视觉，与 HoYoverse / NovelAI 无官方合作或背书关系。项目代码的 MIT 许可不授予第三方角色、商标或素材权利。配图说明见[视觉素材记录](./docs/assets/readme/ASSETS.md)。
