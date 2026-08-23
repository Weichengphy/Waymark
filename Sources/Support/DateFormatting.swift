import Foundation

enum WaymarkDateFormat {
    /// Range every visit date picker is clamped to. A visit records somewhere
    /// you have already been, so the future is out — but the real reason this
    /// exists is the past end: macOS's date field accepts a typed two-digit
    /// year literally, so typing "25" silently stored the year 25 CE.
    static var visitDateRange: ClosedRange<Date> {
        var components = DateComponents()
        components.year = 1900
        components.month = 1
        components.day = 1
        let start = Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
        return start...Date()
    }

    static let dayMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let dayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

    /// "3 天前" style relative label for list rows, where an exact date is
    /// more precision than the eye needs while scanning.
    static func relative(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case ..<0: return dayMonthYear.string(from: date)
        case 0: return "今天"
        case 1: return "昨天"
        case 2..<7: return "\(days) 天前"
        case 7..<30: return "\(days / 7) 周前"
        case 30..<365: return "\(days / 30) 个月前"
        default: return "\(days / 365) 年前"
        }
    }
}
