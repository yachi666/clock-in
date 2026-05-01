# Dashboard Calendar Visual Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the dashboard calendar so holiday badges no longer collide with the today outline, attended dates read as distinct at a glance, and the day detail popover has stronger visual hierarchy and contrast.

**Architecture:** Keep the existing dashboard structure intact. Add small pure presentation-semantics helpers to `DashboardCalendarLayout.swift` so the day cell changes remain testable, then apply the Quiet Halo styling in `DashboardView.swift` without changing month navigation, gesture handling, or attendance logic. Use the existing dashboard tests as the primary safety net and add focused unit coverage for the new day-cell semantics and updated popover sizing.

**Tech Stack:** Swift 6, SwiftUI, XCTest, Xcode project `Presence.xcodeproj`, app target `Presence`, test target `PresenceTests`.

---

## File Structure

- Modify: `Presence/Dashboard/DashboardCalendarLayout.swift`
  - Add pure visual-semantics helpers for holiday badge text/tone and day marker style.
  - Keep these helpers SwiftUI-free so they remain easy to unit test.
- Modify: `Presence/Dashboard/DashboardView.swift`
  - Update `FigmaDayCell` to render the Quiet Halo date treatment, inset today outline, and badge layering.
  - Update `DayTimePopover` surface, text hierarchy, and color contrast.
  - Update `DashboardView.popoverSize(for:)` if the stronger card spacing requires taller buckets.
- Modify: `PresenceTests/DashboardCalendarLayoutTests.swift`
  - Add failing tests for day-cell visual semantics.
  - Update popover size expectations if the refined card height changes.

## Worktree Safety

This repository already contains unrelated untracked files such as `figma/`, `requirement.md`, and `docs/superpowers/plans/2026-05-01-dashboard-popover-soft-glass.md`. Do not stage those files while executing this plan. Use `git add` with explicit paths only.

## Task 1: Add Pure Day-Cell Visual Semantics

**Files:**
- Modify: `Presence/Dashboard/DashboardCalendarLayout.swift`
- Test: `PresenceTests/DashboardCalendarLayoutTests.swift`

- [ ] **Step 1: Write the failing tests for Quiet Halo day semantics**

Add these tests after `testPopoverStatusLabelsHolidayFutureAndNoRecord()` in `PresenceTests/DashboardCalendarLayoutTests.swift`:

```swift
    func testDayVisualSemanticsMapsStatusToQuietHaloMarkers() {
        let presentDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .present,
            isCurrentMonth: true,
            attendance: AttendanceDay(
                dayIdentifier: "2026-05-01",
                arrivedAt: Date(timeIntervalSince1970: 1_777_555_200),
                leftAt: Date(timeIntervalSince1970: 1_777_589_400),
                totalDuration: 34_200,
                status: .present
            )
        )
        let incompleteDay = DashboardCalendarDay(
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
        let futureDay = DashboardCalendarDay(
            id: "2026-05-03",
            date: 3,
            identifier: "2026-05-03",
            status: .future,
            isCurrentMonth: true,
            attendance: nil
        )
        let emptyDay = DashboardCalendarDay(
            id: "2026-05-04",
            date: 4,
            identifier: "2026-05-04",
            status: .empty,
            isCurrentMonth: true,
            attendance: nil
        )

        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: presentDay), .presentSignal)
        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: incompleteDay), .incompleteRing)
        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: futureDay), .futureDot)
        XCTAssertEqual(DashboardDayVisualSemantics.marker(for: emptyDay), .none)

        XCTAssertTrue(DashboardDayVisualSemantics.emphasizesDate(for: presentDay))
        XCTAssertTrue(DashboardDayVisualSemantics.emphasizesDate(for: incompleteDay))
        XCTAssertFalse(DashboardDayVisualSemantics.emphasizesDate(for: futureDay))
        XCTAssertFalse(DashboardDayVisualSemantics.emphasizesDate(for: emptyDay))
    }

    func testDayVisualSemanticsReturnsHolidayBadgeTextAndTone() {
        let holidayDay = DashboardCalendarDay(
            id: "2026-05-01",
            date: 1,
            identifier: "2026-05-01",
            status: .empty,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-01", name: "劳动节", type: .publicHoliday),
            attendance: nil
        )
        let transferWorkday = DashboardCalendarDay(
            id: "2026-05-10",
            date: 10,
            identifier: "2026-05-10",
            status: .empty,
            isCurrentMonth: true,
            holiday: HolidayEntry(date: "2026-05-10", name: "补班", type: .transferWorkday),
            attendance: nil
        )
        let ordinaryDay = DashboardCalendarDay(
            id: "2026-05-12",
            date: 12,
            identifier: "2026-05-12",
            status: .empty,
            isCurrentMonth: true,
            attendance: nil
        )

        XCTAssertEqual(DashboardDayVisualSemantics.badge(for: holidayDay), .label(text: "休", tone: .holiday))
        XCTAssertEqual(DashboardDayVisualSemantics.badge(for: transferWorkday), .label(text: "班", tone: .transferWorkday))
        XCTAssertEqual(DashboardDayVisualSemantics.badge(for: ordinaryDay), .none)
    }
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:PresenceTests/DashboardCalendarLayoutTests
```

