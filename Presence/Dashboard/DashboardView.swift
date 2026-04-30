import SwiftUI

struct DashboardView: View {
    let summary: MonthlySummary
    let attendanceDays: [AttendanceDay]

    @State private var selectedDay: AttendanceDay? = nil

    private var attendanceMap: [String: AttendanceDay] {
        Dictionary(uniqueKeysWithValues: attendanceDays.map { ($0.dayIdentifier, $0) })
    }

    private var progress: Double {
        guard summary.workingDays > 0 else { return 0 }
        return Double(summary.presentDays) / Double(summary.workingDays)
    }

    private var monthTitle: String {
        let parts = summary.monthIdentifier.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
            return summary.monthIdentifier
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let calendar = Calendar.gregorianCN
        guard let date = calendar.date(from: components) else { return summary.monthIdentifier }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private var calendarDays: [CalendarDay] {
        let parts = summary.monthIdentifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1])
        else { return [] }

        var firstComponents = DateComponents()
        firstComponents.year = year
        firstComponents.month = month
        firstComponents.day = 1
        let cal = Calendar.gregorianCN
        guard let firstDay = cal.date(from: firstComponents),
              let dayRange = cal.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        // weekday of first day (1=Sun ... 7=Sat), convert to Mon-origin (0=Mon)
        let rawWeekday = cal.component(.weekday, from: firstDay)
        let leadingBlanks = (rawWeekday + 5) % 7

        var days: [CalendarDay] = Array(repeating: .blank, count: leadingBlanks)
        for day in dayRange {
            let identifier = String(format: "%04d-%02d-%02d", year, month, day)
            let attendance = attendanceMap[identifier]
            days.append(CalendarDay(dayNumber: day, identifier: identifier, attendance: attendance))
        }
        return days
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    monthGridSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if let day = selectedDay {
                    DayDetailOverlay(day: day) {
                        selectedDay = nil
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Present Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.presentDays)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Working Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(summary.workingDays)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(.green)
                .scaleEffect(x: 1, y: 2, anchor: .center)

            Text("\(Int(progress * 100))% attendance rate")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var monthGridSection: some View {
        VStack(spacing: 8) {
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                    DayCell(day: day)
                        .onTapGesture {
                            if let attendance = day.attendance {
                                selectedDay = attendance
                            }
                        }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Supporting Types

struct CalendarDay {
    let dayNumber: Int?
    let identifier: String?
    let attendance: AttendanceDay?

    static let blank = CalendarDay(dayNumber: nil, identifier: nil, attendance: nil)

    init(dayNumber: Int? = nil, identifier: String? = nil, attendance: AttendanceDay? = nil) {
        self.dayNumber = dayNumber
        self.identifier = identifier
        self.attendance = attendance
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let day: CalendarDay

    var body: some View {
        Group {
            if let number = day.dayNumber {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 36, height: 36)
                    Text("\(number)")
                        .font(.system(.footnote, design: .rounded))
                        .fontWeight(fontWeight)
                        .foregroundStyle(foregroundColor)
                }
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        switch day.attendance?.status {
        case .present: return .green.opacity(0.8)
        case .absent:  return .red.opacity(0.15)
        case .pending: return .orange.opacity(0.3)
        case nil:      return .clear
        }
    }

    private var foregroundColor: Color {
        day.attendance?.status == .present ? .white : .primary
    }

    private var fontWeight: Font.Weight {
        day.attendance != nil ? .semibold : .regular
    }
}

// MARK: - Day Detail Overlay

private struct DayDetailOverlay: View {
    let day: AttendanceDay
    let onDismiss: () -> Void

    private var durationString: String {
        guard day.totalDuration > 0 else { return "—" }
        let hours = Int(day.totalDuration) / 3600
        let minutes = (Int(day.totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 16) {
                HStack {
                    Text(day.dayIdentifier)
                        .font(.headline)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                detailRow("Status", value: day.status.rawValue.capitalized)

                if let arrived = day.arrivedAt {
                    detailRow("Arrived", value: Self.timeFormatter.string(from: arrived))
                }
                if let left = day.leftAt {
                    detailRow("Left", value: Self.timeFormatter.string(from: left))
                }
                detailRow("Duration", value: durationString)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Sample Data

private let sampleAttendanceDays: [AttendanceDay] = (1...15).map { day in
    AttendanceDay(
        dayIdentifier: String(format: "2026-04-%02d", day),
        arrivedAt: Date(timeIntervalSince1970: 1_743_462_000 + Double(day - 1) * 86400),
        leftAt:    Date(timeIntervalSince1970: 1_743_462_000 + Double(day - 1) * 86400 + 32400),
        totalDuration: 32400,
        status: .present
    )
}

extension MonthlySummary {
    static let sample: MonthlySummary = {
        let hc = HolidayCalendar(year: 2026, region: "CN", entries: [])
        // swiftlint:disable:next force_try
        return try! MonthlySummary(  // safe: known-valid inputs used only for preview
            monthIdentifier: "2026-04",
            attendanceDays: sampleAttendanceDays,
            holidayCalendar: hc
        )
    }()
}

// MARK: - Previews

#Preview {
    DashboardView(summary: .sample, attendanceDays: sampleAttendanceDays)
}
