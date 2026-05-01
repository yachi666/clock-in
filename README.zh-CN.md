# Presence

[English](./README.md)

![Stage](https://img.shields.io/badge/stage-early%20stage-F59E0B)
![Platform](https://img.shields.io/badge/platform-iOS-0A84FF)
![语言](https://img.shields.io/badge/docs-%E4%B8%AD%E6%96%87-111827)

> 一款极简、隐私优先的 iOS 考勤应用，目标是让打卡记录尽可能无感发生。

Presence 是一个仍处于探索阶段的开源项目，尝试在 iPhone 上实现自动化考勤记录：用户只需设置一次公司位置，后续由地理围栏在后台感知到岗与离岗，并用克制、轻量的方式展示月度出勤信息。

## ✨ 为什么做 Presence

大多数考勤工具都围绕重复的手动操作设计，而 Presence 希望反过来：

- 减少每天重复打卡的摩擦，
- 让记录过程尽可能安静、轻量，
- 在可行范围内坚持本地优先的数据处理方式，
- 用更贴近 iOS 原生体验的方式呈现出勤信息。

## 🧭 核心特性

- **自动考勤记录**：基于地理围栏感知到岗与离岗
- **隐私优先方向**：尽量采用本地优先的数据处理方式
- **极简主看板**：聚焦月度出勤可视化
- **工作日感知统计**：围绕真实出勤进度组织统计信息
- **原生 iOS 产品方向**：以 SwiftUI、系统定位能力和克制视觉语言为核心

## 🚧 项目状态

Presence 当前处于 **早期阶段（early-stage）/ 设计优先（design-first）**。

当前仓库主要聚焦于：

- 产品定义，
- 技术架构决策，
- 交互与视觉探索，
- 在完整原生实现前的原型迭代。

它**不是**一个已经发布、已经完善或可直接上架 App Store 的成品应用说明页。

## 🖼️ 截图

真机截图会在后续实现和设备测试完成后补充。

计划中的资源路径：

- `screenshots/dashboard.png`
- `screenshots/setup-map.png`

## 🗺️ 路线图

- [ ] 搭建原生 iOS 应用基础
- [ ] 实现地理围栏与权限流转
- [ ] 完成主看板与单日详情交互
- [ ] 验证考勤规则与工作日统计逻辑
- [ ] 补充真机截图并完善公开项目信息

## 📁 仓库结构

- `requirement.md` —— 产品需求与交互轮廓
- `docs/superpowers/specs/` —— 设计决策与功能规格
- `docs/superpowers/plans/` —— 已批准工作的实现计划
- `figma/` —— 设计 / 原型相关资源与实验
- `Shared/` —— 跨平台共享代码与资源
- `Presence/`、`PresenceTests/`、`PresenceWidget/` —— 原生 iOS 应用、测试与 Widget 目标

## 🤝 参与贡献

在项目逐步成形阶段，欢迎提出 issue、讨论、反馈与建议。在某项工作方向与范围足够清晰后，也欢迎提交 pull request。

## 📄 License

仓库目前还没有补充 License 信息。