Expected: FAIL because `DashboardDayVisualSemantics`, `DashboardDayMarkerStyle`, and holiday badge tone types do not exist yet.

- [ ] **Step 3: Add the pure visual-semantics helpers**

Insert this code in `Presence/Dashboard/DashboardCalendarLayout.swift` after `DashboardPopoverStatus` and before `DashboardCalendarHitTester`:

```swift
enum DashboardDayMarkerStyle: Equatable {
    case none
    case futureDot
    case incompleteRing
    case presentSignal
}

enum DashboardHolidayBadgeTone: Equatable {
    case holiday
    case transferWorkday
}

enum DashboardHolidayBadgeStyle: Equatable {
    case none
    case label(text: String, tone: DashboardHolidayBadgeTone)
}

enum DashboardDayVisualSemantics {
    static func marker(for day: DashboardCalendarDay) -> DashboardDayMarkerStyle {
        switch day.status {
        case .present:
            return .presentSignal
        case .future:
            return .futureDot
        case .incomplete:
            return .incompleteRing
        case .empty:
            return .none
        }
    }

    static func badge(for day: DashboardCalendarDay) -> DashboardHolidayBadgeStyle {
        guard let holiday = day.holiday else { return .none }

        switch holiday.type {
        case .publicHoliday, .unknown:
            return .label(text: "休", tone: .holiday)
        case .transferWorkday:
            return .label(text: "班", tone: .transferWorkday)
        }
    }

    static func emphasizesDate(for day: DashboardCalendarDay) -> Bool {
        day.status == .present || day.status == .incomplete
    }
}
```

- [ ] **Step 4: Run the targeted test to verify it passes**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:PresenceTests/DashboardCalendarLayoutTests
```

Expected: PASS for the new day-semantics tests and the existing dashboard layout tests.

- [ ] **Step 5: Commit the pure semantics task**

Run:

```bash
git add Presence/Dashboard/DashboardCalendarLayout.swift PresenceTests/DashboardCalendarLayoutTests.swift
git commit -m "test: cover dashboard quiet halo semantics" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: a commit containing only the layout helper and test changes.

## Task 2: Implement Quiet Halo Calendar Cells and Popover Contrast

**Files:**
- Modify: `Presence/Dashboard/DashboardView.swift`
- Test: `PresenceTests/DashboardCalendarLayoutTests.swift`

- [ ] **Step 1: Update the popover size test first**

In `PresenceTests/DashboardCalendarLayoutTests.swift`, update `testPopoverSizeMatchesVisibleContentBuckets()` to expect the taller refined card:

```swift
        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: attendance, holiday: holiday)),
            CGSize(width: 224, height: 172)
        )
        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: attendance, holiday: nil)),
            CGSize(width: 224, height: 152)
        )
        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: nil, holiday: holiday)),
            CGSize(width: 224, height: 124)
        )
        XCTAssertEqual(
            DashboardView.popoverSize(for: popoverDay(attendance: nil, holiday: nil)),
            CGSize(width: 224, height: 104)
        )
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:PresenceTests/DashboardCalendarLayoutTests/testPopoverSizeMatchesVisibleContentBuckets
```

Expected: FAIL because `DashboardView.popoverSize(for:)` still returns the old heights.

- [ ] **Step 3: Update the popover size buckets**

Replace `DashboardView.popoverSize(for:)` in `Presence/Dashboard/DashboardView.swift` with:

```swift
    static func popoverSize(for day: DashboardCalendarDay) -> CGSize {
        switch (day.attendance != nil, day.holiday != nil) {
        case (true, true):
            return CGSize(width: 224, height: 172)
        case (true, false):
            return CGSize(width: 224, height: 152)
        case (false, true):
            return CGSize(width: 224, height: 124)
        case (false, false):
            return CGSize(width: 224, height: 104)
        }
    }
```

- [ ] **Step 4: Replace the day-cell rendering with Quiet Halo styling**

In `Presence/Dashboard/DashboardView.swift`, replace the `FigmaDayCell` body and helper properties with:

