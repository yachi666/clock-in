import Foundation

func dayIdentifier(for date: Date, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year, let month = components.month, let day = components.day else {
        fatalError("Calendar \(calendar.identifier) did not return year/month/day components for \(date)")
    }
    return String(format: "%04d-%02d-%02d", year, month, day)
}
