# 源码运行与构建

[返回项目首页](../../README.md) · [贡献指南](../../CONTRIBUTING.md)

这里只面向开发者。下载并使用安装包不需要执行以下命令。

## 桌面开发

准备兼容项目工具链的 Node.js 与 npm，在仓库根目录运行：

```powershell
npm ci
npm run dev
```

项目使用 Electron + React + TypeScript，`npm run dev` 同时启动 Vite 渲染端和 Electron 主进程。

## 检查与打包

```powershell
npm run typecheck
npm test
npm run build
npm run pack
```

`npm run pack` 在 Windows 同时生成便携版与 NSIS 安装版。只需便携版时使用 `npm run pack:portable`。macOS 构建入口为 `npm run dist:mac`，完整跨平台发行使用仓库 CI。

Windows 产物示例（`<版本>` 为 `package.json` 中的版本号）：

```text
release/Langbai-NovelAI-Studio-<版本>.exe
release/Langbai-NovelAI-Studio-Setup-<版本>.exe
release/Langbai-NovelAI-Studio.exe
```

兼容旧启动脚本的别名 `release/NovelAI-Image-Desktop.exe` 仍会生成。根目录 `启动程序.bat` 是开发 / 本地运行相关入口，不应替代给普通用户的安装包指引。

## iOS 开发

iOS 客户端位于 `mobile/`，使用 Flutter 3.24.0（与 CI 一致）。在 `mobile/` 目录运行：

```bash
flutter pub get
flutter analyze
flutter test
```

测试会读取仓库根目录的 `shared/`、`tests/fixtures/` 等共享夹具，请在完整仓库中运行。编译需要 macOS 与 Xcode：

```bash
flutter build ios --release --no-codesign
```

产物 `build/ios/iphoneos/Runner.app` 没有签名；CI 把它打包成未签名 IPA，安装前需要自行签名。iOS 应用内置了桌面的原数据解析 Worker 和提示词模板，改动对应的桌面源码后运行 `node scripts/build-mobile-metadata-runtime.mjs` 与 `node scripts/sync-mobile-prompt-templates.mjs` 同步，CI 会用 `--check` 检查两者是否最新。

## 代码地图

| 位置 | 职责 |
| --- | --- |
| `electron/main.ts` | 窗口、主进程与 IPC 注册 |
| `electron/ipc/nai.ts` | NovelAI API、反推、转换与模型检测 |
| `electron/ipc/store.ts` / `storage.ts` | 设置、历史、目录与分组 |
| `electron/preload.ts` | 暴露受控的渲染进程接口 |
| `src/app/` | 顶部导航与工作区外壳 |
| `src/tavern/` | 反推 / 转换的系统提示词预设与 SillyTavern JSON 预设导入 |
| `src/ToolsHub.tsx` / `src/comic/` | 工具入口与漫画分镜流程 |
| `src/MetadataInspector.tsx` | 图片原数据查看 |
| `src/store.ts` / `src/types.ts` | 状态、共享类型和默认参数 |
| `mobile/` | iOS 客户端（Flutter）：`lib/` 为 Dart 源码，`ios/` 为 Xcode 工程 |

## 发行与协作

版本标签 `v*` 同时触发 Windows / macOS 桌面工作流和 iOS 工作流，产物附加到同一个 Release。维护者发布前应检查版本字段、测试结果、发行说明及 CI 权限；README 编辑本身不需要创建发行标签。

桌面与 iOS 共用一个版本号：发行时 `mobile/pubspec.yaml` 的 `version` 写成与 `package.json` 相同的版本号，`+` 后的构建号每次发行加一；`mobile/lib/models/nai_models.dart` 的 `appVersion` 也改成同一版本号。这些字段与 `package.json` 不一致时桌面单元测试会报错；在版本标签上，标签或这些字段与 `package.json` 不一致时 iOS 工作流不会构建 IPA。

[桌面工作流](../../.github/workflows/build.yml) · [iOS 工作流](../../.github/workflows/build-mobile.yml) · [版本记录](../RELEASE_NOTES.md)

不要提交 Token、服务 Key、本机用户配置或私人素材。贡献前阅读 [CONTRIBUTING.md](../../CONTRIBUTING.md) 与 [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)。
