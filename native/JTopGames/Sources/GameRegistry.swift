import Foundation

/// Describes a single game entry in the registry.
/// Each game has a unique identifier, display metadata, and references to its bundled files.
struct GameDefinition: Identifiable {
    let id: String
    let displayName: String
    let iconName: String
    let htmlFileName: String
    let dataFileNames: [String]
}

/// Static registry of all available games.
/// Adding a new game only requires appending a new entry to the `games` array.
struct GameRegistry {
    static let games: [GameDefinition] = [
        GameDefinition(id: "snake", displayName: "Snakesky", iconName: "lizard.fill", htmlFileName: "snake.html", dataFileNames: ["snakesky.json"]),
        GameDefinition(id: "wordsky", displayName: "Wordsky", iconName: "textformat.abc", htmlFileName: "wordsky.html", dataFileNames: ["wordsky.json"]),
        GameDefinition(id: "rootsky", displayName: "Rootsky", iconName: "tree.fill", htmlFileName: "rootsky.html", dataFileNames: ["rootsky.json"]),
        GameDefinition(id: "tetrisky", displayName: "Tetrisky", iconName: "square.grid.3x3.bottomright.filled", htmlFileName: "tetrisky.html", dataFileNames: ["snakesky.json"]),
        GameDefinition(id: "scramblisky", displayName: "Scramblisky", iconName: "textformat.abc.dottedunderline", htmlFileName: "scramblisky.html", dataFileNames: ["snakesky.json"])
    ]
}
