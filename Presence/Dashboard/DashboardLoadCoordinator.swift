import Foundation
import OSLog
import SwiftData

// MARK: - Attendance fetching protocol

/// Minimal abstraction over the attendance store so DashboardLoadCoordinator
/// can be tested with a stub that simulates fetch failures.
@MainActor
protocol AttendanceDayFetching {
    func fetchAttendanceDays(inMonth month: Date, calendar: Calendar) throws -> [AttendanceDayModel]
}

extension AttendanceStore: AttendanceDayFetching {}

// MARK: - Load Result

enum DashboardLoadResult {
    case loaded(summary: MonthlySummary, days: [AttendanceDay])
    case holidayUnavailable(presentDays: Int, days: [AttendanceDay], monthIdentifier: String)
}

// MARK: - Coordinator

/// Pure loading logic for the Dashboard; extracted for testability.
@MainActor
struct DashboardLoadCoordinator {
    let store: any AttendanceDayFetching
    let holidayService: HolidayService
    let context: ModelContext

    private let logger = Logger(subsystem: "com.presence.app", category: "Dashboard")

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

        // Fetch attendance days; log failure and fall back to empty rather than crashing.
        let dayModels: [AttendanceDayModel]
        do {
            dayModels = try store.fetchAttendanceDays(inMonth: monthDate, calendar: calendar)
        } catch {
            logger.error("fetchAttendanceDays failed: \(error, privacy: .public)")
            dayModels = []
        }
        let days = dayModels.map { $0.toAttendanceDay() }

        // 1. Try local cache first.
        do {
            if let cached = try holidayService.loadCachedCalendar(year: year, region: "CN", in: context) {
                // Calendar is available locally — a MonthlySummary failure here is an
                // unrecoverable data error; return unavailable instead of falling through to fetch.
                do {
                    let summary = try MonthlySummary(
                        monthIdentifier: monthIdentifier,
                        attendanceDays: days,
                        holidayCalendar: cached,
                        calendar: calendar
                    )
                    return .loaded(summary: summary, days: days)
                } catch {
                    logger.error("MonthlySummary construction failed (cached): \(error, privacy: .public)")
                    let presentDays = days.filter { $0.status == .present }.count
                    return .holidayUnavailable(presentDays: presentDays, days: days, monthIdentifier: monthIdentifier)
                }
            }
        } catch {
            logger.error("loadCachedCalendar failed: \(error, privacy: .public)")
        }

        // 2. Fetch from public API and cache result.
        do {
            let fetched = try await holidayService.fetchCalendar(year: year, region: "CN")
            do {
                try holidayService.cache(fetched, in: context)
            } catch {
                logger.error("holidayService.cache failed: \(error, privacy: .public)")
            }
            do {
                let summary = try MonthlySummary(
                    monthIdentifier: monthIdentifier,
                    attendanceDays: days,
                    holidayCalendar: fetched,
                    calendar: calendar
                )
                return .loaded(summary: summary, days: days)
            } catch {
                logger.error("MonthlySummary construction failed (fetched): \(error, privacy: .public)")
                let presentDays = days.filter { $0.status == .present }.count
                return .holidayUnavailable(presentDays: presentDays, days: days, monthIdentifier: monthIdentifier)
            }
        } catch {
            logger.error("fetchCalendar failed: \(error, privacy: .public)")
        }

        // 3. Both sources failed — surface unavailable state.
        let presentDays = days.filter { $0.status == .present }.count
        return .holidayUnavailable(presentDays: presentDays, days: days, monthIdentifier: monthIdentifier)
    }
}
