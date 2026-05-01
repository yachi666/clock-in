# Dashboard Popover Soft Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dashboard date popover with the selected Soft Glass micro-card while preserving current date press/drag, haptic, holiday, and attendance behavior.

**Architecture:** Keep positioning and gesture behavior unchanged. Add a small pure helper for popover status semantics in `DashboardCalendarLayout.swift`, then consume it from `DayTimePopover` in `DashboardView.swift` for a glass-style card with a status pill and compact hierarchy.

**Tech Stack:** Swift 6, SwiftUI, XCTest, existing iOS app target and `PresenceTests` test target.

---

## File Structure

- Modify `Presence/Dashboard/DashboardCalendarLayout.swift`
  - Add `DashboardPopoverStatus`, a pure `Equatable` value describing the popover status label and semantic kind.
  - Responsibility: derive status text from `DashboardCalendarDay` without depending on SwiftUI colors or view rendering.
- Modify `Presence/Dashboard/DashboardView.swift`
  - Update `DayTimePopover` to render the Soft Glass card.
  - Add local view helpers for status pill, date/holiday hierarchy, and card styling.
  - Adjust `DashboardView.popoverSize` only if the card height changes.
- Modify `PresenceTests/DashboardCalendarLayoutTests.swift`
  - Add tests for the new `DashboardPopoverStatus` helper.
  - Keep existing positioning, holiday, and gesture tests intact.

## Worktree Safety

This repository currently has uncommitted baseline changes from earlier dashboard, setup, attendance, and holiday work. Do not run commit commands that stage entire files unless the worktree has first been made clean. Each task includes a checkpoint step with safe status commands; only use the commit command shown there when executing in a clean dedicated worktree.

## Task 1: Add Popover Status Semantics

**Files:**
- Modify: `Presence/Dashboard/DashboardCalendarLayout.swift`
- Test: `PresenceTests/DashboardCalendarLayoutTests.swift`

- [ ] **Step 1: Write failing tests for status derivation**

Add these tests before the existing private `date(...)` helper in `PresenceTests/DashboardCalendarLayoutTests.swift`:

```swift
    func testPopoverStatusLabelsAttendanceStatesBeforeHoliday() {
        let presentDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .present,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday),
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-01",
                arrivedAt: Date(timeIntervalSince1970: 1_777_555_200),
                leftAt: Date(timeIntervalSince1970: 1_777_589_400),
                totalDuration: 34_200,
                status: .present
            )
        )

        let pendingDay = DashboardCalendarDay(
            id: "2026-05-02",
            date: 2,
            identifier: "2026-05-02",
            status: .incomplete,
            isCurrentMonth: true,
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-02",
                arrivedAt: Date(timeIntervalSince1970: 1_777_641_600),
                leftAt: nil,
                totalDuration: 0,
                status: .pending
            )
        )

        XCTAssertEqual(DashboardPopoverStatus.status(for: presentDay), .present)
        XCTAssertEqual(DashboardPopoverStatus.status(for: pendingDay), .pending)
    }

    func testPopoverStatusLabelsHolidayFutureAndNoRecord() {
        let holidayDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .empty,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday),
            attendance: nil
        )
        let futureDay = DashboardCalendarDay(
            id: "2026-05-20",
            date: 20,
            identifier: "2026-05-20",
            status: .future,
            isCurrentMonth: true,
            attendance: nil
        )
        let emptyDay = DashboardCalendarDay(
            id: "2026-05-10",
            date: 10,
            identifier: "2026-05-10",
            status: .empty,
            isCurrentMonth: true,
            attendance: nil
        )

        XCTAssertEqual(DashboardPopoverStatus.status(for: holidayDay), .holiday)
        XCTAssertEqual(DashboardPopoverStatus.status(for: futureDay), .future)
        XCTAssertEqual(DashboardPopoverStatus.status(for: emptyDay), .noRecord)
    }
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:PresenceTests/DashboardCalendarLayoutTests
```

Expected: FAIL because `DashboardPopoverStatus` is not defined.

- [ ] **Step 3: Add the pure status helper**

Add this enum after `DashboardGestureHint` and before `DashboardCalendarHitTester` in `Presence/Dashboard/DashboardCalendarLayout.swift`:

```swift
enum DashboardPopoverStatus: Equatable {
    case present
    case pending
    case holiday
    case future
    case noRecord

    var label: String {
        switch self {
        case .present:
            return "Present"
        case .pending:
            return "Pending"
        case .holiday:
            return "Holiday"
        case .future:
            return "Future"
        case .noRecord:
            return "No record"
        }
    }

    static func status(for day: DashboardCalendarDay) -> DashboardPopoverStatus {
        if let attendance = day.attendance {
            switch attendance.status {
            case .present:
                return .present
            case .pending, .absent:
                return .pending
            }
        }

        if day.holiday?.type == .publicHoliday {
            return .holiday
        }

        if day.status == .future {
            return .future
        }

        return .noRecord
    }
}
```

- [ ] **Step 4: Run the targeted test to verify it passes**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:PresenceTests/DashboardCalendarLayoutTests
```

Expected: PASS for `DashboardCalendarLayoutTests`.

- [ ] **Step 5: Record Task 1 checkpoint**

Run:

```bash
git --no-pager status --short Presence/Dashboard/DashboardCalendarLayout.swift PresenceTests/DashboardCalendarLayoutTests.swift
```

Expected in this repo: these files may show existing modified or untracked state from earlier work. Do not commit if that would include unrelated baseline changes.

If executing in a clean dedicated worktree, commit the task with:

```bash
git add Presence/Dashboard/DashboardCalendarLayout.swift PresenceTests/DashboardCalendarLayoutTests.swift
git commit -m "test: cover dashboard popover status" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 2: Implement the Soft Glass Popover UI

