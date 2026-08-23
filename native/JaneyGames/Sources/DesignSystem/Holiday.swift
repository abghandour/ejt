import Foundation

/// Holiday rotation for the Festivus theme, ported from web/shared/theme.js.
nonisolated enum Holiday: String, CaseIterable, Sendable {
    case newyear, valentine, easter, july4th, halloween, thanksgiving, christmas

    var displayName: String {
        switch self {
        case .newyear: "New Year's"
        case .valentine: "Valentine's Day"
        case .easter: "Easter"
        case .july4th: "4th of July"
        case .halloween: "Halloween"
        case .thanksgiving: "Thanksgiving"
        case .christmas: "Christmas"
        }
    }

    /// Easter Sunday via the Anonymous Gregorian algorithm. Returns (month, day), 1-indexed.
    static func easterDate(year: Int) -> (month: Int, day: Int) {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return (month, day)
    }

    /// The holiday whose seasonal window contains the given date.
    /// Windows match theme.js exactly (Christmas Dec 1–25, New Year Dec 26–Jan 6, …).
    static func current(on date: Date = .now, calendar: Calendar = .current) -> Holiday {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let m = components.month, let d = components.day else {
            return .easter
        }
        let easter = easterDate(year: year)

        func onOrBefore(_ tm: Int, _ td: Int) -> Bool { m < tm || (m == tm && d <= td) }
        func onOrAfter(_ tm: Int, _ td: Int) -> Bool { m > tm || (m == tm && d >= td) }

        if (m == 12 && d >= 26) || (m == 1 && d <= 6) { return .newyear }
        if onOrAfter(1, 7) && onOrBefore(2, 18) { return .valentine }
        if onOrAfter(2, 19) && onOrBefore(easter.month, easter.day) { return .easter }
        if (m > easter.month || (m == easter.month && d > easter.day)) && onOrBefore(7, 10) { return .july4th }
        if onOrAfter(7, 11) && onOrBefore(11, 1) { return .halloween }
        if onOrAfter(11, 2) && onOrBefore(11, 30) { return .thanksgiving }
        if onOrAfter(12, 1) && onOrBefore(12, 25) { return .christmas }
        return .easter
    }
}
