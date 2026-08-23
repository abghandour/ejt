import Foundation
import Testing
@testable import HowJaneyLearnedRussian

struct HolidayTests {
    @Test(arguments: [
        (2024, 3, 31), (2025, 4, 20), (2026, 4, 5), (2027, 3, 28), (2030, 4, 21),
    ])
    func easterDates(year: Int, month: Int, day: Int) {
        let easter = Holiday.easterDate(year: year)
        #expect(easter.month == month)
        #expect(easter.day == day)
    }

    @Test(arguments: [
        (12, 10, Holiday.christmas),
        (12, 26, Holiday.newyear),
        (1, 3, Holiday.newyear),
        (2, 10, Holiday.valentine),
        (3, 15, Holiday.easter),
        (7, 1, Holiday.july4th),
        (10, 31, Holiday.halloween),
        (11, 20, Holiday.thanksgiving),
    ])
    func holidayWindows(month: Int, day: Int, expected: Holiday) throws {
        var components = DateComponents()
        components.year = 2026
        components.month = month
        components.day = day
        let date = try #require(Calendar.current.date(from: components))
        #expect(Holiday.current(on: date) == expected)
    }
}
