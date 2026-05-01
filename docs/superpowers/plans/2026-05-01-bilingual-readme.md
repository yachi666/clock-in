# Bilingual README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `README.md` and `README.zh-CN.md` as mirrored open-source landing pages that accurately present Presence as an early-stage, design-first iOS project.

**Architecture:** Keep the change documentation-only and localized to the repository root. Write the English README first to lock the structure and claims, then write the Chinese README as a meaning-aligned mirror, and finish with a verification pass that checks section parity and all referenced paths.

**Tech Stack:** Markdown, Git, repository file structure inspection with shell commands.

---

## File Structure

- Create `README.md` as the primary English project landing page.
- Create `README.zh-CN.md` as the Chinese mirror of the English README.
- Do not create a `screenshots/` directory yet because Git does not track empty folders; reference future screenshot paths in prose only.
- Do not create a `LICENSE` file as part of this task; the README must clearly state that licensing information is still to be added.

Planned files:

| Path | Responsibility |
| --- | --- |
| `README.md` | English-first repository homepage with badges, project summary, highlights, current status, roadmap, structure, contributing, and license status |
| `README.zh-CN.md` | Chinese mirror of `README.md`, preserving the same structure and meaning |

---

### Task 1: Create the English README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Confirm the root has no README yet**

Run:

```bash
ls README*
```

Expected: shell reports that no matching README file exists yet.

- [ ] **Step 2: Write the English README**

Create `README.md`:

```markdown
# Presence

[简体中文](./README.zh-CN.md)

![Stage](https://img.shields.io/badge/stage-early%20stage-F59E0B)
![Platform](https://img.shields.io/badge/platform-iOS-0A84FF)
![Language](https://img.shields.io/badge/docs-English-111827)

> A minimalist, privacy-first iOS attendance companion designed to make clock-in tracking feel invisible.

Presence is an exploratory open-source project for automatic attendance logging on iPhone. The goal is simple: set your workplace once, let geofencing track arrival and departure in the background, and review your month through a calm, lightweight dashboard.

## ✨ Why Presence

Most attendance tools are built around repetitive manual actions. Presence is built around the opposite idea:

- reduce daily punch-in friction,
- keep the experience quiet and lightweight,
- store attendance data locally whenever possible,
- present workday information with a minimal iOS-native feel.

## 🧭 Highlights

- **Automatic attendance logging** through geofencing-based arrival and departure detection
- **Privacy-first direction** with local-first data handling
- **Minimal dashboard** for monthly presence visibility
- **Workday-aware statistics** designed around actual attendance progress
- **Native iOS product direction** shaped around SwiftUI, system location capabilities, and a calm visual language

## 🚧 Project Status

Presence is currently in an **early-stage, design-first** phase.

This repository is focused on:

- product definition,
- technical architecture decisions,
- interaction and visual exploration,
- prototype iteration before a full native implementation.

It is **not** presented as a production-ready app or an App Store release.

## 🖼️ Screenshots

Device screenshots will be added after implementation and real-device testing.

Planned asset paths:

- `screenshots/dashboard.png`
- `screenshots/setup-map.png`

## 🗺️ Roadmap

- [ ] Establish the native iOS app foundation
- [ ] Implement geofencing and permission flow
- [ ] Build the dashboard and presence detail interactions
- [ ] Validate attendance rules and workday calculations
- [ ] Add device screenshots and polish public project materials

## 📁 Repository Structure

- `requirement.md` — product requirements and interaction outline
- `docs/superpowers/specs/` — design decisions and feature specs
- `docs/superpowers/plans/` — implementation plans for approved work
- `figma/` — design/prototype-related assets and experiments
- `Presence/`, `PresenceTests/`, `PresenceWidget/` — native iOS app, tests, and widget targets

## 🤝 Contributing

Issues, discussions, and thoughtful feedback are welcome while the project is taking shape. Pull requests are also welcome once a piece of work has a clear direction and scope.

## 📄 License

License information has not been added to the repository yet.
```

