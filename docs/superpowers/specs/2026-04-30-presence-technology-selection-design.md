# Presence 技术选型设计文档

## 1. 背景与结论

`Presence` 的目标是做一款 **原生 iOS 自动考勤应用**：用户首次设置公司位置后，应用通过地理围栏在后台自动记录到岗与离岗时间，并以极简的主看板呈现月度出勤结果。

基于 `requirement.md` 中对 `CoreLocation`、`CLCircularRegion`、`SwiftData`、`Live Activities`、iOS 视觉风格和本地隐私的要求，本项目的正式技术路线确定为：

- **客户端**：原生 iOS
- **UI 框架**：`SwiftUI`
- **本地存储**：`SwiftData`
- **定位与围栏**：`CoreLocation` + `CLCircularRegion`
- **地图设置页**：`MapKit`
- **锁屏展示**：`ActivityKit` / `Live Activities`
- **网络访问**：`URLSession`
- **依赖管理**：`Swift Package Manager`
- **架构风格**：轻量分层，按 Feature 拆分，使用 MVVM / Observation

## 2. 选型目标

本次技术选型以以下目标为优先级：

1. **完整支持 iOS 系统能力**：后台定位、地理围栏、Live Activities 必须可靠可用。
2. **纯本地优先**：除节假日/工作日数据外，不引入重后端，不做云同步。
3. **符合 Apple 平台体验**：视觉、动效、权限引导和信息架构应贴近原生 iOS。
4. **保持实现复杂度可控**：优先选择系统原生能力，避免为“未来可能的多端”提前付出过高复杂度。

## 3. 不采用的路线

### 3.1 不采用跨平台主栈

`Flutter`、`React Native` 这类方案虽然在 UI 搭建速度和多端扩展上有优势，但本项目的核心难点并不在普通页面，而在于：

- 地理围栏和后台位置状态的可靠性
- 权限申请与状态管理
- Live Activities 集成
- 本地持久化和生命周期恢复

这些部分最终都需要回到原生桥接处理，整体复杂度不会更低。

### 3.2 不采用 Web / PWA / Hybrid 方案

Web 栈无法自然满足本项目对后台定位、系统触发和锁屏状态展示的需求，因此不作为正式产品路线。

### 3.3 不复用 `figma/` 目录中的 React 原型代码

`figma/` 目录当前是一个由 Figma Make 生成的 **React + Vite + MUI / Radix 风格原型工程**。它适合承载：

- 视觉风格参考
- 布局结构参考
- 交互节奏参考

但不适合作为正式产品代码基础。正式产品应以原生 iOS 重建，`figma/` 仅作为设计参考输入。

## 4. 正式技术栈

| 层级 | 选型 | 说明 |
| --- | --- | --- |
| App UI | `SwiftUI` | 最贴合极简界面、动画和 iOS 视觉规范 |
| 状态与界面组织 | `Observation` + MVVM | 保持轻量，不引入过重架构框架 |
| 本地数据 | `SwiftData` | 与 Apple 生态一致，适合本地隐私存储 |
| 定位与围栏 | `CoreLocation` + `CLCircularRegion` | 满足后台进出区域监听 |
| 地图 | `MapKit` | 用于 Setup 页选点和围栏半径设置 |
| 锁屏状态 | `ActivityKit` | 展示“已在办公 X 小时” |
| 网络 | `URLSession` | 仅用于节假日/工作日数据获取 |
| 依赖管理 | `SPM` | 降低工程复杂度，少依赖 |
| 测试 | `Swift Testing` / `XCTest` + `XCUITest` | 规则逻辑与关键流程分层测试 |

## 5. 架构边界

建议按能力拆分为以下模块：

### 5.1 SetupFeature

负责首次设置流程，包括：

- 定位权限说明与引导
- 公司位置选点
- 围栏半径调整（100m - 500m）
- 保存配置并进入主看板

### 5.2 TrackingEngine

负责系统定位与围栏能力的封装，包括：

- 注册和更新 `CLCircularRegion`
- 监听进入/离开事件
- 应用重启后的状态恢复
- 向上层暴露稳定的领域事件

### 5.3 PresenceRules

负责业务规则，不直接依赖 UI：

- 进入/离开需持续超过 10 分钟才算有效
- 凌晨 4 点前的离开归入前一天
- 生成“到岗 / 离岗 / 当日总时长”的最终判定

