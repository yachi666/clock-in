import SwiftData
import SwiftUI

/// Loads dashboard data and renders DashboardView with live store/holiday data.
@MainActor
struct DashboardLoader: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var loadResult: DashboardLoadResult?
    @State private var selectedMonthIdentifier = DashboardLoader.currentMonthIdentifier()

    private let holidayService = HolidayService()

    var body: some View {
        Group {
            if let result = loadResult {
                switch result {
                case .loaded(let summary, let days, let holidayCalendar):
                    dashboardView(summary: summary, attendanceDays: days, holidayCalendar: holidayCalendar)
                case .holidayUnavailable(let presentDays, let days, let monthIdentifier):
                    dashboardView(
                        summary: .unavailable(monthIdentifier: monthIdentifier, presentDays: presentDays),
                        attendanceDays: days,
                        workingDaysUnavailable: true
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: selectedMonthIdentifier) { await reload(monthIdentifier: selectedMonthIdentifier) }
    }

    private func reload(monthIdentifier: String) async {
        let coordinator = DashboardLoadCoordinator(
            store: AttendanceStore(context: modelContext),
            holidayService: holidayService,
            context: modelContext
        )
        let result = await coordinator.load(monthIdentifier: monthIdentifier)
        guard !Task.isCancelled else { return }
        loadResult = result
    }

    private func dashboardView(
        summary: MonthlySummary,
        attendanceDays: [AttendanceDay],
        holidayCalendar: HolidayCalendar? = nil,
        workingDaysUnavailable: Bool = false
    ) -> some View {
        DashboardView(
            summary: summary,
            attendanceDays: attendanceDays,
            holidayCalendar: holidayCalendar,
            workingDaysUnavailable: workingDaysUnavailable,
            onPreviousMonth: {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedMonthIdentifier = DashboardMonthNavigator.previousMonth(from: selectedMonthIdentifier)
                }
            },
            onNextMonth: {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedMonthIdentifier = DashboardMonthNavigator.nextMonth(from: selectedMonthIdentifier)
                }
            },
            onSetupTapped: {
                appState.reopenSetup()
            }
        )
    }

    private static func currentMonthIdentifier(calendar: Calendar = .gregorianCN, now: Date = Date()) -> String {
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return String(format: "%04d-%02d", year, month)
    }
}