- [ ] **Step 3: Verify the English README was created**

Run:

```bash
test -f README.md && rg '^## ' README.md
```

Expected:

- `test -f` exits successfully
- `rg` prints the eight section headings:
  - `## ✨ Why Presence`
  - `## 🧭 Highlights`
  - `## 🚧 Project Status`
  - `## 🖼️ Screenshots`
  - `## 🗺️ Roadmap`
  - `## 📁 Repository Structure`
  - `## 🤝 Contributing`
  - `## 📄 License`

- [ ] **Step 4: Commit the English README**

Run:

```bash
git add README.md
git commit -m "docs: add English project README"
```

Expected: Git creates a commit containing only `README.md`.

---

### Task 2: Create the Chinese README Mirror

**Files:**
- Create: `README.zh-CN.md`

- [ ] **Step 1: Write the Chinese README with matching structure**

Create `README.zh-CN.md`:

```markdown
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
- `Presence/`、`PresenceTests/`、`PresenceWidget/` —— 原生 iOS 应用、测试与 Widget 目标

## 🤝 参与贡献

在项目逐步成形阶段，欢迎提出 issue、讨论、反馈与建议。在某项工作方向与范围足够清晰后，也欢迎提交 pull request。

## 📄 License

仓库目前还没有补充 License 信息。
```

- [ ] **Step 2: Verify the Chinese README was created**

Run:

```bash
test -f README.zh-CN.md && rg '^## ' README.zh-CN.md
```

Expected:

- `test -f` exits successfully
- `rg` prints the eight section headings:
  - `## ✨ 为什么做 Presence`
  - `## 🧭 核心特性`
  - `## 🚧 项目状态`
  - `## 🖼️ 截图`
  - `## 🗺️ 路线图`
  - `## 📁 仓库结构`
  - `## 🤝 参与贡献`
  - `## 📄 License`

- [ ] **Step 3: Commit the Chinese README**

Run:

```bash
git add README.zh-CN.md
git commit -m "docs: add Chinese project README"
```

Expected: Git creates a commit containing only `README.zh-CN.md`.

---

### Task 3: Verify Bilingual Alignment and Repository References

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

- [ ] **Step 1: Verify all referenced repository paths exist**

Run:

```bash
test -f requirement.md && \
test -d docs/superpowers/specs && \
test -d docs/superpowers/plans && \
test -d figma && \
test -d Presence && \
test -d PresenceTests && \
test -d PresenceWidget
```

Expected: the command exits successfully with no output.

- [ ] **Step 2: Check section parity between both README files**

Run:

```bash
printf "EN sections:\n" && rg '^## ' README.md && \
printf "\nZH sections:\n" && rg '^## ' README.zh-CN.md
```

Expected: both files print eight top-level `##` sections in the same order.

- [ ] **Step 3: Polish wording if the files drift in meaning**

If needed, edit the files so these lines remain aligned:

```markdown
README.md: Presence is currently in an **early-stage, design-first** phase.
README.zh-CN.md: Presence 当前处于 **早期阶段（early-stage）/ 设计优先（design-first）**。

README.md: Device screenshots will be added after implementation and real-device testing.
README.zh-CN.md: 真机截图会在后续实现和设备测试完成后补充。

README.md: License information has not been added to the repository yet.
README.zh-CN.md: 仓库目前还没有补充 License 信息。
```

- [ ] **Step 4: Inspect the final diff**

Run:

```bash
git --no-pager diff -- README.md README.zh-CN.md
```

Expected: the diff only contains the two new README files with mirrored structure and no broken links.

- [ ] **Step 5: Commit the aligned bilingual README set**

Run:

```bash
git add README.md README.zh-CN.md
git commit -m "docs: add bilingual project readme"
```

Expected: Git creates a final documentation commit with the English and Chinese README files.
