import SwiftUI
import UIKit

struct DashboardView: View {
    let summary: MonthlySummary
    let attendanceDays: [AttendanceDay]
    var holidayCalendar: HolidayCalendar?
    var workingDaysUnavailable: Bool = false
    var onPreviousMonth: (() -> Void)?
    var onNextMonth: (() -> Void)?
    var onCurrentMonth: (() -> Void)?
    var onSetupTapped: (() -> Void)?

    @State private var selectedDay: DashboardCalendarDay?
    @State private var selectedDayFrame: CGRect?
    @State private var dayGridFrame: CGRect = .zero
    @State private var isSelectingDay = false
    @AppStorage("dashboardGestureHintSeen") private var hasSeenGestureHint = false

    private var calendarDays: [DashboardCalendarDay] {
        DashboardCalendarLayout.build(
            monthIdentifier: summary.monthIdentifier,
            attendanceDays: attendanceDays,
            holidayCalendar: holidayCalendar
        )
    }

    private var progress: Double {
        guard !workingDaysUnavailable, summary.workingDays > 0 else { return 0 }
        return min(1, Double(summary.presentDays) / Double(summary.workingDays))
    }

    private var monthParts: (month: String, year: String) {
        DashboardMonthTitleParts.parts(from: summary.monthIdentifier)
    }

    var body: some View {
        GeometryReader { rootProxy in
            ZStack(alignment: .top) {
                Color.white
                    .ignoresSafeArea()
                    .onTapGesture { clearSelectedDay() }

                VStack(spacing: 0) {
                    header
                    calendarGrid
                    if DashboardGestureHint.shouldShow(hasSeenHint: hasSeenGestureHint) {
                        gestureHint
                            .padding(.top, 22)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    Spacer(minLength: 24)
                    footer
                }
                .padding(.horizontal, 32)
                .padding(.top, 56)
                .padding(.bottom, 48)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)

                if let selectedDay,
                   selectedDay.isCurrentMonth,
                   let selectedDayFrame {
                    let anchorFrame = selectedDayFrame.offsetBy(dx: dayGridFrame.minX, dy: dayGridFrame.minY)
                    let popoverSize = Self.popoverSize(for: selectedDay)
                    DayTimePopover(day: selectedDay)
                        .frame(width: popoverSize.width, height: popoverSize.height, alignment: .leading)
                        .position(
                            DashboardPopoverPositioner.position(
                                anchoredTo: anchorFrame,
                                popoverSize: popoverSize,
                                containerSize: rootProxy.size
                            )
                        )
                        .transition(
                            .opacity
                                .combined(with: .scale(scale: 0.94, anchor: .center))
                        )
                        .zIndex(2)
                }

                Button {
                    onSetupTapped?()
                } label: {
                    Text("Setup")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.figmaMutedText)
                }
                .buttonStyle(.plain)
                .padding(.top, 32)
                .padding(.trailing, 32)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
            .coordinateSpace(name: Self.dashboardCoordinateSpace)
        }
        .fontDesign(.default)
        .simultaneousGesture(monthSwipeGesture)
        .simultaneousGesture(returnToCurrentMonthGesture)
        .onPreferenceChange(DashboardDayGridFramePreferenceKey.self) { dayGridFrame = $0 }
        .animation(.easeOut(duration: 0.2), value: selectedDay?.id)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthParts.month)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.black)
            Text(monthParts.year)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.figmaMutedText)
        }
        .padding(.bottom, 48)
    }

    private var calendarGrid: some View {
        VStack(spacing: 28) {
            HStack(spacing: 8) {
                ForEach(Array(Self.weekdayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.figmaMutedText)
                        .frame(maxWidth: .infinity)
                }
            }

            GeometryReader { proxy in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 28) {
                    ForEach(calendarDays, id: \.id) { day in
                        FigmaDayCell(day: day, isSelected: selectedDay?.id == day.id)
                    }
                }
                .contentShape(Rectangle())
                .gesture(daySelectionGesture(in: proxy.size))
                .background {
                    GeometryReader { gridProxy in
                        Color.clear.preference(
                            key: DashboardDayGridFramePreferenceKey.self,
                            value: gridProxy.frame(in: .named(Self.dashboardCoordinateSpace))
                        )
                    }
                }
            }
            .frame(height: dayGridHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private var gestureHint: some View {
        Text(DashboardGestureHint.text)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Color.figmaSecondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.figmaPopover, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.figmaBorder, lineWidth: 1)
            }
    }

    private var dayGridHeight: CGFloat {
        let rowHeight: CGFloat = 34
        let rowSpacing: CGFloat = 28
        let rows = max(1, Int(ceil(Double(calendarDays.count) / 7.0)))
        return CGFloat(rows) * rowHeight + CGFloat(rows - 1) * rowSpacing
    }

    private func daySelectionGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isSelectingDay = true
                selectDay(at: value.location, in: size)
            }
            .onEnded { _ in
                clearSelectedDay()
                DispatchQueue.main.async {
                    isSelectingDay = false
                }
            }
    }

    private func selectDay(at point: CGPoint, in size: CGSize) {
        guard let day = DashboardCalendarHitTester.day(at: point, in: size, days: calendarDays),
              day.isCurrentMonth,
              let dayFrame = DashboardCalendarHitTester.frame(for: day.id, in: size, days: calendarDays)
        else { return }

        guard selectedDay?.id != day.id else { return }
        markGestureHintSeen()
        if selectedDay != nil {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        selectedDay = day
        selectedDayFrame = dayFrame
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard !isSelectingDay,
                      let change = DashboardMonthSwipeResolver.change(for: value.translation)
                else { return }

                clearSelectedDay()
                markGestureHintSeen()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                switch change {
                case .previous:
                    onPreviousMonth?()
                case .next:
                    onNextMonth?()
                }
            }
    }

    private var returnToCurrentMonthGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.55)
            .onEnded { _ in
                clearSelectedDay()
                markGestureHintSeen()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onCurrentMonth?()
            }
    }

    private func clearSelectedDay() {
        selectedDay = nil
        selectedDayFrame = nil
    }

    private func markGestureHintSeen() {
        if !hasSeenGestureHint {
            hasSeenGestureHint = true
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(summary.presentDays)")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.black)
                Text("days present")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.figmaSecondaryText)
            }

            Text(workingDaysUnavailable ? "Working day data unavailable" : "Out of \(summary.workingDays) working days this month")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.figmaMutedText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.figmaRule)
                    Rectangle()
                        .fill(Color.figmaProgress)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 1)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private static let dashboardCoordinateSpace = "DashboardCoordinateSpace"

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
}