### 5.4 AttendanceStore

负责本地持久化：

- 公司位置配置
- 围栏原始事件
- 每日出勤汇总
- 节假日缓存

### 5.5 DashboardFeature

负责主看板展示：

- 月度圆点网格
- 今日状态高亮
- 单日详情浮层
- 月度统计摘要与进度线

### 5.6 HolidayService

负责：

- 拉取第三方法定节假日 / 调休日历
- 本地缓存和更新时间记录
- 向统计模块提供“应到工作日”计算基础

### 5.7 LiveActivityFeature

负责：

- 用户在公司期间启动或更新 Live Activity
- 当离开公司或记录失效时结束展示

### 5.8 PermissionState

负责统一表达权限状态，避免静默失败：

- 未授权
- 仅 While In Use
- Always 可用
- 系统限制或被关闭

## 6. 数据流

系统数据流建议如下：

1. 用户在 `SetupFeature` 完成公司坐标与半径设置。
2. `TrackingEngine` 基于配置注册地理围栏。
3. 系统触发进入/离开事件后，由 `TrackingEngine` 转换为领域事件。
4. `PresenceRules` 对事件应用 10 分钟去抖与跨天规则。
5. `AttendanceStore` 写入原始事件和最终日汇总。
6. `DashboardFeature` 只读取汇总结果与统计结果，不直接处理定位细节。
7. `LiveActivityFeature` 订阅“当前是否在公司”的状态并刷新锁屏展示。
8. `HolidayService` 提供工作日基线数据，供 Dashboard 计算 “XX Days Present out of XX Working Days”。

## 7. 数据模型建议

当前阶段只定义方向，不展开实现细节。建议至少包含以下实体：

- **WorkplaceConfig**
  - 公司坐标
  - 围栏半径
  - 是否已完成初始化

- **RegionEvent**
  - 事件类型（enter / exit）
  - 事件发生时间
  - 事件来源与有效性标记

- **AttendanceDay**
  - 日期
  - arrivedAt
  - leftAt
  - totalDuration
  - status（present / absent / pending）

- **HolidayCalendarCache**
  - 年月或年份
  - 工作日 / 节假日结果
  - 数据源更新时间

## 8. 关键约束与风险

### 8.1 Geofence 适合“无感记录”，不适合做严格监管

地理围栏并非秒级触发机制，系统会基于省电与定位策略调度。它适合本产品的“到/离公司自动记录”场景，但不应承诺监管级精度。

### 8.2 权限体验是核心成功因素

若无法获得合适的后台定位授权，产品价值会大幅下降。因此 Setup 页必须明确说明用途和收益，并把授权状态展示清楚。

### 8.3 规则正确性高于界面完成度

10 分钟去抖与凌晨 4 点跨天归并是业务正确性的核心，应集中在 `PresenceRules` 中，避免散落在回调或页面逻辑中。

### 8.4 节假日数据必须可追溯

第三方 API 异常时不能默默回退为错误统计。界面和存储层需要知道当前统计基于哪一版缓存数据。

### 8.5 Live Activities 只是展示层

锁屏信息只是当前状态的外显，不能作为考勤真相数据源。真正的业务记录仍以本地存储结果为准。

## 9. 平台范围

- **正式目标平台**：iPhone 上的原生 iOS App
- **建议最低系统版本**：`iOS 17+`
- **视觉适配重点**：面向 `iOS 18` 做深色 / 着色图标和系统视觉协调

不在当前范围内的内容：

- Android
- Web 管理后台
- 云端同步
- 多人组织管理

## 10. 推荐落地顺序

推荐按以下顺序推进实现：

1. **Setup + Geofence + 本地记录闭环**
2. **Dashboard + 月视图统计 + 单日详情浮层**
3. **HolidayService + Live Activities + 动效打磨**

这个顺序优先验证产品真核心：是否能稳定记录“到岗/离岗”，而不是先把展示层做复杂。

## 11. 最终决策

`Presence` 项目的正式技术选型为：

> **原生 iOS 单端，基于 SwiftUI + SwiftData + CoreLocation + MapKit + ActivityKit 构建，采用纯本地优先、轻量分层架构，`figma/` 原型仅作为视觉参考，不进入正式实现栈。**