```swift
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                dateLabel
                holidayBadge
                    .offset(x: 9, y: -6)
            }
            .frame(width: 34, height: 24)

            marker
                .frame(width: 14, height: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .contentShape(Rectangle())
    }

    private var dateLabel: some View {
        Text("\\(day.date)")
            .font(.system(size: 14, weight: dateWeight))
            .foregroundStyle(dateColor)
            .frame(width: 32, height: 22)
            .background(dateBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .inset(by: 1)
                        .stroke(Color.figmaTodayStroke, lineWidth: 1)
                }
            }
    }

    @ViewBuilder
    private var dateBackground: some ShapeStyle {
        if day.status == .present {
            LinearGradient(
                colors: [Color.figmaPresentWash.opacity(0.22), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var marker: some View {
        switch DashboardDayVisualSemantics.marker(for: day) {
        case .presentSignal:
            Capsule()
                .fill(isSelected ? Color.figmaPresentSignal : Color.figmaPresentSignal.opacity(0.78))
                .frame(width: isSelected ? 14 : 12, height: 4)
        case .futureDot:
            Circle()
                .fill(Color.figmaFutureDot)
                .frame(width: 4, height: 4)
        case .incompleteRing:
            Circle()
                .stroke(Color.figmaIncompleteDot, lineWidth: 1)
                .frame(width: 7, height: 7)
        case .none:
            Color.clear
        }
    }

    private var dateWeight: Font.Weight {
        DashboardDayVisualSemantics.emphasizesDate(for: day) ? .semibold : .regular
    }

    private var dateColor: Color {
        if !day.isCurrentMonth {
            return Color.figmaOutOfMonthText
        }

        switch day.status {
        case .present:
            return Color.figmaProgress
        case .incomplete:
            return .black
        case .future:
            return Color.figmaMutedText
        case .empty:
            return Color.figmaSecondaryText
        }
    }

    @ViewBuilder
    private var holidayBadge: some View {
        switch DashboardDayVisualSemantics.badge(for: day) {
        case .none:
            EmptyView()
        case let .label(text, tone):
            Text(text)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(tone == .holiday ? Color.figmaHolidayBadgeText : Color.figmaTransferBadgeText)
                .padding(.horizontal, 4)
                .frame(height: 16)
                .background(
                    tone == .holiday ? Color.figmaHolidayBadgeFill : Color.figmaTransferBadgeFill,
                    in: Capsule()
                )
        }
    }
```

- [ ] **Step 5: Strengthen the popover surface and text hierarchy**

In `Presence/Dashboard/DashboardView.swift`, update `DayTimePopover.body`, `timeRow(_:, value:)`, and add the new color tokens:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            statusPill

            VStack(alignment: .leading, spacing: 7) {
                Text(displayDate)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.figmaPopoverPrimaryText)

                if let holiday = day.holiday {
                    Text(holidayText(holiday))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(holiday.type == .transferWorkday ? Color.figmaTransferBadgeText : Color.figmaHolidayText)
                        .lineLimit(1)
                }
            }

            if let attendance = day.attendance {
                VStack(spacing: 8) {
                    timeRow("Arrived", value: formatted(attendance.arrivedAt))
                    timeRow("Left", value: formatted(attendance.leftAt))
                }
                .padding(.top, 2)
            } else {
                Text(DashboardPopoverStatus.status(for: day).label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.figmaPopoverSecondaryText)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 28, y: 14)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .allowsHitTesting(false)
    }

    private func timeRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.figmaPopoverSecondaryText)
            Spacer(minLength: 20)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(value == "--:--" ? Color.figmaMutedText : Color.figmaPopoverPrimaryText)
        }
        .font(.system(size: 13, weight: .regular))
    }
```

Add these colors in the existing `private extension Color`:

```swift
    static let figmaTodayStroke = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255).opacity(0.24)
    static let figmaPresentWash = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
    static let figmaPresentSignal = Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255)
    static let figmaHolidayBadgeFill = Color(red: 254 / 255, green: 226 / 255, blue: 226 / 255)
    static let figmaHolidayBadgeText = Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
    static let figmaTransferBadgeFill = Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255)
    static let figmaTransferBadgeText = Color(red: 71 / 255, green: 85 / 255, blue: 105 / 255)
    static let figmaPopoverPrimaryText = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let figmaPopoverSecondaryText = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
```

- [ ] **Step 6: Run the targeted dashboard tests**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:PresenceTests/DashboardCalendarLayoutTests
```

Expected: PASS with the new Quiet Halo helper tests and updated popover size expectations.

- [ ] **Step 7: Commit the dashboard UI refinement**

Run:

```bash
git add Presence/Dashboard/DashboardView.swift PresenceTests/DashboardCalendarLayoutTests.swift
git commit -m "feat: refine dashboard calendar visuals" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: a commit containing only the dashboard view styling and test expectation updates.

## Task 3: Final Verification

**Files:**
- No source changes expected.

- [ ] **Step 1: Run the full test suite**

Run:

```bash
xcodebuild test -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Expected: all `PresenceTests` pass.

- [ ] **Step 2: Build the app target for the simulator**

Run:

```bash
xcodebuild -project Presence.xcodeproj -scheme Presence -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO build
```

Expected: build succeeds with no SwiftUI compile errors.

- [ ] **Step 3: Inspect the final diff before handoff**

Run:

```bash
git --no-pager diff --stat -- Presence/Dashboard/DashboardCalendarLayout.swift Presence/Dashboard/DashboardView.swift PresenceTests/DashboardCalendarLayoutTests.swift
git --no-pager status --short
```

Expected: only the dashboard layout helper, dashboard view styling, and dashboard tests appear as implementation changes; unrelated untracked files remain unstaged.
