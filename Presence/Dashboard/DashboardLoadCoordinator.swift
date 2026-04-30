import Foundation
import SwiftData

// MARK: - Load Result

enum DashboardLoadResult {
    case loaded(summary: MonthlySummary, days: [AttendanceDay])
    case holidayUnavailable(presentDays: Int, days: [AttendanceDay], monthIdentifier: String)
}

// MARK: - Coordinator

/// Pure loading logic for the Dashboard; extracted for testability.
@MainActor
struct DashboardLoadCoordinator {
    let store: AttendanceStore
    let holidayService: HolidayService
    let context: ModelContext

    func load(monthIdentifier: String) async -> DashboardLoadResult {
        let calendar = Calendar.gregorianCN
        let parts = monthIdentifier.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
            return .holidayUnavailable(presentDays: 0, days: [], monthIdentifier: monthIdentifier)
        }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let monthDate = calendar.date(from: comps) ?? Date()

        let dayModels = (try? store.fetchAttendanceDays(inMonth: monthDate, calendar: calendar)) ?? []
        let days = dayModels.map { $0.toAttendanceDay() }

        // 1. Try local cache first.
        if let cached = try? holidayService.loadCachedCalendar(year: year, region: "CN", in: context),
           let summary = try? MonthlySummary(monthIdentifier: monthIdentifier, attendanceDays: days, holidayCalendar: cached, calendar: calendar) {
            return .loaded(summary: summary, days: days)
        }

        // 2. Fetch from public API and cache result.
        do {
            let fetched = try await holidayService.fetchCalendar(year: year, region: "CN")
            try? holidayService.cache(fetched, in: context)
            if let summary = try? MonthlySummary(monthIdentifier: monthIdentifier, attendanceDays: days, holidayCalendar: fetched, calendar: calendar) {
                return .loaded(summary: summary, days: days)
            }
        } catch {
            // Fall through to unavailable.
        }

        // 3. Both sources failed — surface unavailable state.
        let presentDays = days.filter { $0.status == .present }.count
        return .holidayUnavailable(presentDays: presentDays, days: days, monthIdentifier: monthIdentifier)
    }
}
