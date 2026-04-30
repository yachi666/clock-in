import SwiftData
import SwiftUI

/// Loads dashboard data and renders DashboardView with live store/holiday data.
@MainActor
struct DashboardLoader: View {
    @Environment(\.modelContext) private var modelContext

    @State private var loadResult: DashboardLoadResult?

    private let holidayService = HolidayService()

    var body: some View {
        Group {
            if let result = loadResult {
                switch result {
                case .loaded(let summary, let days):
                    DashboardView(summary: summary, attendanceDays: days)
                case .holidayUnavailable(let presentDays, let days, let monthIdentifier):
                    DashboardView(
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
        .task { await reload() }
    }

    private func reload() async {
        let calendar = Calendar.gregorianCN
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let monthIdentifier = String(format: "%04d-%02d", year, month)

        let coordinator = DashboardLoadCoordinator(
            store: AttendanceStore(context: modelContext),
            holidayService: holidayService,
            context: modelContext
        )
        loadResult = await coordinator.load(monthIdentifier: monthIdentifier)
    }
}