private struct DashboardDayGridFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct FigmaDayCell: View {
    let day: DashboardCalendarDay
    let isSelected: Bool

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
        Text("\(day.date)")
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

    private var dateBackground: AnyShapeStyle {
        if day.status == .present {
            AnyShapeStyle(
                LinearGradient(
                    colors: [Color.figmaPresentWash.opacity(0.22), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        } else {
            AnyShapeStyle(Color.clear)
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
}

private struct DayTimePopover: View {
    let day: DashboardCalendarDay

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.shortMonthSymbols
    }()

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

    private var displayDate: String {
        guard let identifier = day.identifier else { return "\(day.date)" }
        let parts = identifier.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              (1...Self.shortMonthSymbols.count).contains(month)
        else { return identifier }
        return "\(Self.shortMonthSymbols[month - 1]) \(day.date)"
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

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return Self.timeFormatter.string(from: date)
    }

    private func holidayText(_ holiday: HolidayEntry) -> String {
        switch holiday.type {
        case .publicHoliday:
            return "\(holiday.name) · Holiday"
        case .transferWorkday:
            return "\(holiday.name) · Workday"
        case .unknown:
            return holiday.name
        }
    }
}

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

private extension Color {
    static let figmaIndigo = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
    static let figmaMutedText = Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255)
    static let figmaSecondaryText = Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255)
    static let figmaOutOfMonthText = Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255)
    static let figmaFutureDot = Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255)
    static let figmaIncompleteDot = Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255)
    static let figmaRule = Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255)
    static let figmaProgress = Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255)
    static let figmaPopover = Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255)
    static let figmaBorder = Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255)
    static let figmaHolidayText = Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)
    static let figmaTodayStroke = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255).opacity(0.24)
    static let figmaPresentWash = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
    static let figmaPresentSignal = Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255)
    static let figmaHolidayBadgeFill = Color(red: 254 / 255, green: 226 / 255, blue: 226 / 255)
    static let figmaHolidayBadgeText = Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
    static let figmaTransferBadgeFill = Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255)
    static let figmaTransferBadgeText = Color(red: 71 / 255, green: 85 / 255, blue: 105 / 255)
    static let figmaPopoverPrimaryText = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let figmaPopoverSecondaryText = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
}

// Placeholder initializer for display fixtures and unavailable holiday state.
extension MonthlySummary {
    init(placeholder monthIdentifier: String, presentDays: Int, workingDays: Int) {
        self.monthIdentifier = monthIdentifier
        self.presentDays = presentDays
        self.workingDays = workingDays
    }

    static func unavailable(monthIdentifier: String, presentDays: Int) -> MonthlySummary {
        MonthlySummary(placeholder: monthIdentifier, presentDays: presentDays, workingDays: 0)
    }
}

extension MonthlySummary {
    static let sample = MonthlySummary(placeholder: "2026-04", presentDays: 15, workingDays: 22)
}

private let sampleAttendanceDays: [AttendanceDay] = (1...15).map { day in
    AttendanceDay(
        dayIdentifier: String(format: "2026-04-%02d", day),
        arrivedAt: Date(timeIntervalSince1970: 1_743_462_000 + Double(day - 1) * 86_400),
        leftAt: Date(timeIntervalSince1970: 1_743_462_000 + Double(day - 1) * 86_400 + 32_400),
        totalDuration: 32_400,
        status: .present
    )
}

#Preview {
    DashboardView(summary: .sample, attendanceDays: sampleAttendanceDays)
}
