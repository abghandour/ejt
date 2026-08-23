import SwiftUI

/// Trivia's date picker — thin wrapper over the shared game calendar.
struct TriviaCalendarView: View {
    @Environment(TriviatskyModel.self) private var game

    var body: some View {
        GameCalendarView(
            availableDateKeys: game.availableDateKeys,
            playedDateKeys: game.playedDateKeys,
            selectedDateKey: game.dateKey
        ) { key in
            game.selectDate(key)
        }
    }
}
