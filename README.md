# 函数绘图器 iOS 版

为 iOS 16+ 重写的原生 SwiftUI 版函数绘图器。界面全部使用**系统材质的高斯模糊**（`.ultraThinMaterial` / `.regularMaterial`），没有任何自绘 shader。

## 功能

- 多函数绘图，每条曲线自动配色，右上角图例
- 表达式支持省略乘号（`2x`、`(x+1)(x-1)`、`2sin(x)`）、`y=` 前缀、`cot/sec/csc/coth` 等
- 双指缩放（以屏幕中心为基准）、单指拖动平移、双击复位到 -10~10
- 极点自动断开（tan/cot 渐近线不连线）
- 方程行：眼睛图标显隐、✕ 或向右滑动删除，带"红底删除 → 高斯模糊变红 → 塌缩"三段动画
- 导出 PNG（系统分享面板，可存相册）
- 设置页：采样点数、线宽、网格、图例、极点断开、动画开关 + 使用说明
- 所有设置和函数自动保存在本机（UserDefaults）
- 彩蛋：在任意函数输入框输入 `OSNB` 🎆

## 没有 Mac 怎么装到 iPhone 上？

整体思路：**GitHub Actions 的免费 macOS 云电脑帮忙编译 → 下载未签名的 ipa → Windows 上用 Sideloadly 用你自己的 Apple ID 签名安装**。

### 第一步：编译出 ipa（不需要 Mac）

1. 注册一个 GitHub 账号（免费）
2. 新建一个仓库（Repository），把本文件夹里的**所有内容**传上去（注意 `.github` 是隐藏文件夹，别漏了，里面是自动编译脚本）
3. 打开仓库的 **Actions** 标签页，等 "Build IPA" 工作流跑完（约 3~5 分钟）
4. 在该次运行页面底部的 **Artifacts** 下载 `FunctionPlotter-ipa`，解压得到 `FunctionPlotter.ipa`

### 第二步：签名并安装到 iPhone（在 Windows 上做）

1. 下载安装 [Sideloadly](https://sideloadly.io)（Windows 版）
2. iPhone 用数据线连上电脑，首次连接点"信任"
3. 打开 Sideloadly：拖入 `FunctionPlotter.ipa`，输入你的 Apple ID 和密码，点 Start
4. 等待签名并自动安装（免费 Apple ID 有效期 **7 天**，到期重签一次即可；一个免费账号最多同时装 3 个自签 App）
5. iPhone 上：**设置 → 通用 → VPN 与设备管理**，信任你的 Apple ID 证书
6. iOS 16 还需要：**设置 → 隐私与安全性 → 开发者模式** 打开并重启

> 替代方案：AltStore（需要常驻一个后台程序自动续签）、或爱思助手（同样支持自签安装）。

### 有 Mac 的话（可选）

```bash
brew install xcodegen
xcodegen generate
open FunctionPlotter.xcodeproj
```
直接 Xcode 里 Run，或 Product → Archive 导出 ipa。

## 项目结构

```
├── project.yml                  # XcodeGen 工程定义（生成 .xcodeproj）
├── Sources/
│   ├── App.swift                # 入口
│   ├── ExprParser.swift         # 表达式解析（递归下降 + 隐式乘法）
│   ├── PlotModel.swift          # 函数/设置数据模型 + UserDefaults 持久化
│   ├── ContentView.swift        # 主界面（系统材质卡片 + 高斯模糊背景光斑）
│   ├── PlotCanvas.swift         # Canvas 绘图 + 缩放/平移/双击手势
│   ├── EquationRow.swift        # 方程行 + 三段式删除动画
│   ├── SettingsSheet.swift      # 设置页
│   ├── Fireworks.swift          # OSNB 彩蛋
│   └── ShareSheet.swift         # 系统分享面板
├── Resources/Assets.xcassets/   # 应用图标（1024 满幅）
└── .github/workflows/build-ipa.yml  # 云端自动编译
```

## 最低要求

- iOS 16.0+（iPhone / iPad 通用）
- 编译需 Xcode 14+（Swift 5，用了 iOS 16 的 `ImageRenderer`、`scrollContentBackground`、`scrollIndicators`）