**Files:**
- Modify: `Presence/Dashboard/DashboardView.swift`

- [ ] **Step 1: Update popover dimensions and transition**

In `Presence/Dashboard/DashboardView.swift`, update the popover frame and transition in `DashboardView.body`:

```swift
                    DayTimePopover(day: selectedDay)
                        .frame(width: Self.popoverSize.width, alignment: .leading)
                        .position(
                            DashboardPopoverPositioner.position(
                                anchoredTo: anchorFrame,
                                popoverSize: Self.popoverSize,
                                containerSize: rootProxy.size
                            )
                        )
                        .transition(
                            .opacity
                                .combined(with: .scale(scale: 0.94, anchor: .center))
                        )
                        .zIndex(2)
```

Then update the static size near the bottom of `DashboardView`:

```swift
    private static let popoverSize = CGSize(width: 224, height: 132)
```

- [ ] **Step 2: Replace `DayTimePopover.body` with the Soft Glass hierarchy**

Replace the current `body` property inside `private struct DayTimePopover` with:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusPill

            VStack(alignment: .leading, spacing: 6) {
                Text(displayDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black)

                if let holiday = day.holiday {
                    Text(holidayText(holiday))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(holiday.type == .transferWorkday ? Color.figmaSecondaryText : Color.figmaHolidayText)
                        .lineLimit(1)
                }
            }

            if let attendance = day.attendance {
                VStack(spacing: 7) {
                    timeRow("Arrived", value: formatted(attendance.arrivedAt))
                    timeRow("Left", value: formatted(attendance.leftAt))
                }
                .padding(.top, 2)
            } else {
                Text(DashboardPopoverStatus.status(for: day).label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.figmaSecondaryText)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minWidth: 224, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        .allowsHitTesting(false)
    }
```

- [ ] **Step 3: Add the status pill view and styling helpers**

Inside `DayTimePopover`, add this computed property after `body`:

```swift
    private var statusPill: some View {
        let status = DashboardPopoverStatus.status(for: day)
        return HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 5, height: 5)
            Text(status.label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.background, in: Capsule())
    }
```

Then add this extension after `DayTimePopover` and before the existing `private extension Color`:

```swift
private extension DashboardPopoverStatus {
    var tint: Color {
        switch self {
        case .present:
            return Color.figmaIndigo
        case .pending:
            return Color.figmaIncompleteDot
        case .holiday:
            return Color.figmaHolidayText
        case .future:
            return Color.figmaMutedText
        case .noRecord:
            return Color.figmaSecondaryText
        }
    }

    var background: Color {
        switch self {
        case .present:
            return Color.figmaIndigo.opacity(0.12)
        case .pending:
            return Color.figmaIncompleteDot.opacity(0.13)
        case .holiday:
            return Color.figmaHolidayText.opacity(0.10)
        case .future:
            return Color.figmaFutureDot.opacity(0.70)
        case .noRecord:
            return Color.figmaRule.opacity(0.95)
        }
    }
}
```

- [ ] **Step 4: Tighten row typography**

Replace `timeRow(_:, value:)` inside `DayTimePopover` with:

```swift
    private func timeRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.figmaMutedText)
            Spacer(minLength: 20)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(value == "--:--" ? Color.figmaMutedText : .black)
        }
        .font(.system(size: 13, weight: .regular))
    }
```

- [ ] **Step 5: Run the targeted dashboard tests**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:PresenceTests/DashboardCalendarLayoutTests
```

Expected: PASS for `DashboardCalendarLayoutTests`.

- [ ] **Step 6: Record Task 2 checkpoint**

Run:

```bash
git --no-pager status --short Presence/Dashboard/DashboardView.swift
```

Expected in this repo: the file may show existing modified state from earlier dashboard work. Do not commit if that would include unrelated baseline changes.

If executing in a clean dedicated worktree, commit the task with:

```bash
git add Presence/Dashboard/DashboardView.swift
git commit -m "feat: add soft glass dashboard popover" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 3: Final Verification

**Files:**
- No source changes expected.

- [ ] **Step 1: Run the full simulator test suite**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass.

- [ ] **Step 2: Build for the connected iPhone**

Run:

```bash
xcodebuild -project Presence.xcodeproj -scheme Presence -destination 'id=00008150-000528912278401C' -allowProvisioningUpdates build
```

Expected: build succeeds for the connected device.

- [ ] **Step 3: Install and launch on the connected iPhone**

Run:

```bash
app_path="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Debug-iphoneos/Presence.app' -type d ! -path '*/Index.noindex/*' -print | head -1)"
xcrun devicectl device install app --device 00008150-000528912278401C "$app_path"
xcrun devicectl device process launch --device 00008150-000528912278401C com.lzn.clockin.presence
```

Expected: install succeeds and the app launches. A non-fatal `Failed to load provisioning paramter list` message from `devicectl` can be ignored if install and launch succeed.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git --no-pager diff --stat -- Presence/Dashboard/DashboardCalendarLayout.swift Presence/Dashboard/DashboardView.swift PresenceTests/DashboardCalendarLayoutTests.swift
git --no-pager status --short
```

Expected: status may still show unrelated pre-existing uncommitted changes. The dashboard diff should include only popover status tests/helper and `DayTimePopover` visual changes.
