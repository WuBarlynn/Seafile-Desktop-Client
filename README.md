# Seafile Desktop Client

一个使用 **Flutter** 编写的原生 Seafile 桌面客户端，目标是在 macOS 与 Windows 上提供与 Seafile 网页版（SeaHub 13 / 14）尽可能一致的资料库、文件管理和预览体验。界面不依赖 WebView 渲染，所有数据操作通过 Seafile Web API 完成。

> 当前版本：**0.1.0**（持续迭代中）。仓库会随每次迭代更新。

## 为什么是原生实现

- **不使用 Electron / Tauri 的网页控件**：文件列表、目录树、对话框、预览器全部是 Flutter 原生布局与绘制。
- **调用官方 Web API**：登录、资料库、目录、上传、下载、分享、回收站、历史版本、标签、元数据、AI 对话等均直接请求服务端接口。
- **自动识别服务端版本**：通过 `/api2/server-info/` 判断 13/14，并根据服务端扩展（OnlyOffice、SeaDoc、Excalidraw、元数据）动态显示能力。
- **服务端加密资料库**：按网页版流程调用 `set-password` 解锁，下载、上传、预览与打包下载均走服务端解密，不在本地保存明文密钥。

## 已实现功能

- 登录、两步验证（OTP / 信任设备）、Token 安全存储与自动登录
- 资料库分组（我的 / 共享给我 / 群组 / 公共）、创建、重命名、删除、已删除资料库恢复
- 收藏夹、文件活动、共享管理（分享链接集中查看 / 复制 / 删除）
- 14 版资料库视图：左侧可拖动目录树 + 右侧文件表格/网格、面包屑、排序、多选、右键菜单
- 新建菜单（对齐网页版）：新建目录、文本文件、Markdown、Word / Excel / PowerPoint，以及按服务端能力显示的 SeaDoc、Excalidraw、导入 sdoc；上传文件 / 文件夹、分享、复制路径
- 文件操作：重命名、移动、复制、删除、星标、拖拽上传、上传进度面板
- 下载：单文件、文件夹 ZIP 打包下载、下载进度与取消
- 原生预览：图片（含 SVG）、PDF（pdfrx）、文本、Markdown；其他类型可下载或打开网页版
- 加密资料库解锁与已保存密码自动解锁
- 共享链接：创建（密码 / 有效期 / 权限）、列表、复制、删除
- 回收站：恢复、批量恢复、清空（按服务端支持情况）
- 历史版本：文件版本列表、下载、恢复；资料库提交历史
- 标签与元数据：开关、标签管理、文件打标签、标签筛选、属性面板、AI 摘要展示
- 资料库 AI 对话：流式回答、历史会话、Markdown 渲染
- 资料库设置：历史保留策略、扩展属性 / 标签 / AI 摘要开关、全局隐藏属性
- 全局文件名搜索 + 当前资料库本地回退搜索
- 可拖动的侧边栏、目录树与属性面板；统一悬停/焦点反馈

## 服务端兼容性

| 能力 | Seafile 13 | Seafile 14 | 依赖 |
| --- | --- | --- | --- |
| 基础浏览 / 上传下载 / 分享 / 回收站 / 历史 | ✅ | ✅ | Web API |
| 目录树 + 表格布局、AI、元数据与标签界面 | 基础支持 | ✅ | 14 服务端 |
| SeaDoc / Excalidraw 文件创建 | 视服务端 | ✅ | `ENABLE_SEADOC` |
| Office 文件创建 | 视服务端 | ✅ | OnlyOffice 扩展 |
| 在线编辑 Office / SeaDoc / Excalidraw | 通过网页版打开 | 通过网页版打开 | 原生编辑器尚未实现 |

> 服务端必须启用 Web API；SSO-only、强制两步验证、自签名证书等场景仍在持续验证。自签名证书可在登录页的高级选项中允许。

## 构建

要求：Flutter **3.47.9**（Dart 3.13）、macOS 13+ / Windows 10+。

```bash
flutter pub get
flutter analyze
flutter test
flutter build macos --release
# Windows:
flutter build windows --release
```

macOS 产物位于 `build/macos/Build/Products/Release/Seafile.app`，Windows 产物位于 `build/windows/x64/runner/Release/`。

### macOS 权限说明

- 需要网络访问、用户选择文件的读写权限（沙盒 entitlements 已配置）。
- Token 使用 Keychain 存储；为避免分发时依赖开发者证书，macOS 使用 legacy Keychain（`usesDataProtectionKeychain: false`），不需要 Keychain Sharing entitlement。

## 项目结构

```
lib/
  api/          Seafile Web API 客户端、模型、错误映射
  core/         本地化、主题、格式化、文件类型
  state/        会话、资料库工作区、传输队列、AI 会话
  ui/           登录、侧边栏、14 版文件视图、预览、分享、回收站、历史、设置
assets/web/     SeaHub 同款 SVG / PNG 图标与品牌资源
```

## 已知限制（持续迭代）

- OnlyOffice / SeaDoc / Excalidraw 的在线编辑尚未原生嵌入，使用“在网页版中打开”完成编辑。
- 视频/音频暂不内置播放；知识库（Wiki）仍为占位入口（可跳转网页版）。
- 13 版已识别并隐藏 AI/调整工具入口；更细的 13 版专属差异仍在逐项对齐。Windows 构建尚未在真实 Windows 机器上验证。
- 不做双向文件夹同步（官方桌面端的同步协议不在本客户端范围内）。
- 暂不支持多账号同时在线。

## 开发说明

- API 端点以 SeaHub 14 源码与本地 13/14 环境实测为准，避免依赖过时文档。
- 版本差异通过服务端版本与能力探测驱动，UI 不应假设固定服务端版本。
- 欢迎提交 Issue / PR；仓库地址：<https://github.com/WuBarlynn/Seafile-Desktop-Client>

## 许可证

本项目遵循仓库根目录的 Apache License 2.0。Seafile 是海文（Haiwen）的商标；本项目为非官方客户端。
