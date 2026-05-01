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
- `Shared/` — shared Swift code and resources used across multiple targets

## 🤝 Contributing

Issues, discussions, and thoughtful feedback are welcome while the project is taking shape. Pull requests are also welcome once a piece of work has a clear direction and scope.

## 📄 License

License information has not been added to the repository yet.
