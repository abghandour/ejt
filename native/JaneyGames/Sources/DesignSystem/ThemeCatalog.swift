import SwiftUI

/// All built-in themes, values ported from web/shared/theme.css.
nonisolated enum ThemeCatalog {
    static func theme(id: String) -> Theme? {
        all.first { $0.id == id }
    }

    static func festivus(for holiday: Holiday) -> Theme {
        theme(id: "festivus-\(holiday.rawValue)") ?? soviet
    }

    static let all: [Theme] = [
        soviet, dark, light, bw, brazil, ukraine,
        festivusNewYear, festivusValentine, festivusEaster, festivusJuly4th,
        festivusHalloween, festivusThanksgiving, festivusChristmas,
    ]

    static let soviet = Theme(
        id: "soviet", name: "Soviet", isDark: true,
        bgPrimary: Color(hex: 0x0E0E1A), bgSecondary: Color(hex: 0x16162A), surface: Color(hex: 0x1E1E32),
        textPrimary: Color(hex: 0xF5E6C8), textSecondary: Color(hex: 0x6A6A8A), textMuted: Color(hex: 0x8A8AAA),
        accent: Color(hex: 0xC8A830), info: Color(hex: 0x6A9EC0),
        success: Color(hex: 0x5A8A3A), successText: Color(hex: 0x88FF88),
        danger: Color(hex: 0xCC4444), dangerText: Color(hex: 0xFF8888),
        tileTop: Color(hex: 0x2E2E52), tileBottom: Color(hex: 0x22223A), tileBorder: Color(hex: 0x4A4A7E),
        tileSelectedTop: Color(hex: 0x3A3A10), tileSelectedBottom: Color(hex: 0x2A2A08),
        correctTop: Color(hex: 0x2A5A2A), correctBottom: Color(hex: 0x1A3A1A), correctBorder: Color(hex: 0x55AA55),
        wrongTop: Color(hex: 0x5A2A2A), wrongBottom: Color(hex: 0x3A1A1A), wrongBorder: Color(hex: 0xCC4444),
        playTop: Color(hex: 0x3A5A2A), playBottom: Color(hex: 0x2A4A1A), playBorder: Color(hex: 0x5A8A3A),
        sunburst1: Color(hex: 0x8B2020), sunburst2: Color(hex: 0xA33A3A), sunburstOpacity: 0.35
    )

    static let dark = Theme(
        id: "dark", name: "Dark", isDark: true,
        bgPrimary: Color(hex: 0x121218), bgSecondary: Color(hex: 0x1A1A24), surface: Color(hex: 0x1C1C26),
        textPrimary: Color(hex: 0xD8D8E0), textSecondary: Color(hex: 0x6A6A78), textMuted: Color(hex: 0x8888A0),
        accent: Color(hex: 0x5A9ABF), info: Color(hex: 0x5A9ABF),
        success: Color(hex: 0x4A8A4A), successText: Color(hex: 0x7CC87C),
        danger: Color(hex: 0xBB4444), dangerText: Color(hex: 0xEE8888),
        tileTop: Color(hex: 0x252530), tileBottom: Color(hex: 0x1E1E28), tileBorder: Color(hex: 0x3A3A4A),
        tileSelectedTop: Color(hex: 0x1A2A3A), tileSelectedBottom: Color(hex: 0x142030),
        correctTop: Color(hex: 0x1E2E1E), correctBottom: Color(hex: 0x162016), correctBorder: Color(hex: 0x4A8A4A),
        wrongTop: Color(hex: 0x3A1E1E), wrongBottom: Color(hex: 0x2E1616), wrongBorder: Color(hex: 0xBB4444),
        playTop: Color(hex: 0x2A4A3A), playBottom: Color(hex: 0x1E3A2A), playBorder: Color(hex: 0x4A7A5A),
        sunburst1: Color(hex: 0x1A2A3A), sunburst2: Color(hex: 0x0A1828), sunburstOpacity: 0.18
    )

    static let light = Theme(
        id: "light", name: "Light", isDark: false,
        bgPrimary: Color(hex: 0xF0ECE4), bgSecondary: Color(hex: 0xE6E0D6), surface: .white,
        textPrimary: Color(hex: 0x2A2A30), textSecondary: Color(hex: 0x7A7A88), textMuted: Color(hex: 0x9A9AA8),
        accent: Color(hex: 0xB8860B), info: Color(hex: 0x3A7CA5),
        success: Color(hex: 0x3A7A3A), successText: Color(hex: 0x2A6A2A),
        danger: Color(hex: 0xCC4444), dangerText: Color(hex: 0xAA3333),
        tileTop: .white, tileBottom: Color(hex: 0xF5F2EC), tileBorder: Color(hex: 0xC0BAB0),
        tileSelectedTop: Color(hex: 0xFFF8E0), tileSelectedBottom: Color(hex: 0xF5ECD0),
        correctTop: Color(hex: 0xE8F5E8), correctBottom: Color(hex: 0xD8ECD8), correctBorder: Color(hex: 0x3A7A3A),
        wrongTop: Color(hex: 0xFDE8E8), wrongBottom: Color(hex: 0xF5D8D8), wrongBorder: Color(hex: 0xCC4444),
        playTop: Color(hex: 0x4A8A4A), playBottom: Color(hex: 0x3A7A3A), playBorder: Color(hex: 0x3A7A3A),
        sunburst1: Color(hex: 0xE8DCC0), sunburst2: Color(hex: 0xF0E8D4), sunburstOpacity: 0.25
    )

    static let bw = Theme(
        id: "bw", name: "Mono", isDark: true,
        bgPrimary: Color(hex: 0x111111), bgSecondary: Color(hex: 0x1A1A1A), surface: Color(hex: 0x1E1E1E),
        textPrimary: Color(hex: 0xE0E0E0), textSecondary: Color(hex: 0x777777), textMuted: Color(hex: 0x999999),
        accent: Color(hex: 0xCCCCCC), info: Color(hex: 0xAAAAAA),
        success: Color(hex: 0x888888), successText: Color(hex: 0xBBBBBB),
        danger: Color(hex: 0x888888), dangerText: Color(hex: 0xBBBBBB),
        tileTop: Color(hex: 0x2A2A2A), tileBottom: Color(hex: 0x222222), tileBorder: Color(hex: 0x444444),
        tileSelectedTop: Color(hex: 0x3A3A3A), tileSelectedBottom: Color(hex: 0x303030),
        correctTop: Color(hex: 0x303030), correctBottom: Color(hex: 0x282828), correctBorder: Color(hex: 0x888888),
        wrongTop: Color(hex: 0x2E2222), wrongBottom: Color(hex: 0x261A1A), wrongBorder: Color(hex: 0x888888),
        playTop: Color(hex: 0x3A3A3A), playBottom: Color(hex: 0x2E2E2E), playBorder: Color(hex: 0x555555),
        sunburst1: Color(hex: 0x1A1A1A), sunburst2: Color(hex: 0x222222), sunburstOpacity: 0.3
    )

    static let brazil = Theme(
        id: "brazil", name: "Brazil", isDark: true,
        bgPrimary: Color(hex: 0x021A0A), bgSecondary: Color(hex: 0x042E12), surface: Color(hex: 0x0A3D1A),
        textPrimary: Color(hex: 0xF0F0F0), textSecondary: Color(hex: 0x7A9A7A), textMuted: Color(hex: 0xA0BCA0),
        accent: Color(hex: 0xC8A830), info: Color(hex: 0x4A80C0),
        success: Color(hex: 0x009739), successText: Color(hex: 0x40C060),
        danger: Color(hex: 0xCC4444), dangerText: Color(hex: 0xFF8888),
        tileTop: Color(hex: 0x0A3D1A), tileBottom: Color(hex: 0x063010), tileBorder: Color(hex: 0x1A5A2A),
        tileSelectedTop: Color(hex: 0x2A3008), tileSelectedBottom: Color(hex: 0x1E2604),
        correctTop: Color(hex: 0x0A4A1A), correctBottom: Color(hex: 0x063A10), correctBorder: Color(hex: 0x40C060),
        wrongTop: Color(hex: 0x3A1A1A), wrongBottom: Color(hex: 0x2E1212), wrongBorder: Color(hex: 0xCC4444),
        playTop: Color(hex: 0x2A6A2A), playBottom: Color(hex: 0x1A5A1A), playBorder: Color(hex: 0x3A8A3A),
        sunburst1: .white, sunburst2: Color(hex: 0x3CED86), sunburstOpacity: 0.25
    )

    static let ukraine = Theme(
        id: "ukraine", name: "Ukraine", isDark: true,
        bgPrimary: Color(hex: 0x0A1A30), bgSecondary: Color(hex: 0x102040), surface: Color(hex: 0x142850),
        textPrimary: Color(hex: 0xF0EDD8), textSecondary: Color(hex: 0x7A90B0), textMuted: Color(hex: 0x9AB0C8),
        accent: Color(hex: 0xFFD700), info: Color(hex: 0x5090D0),
        success: Color(hex: 0x4A8A4A), successText: Color(hex: 0x80C880),
        danger: Color(hex: 0xCC4444), dangerText: Color(hex: 0xFF8888),
        tileTop: Color(hex: 0x142850), tileBottom: Color(hex: 0x102040), tileBorder: Color(hex: 0x2A4A70),
        tileSelectedTop: Color(hex: 0x2A3010), tileSelectedBottom: Color(hex: 0x222808),
        correctTop: Color(hex: 0x1A2A1A), correctBottom: Color(hex: 0x142014), correctBorder: Color(hex: 0x4A8A4A),
        wrongTop: Color(hex: 0x3A1A1A), wrongBottom: Color(hex: 0x2E1212), wrongBorder: Color(hex: 0xCC4444),
        playTop: Color(hex: 0xC8A800), playBottom: Color(hex: 0xA08800), playBorder: Color(hex: 0xDDB800),
        sunburst1: Color(hex: 0x0050A0), sunburst2: Color(hex: 0x003878), sunburstOpacity: 0.3
    )

    static let festivusNewYear = Theme(
        id: "festivus-newyear", name: "New Year's", isDark: true,
        bgPrimary: Color(hex: 0x0A0A1E), bgSecondary: Color(hex: 0x10102A), surface: Color(hex: 0x14142E),
        textPrimary: Color(hex: 0xE8E0D0), textSecondary: Color(hex: 0x7A7A9A), textMuted: Color(hex: 0x9A9AB8),
        accent: Color(hex: 0xD4AF37), info: Color(hex: 0xA0B8D0),
        success: Color(hex: 0x5A8A5A), successText: Color(hex: 0x8FC88F),
        danger: Color(hex: 0xCC4444), dangerText: Color(hex: 0xFF8888),
        tileTop: Color(hex: 0x1E1E40), tileBottom: Color(hex: 0x161630), tileBorder: Color(hex: 0x3A3A6A),
        tileSelectedTop: Color(hex: 0x2A2A10), tileSelectedBottom: Color(hex: 0x202008),
        correctTop: Color(hex: 0x1A2A1A), correctBottom: Color(hex: 0x142014), correctBorder: Color(hex: 0x55AA55),
        wrongTop: Color(hex: 0x3A1A1A), wrongBottom: Color(hex: 0x2E1212), wrongBorder: Color(hex: 0xCC4444),
        playTop: Color(hex: 0x3A4A2A), playBottom: Color(hex: 0x2A3A1A), playBorder: Color(hex: 0x5A7A3A),
        sunburst1: Color(hex: 0x0F0F3A), sunburst2: Color(hex: 0x1A1A50), sunburstOpacity: 0.25
    )

    static let festivusValentine = Theme(
        id: "festivus-valentine", name: "Valentine's", isDark: true,
        bgPrimary: Color(hex: 0x1A0A10), bgSecondary: Color(hex: 0x241018), surface: Color(hex: 0x28101C),
        textPrimary: Color(hex: 0xF0D8E0), textSecondary: Color(hex: 0x8A6A7A), textMuted: Color(hex: 0xA88898),
        accent: Color(hex: 0xE05080), info: Color(hex: 0xD090B0),
        success: Color(hex: 0x7A5A6A), successText: Color(hex: 0xE0A0C0),
        danger: Color(hex: 0xCC4444), dangerText: Color(hex: 0xFF8888),
        tileTop: Color(hex: 0x2E1828), tileBottom: Color(hex: 0x241020), tileBorder: Color(hex: 0x5A3048),
        tileSelectedTop: Color(hex: 0x3A1830), tileSelectedBottom: Color(hex: 0x2E1028),
        correctTop: Color(hex: 0x2A1A22), correctBottom: Color(hex: 0x201418), correctBorder: Color(hex: 0xA06080),
        wrongTop: Color(hex: 0x3A1A1A), wrongBottom: Color(hex: 0x2E1212), wrongBorder: Color(hex: 0xCC4444),
        playTop: Color(hex: 0x8A3060), playBottom: Color(hex: 0x6A2048), playBorder: Color(hex: 0xA04070),
        sunburst1: Color(hex: 0x3A0A1A), sunburst2: Color(hex: 0x4A1428), sunburstOpacity: 0.2
    )

    static let festivusEaster = Theme(
        id: "festivus-easter", name: "Easter", isDark: false,
        bgPrimary: Color(hex: 0xF4F0F8), bgSecondary: Color(hex: 0xECE6F2), surface: .white,
        textPrimary: Color(hex: 0x3A2A4A), textSecondary: Color(hex: 0x8A7A9A), textMuted: Color(hex: 0xA898B8),
        accent: Color(hex: 0x9B6BB0), info: Color(hex: 0x6AAA8A),
        success: Color(hex: 0x5A9A5A), successText: Color(hex: 0x3A7A3A),
        danger: Color(hex: 0xC46A6A), dangerText: Color(hex: 0xA04040),
        tileTop: .white, tileBottom: Color(hex: 0xF8F4FC), tileBorder: Color(hex: 0xC8B8D8),
        tileSelectedTop: Color(hex: 0xF0E8FF), tileSelectedBottom: Color(hex: 0xE8DDF8),
        correctTop: Color(hex: 0xE8F5E8), correctBottom: Color(hex: 0xD8ECD8), correctBorder: Color(hex: 0x5A9A5A),
        wrongTop: Color(hex: 0xFDE8E8), wrongBottom: Color(hex: 0xF5D8D8), wrongBorder: Color(hex: 0xC46A6A),
        playTop: Color(hex: 0x6AAA8A), playBottom: Color(hex: 0x5A9A7A), playBorder: Color(hex: 0x5A9A7A),
        sunburst1: Color(hex: 0xE8DDF0), sunburst2: Color(hex: 0xF0E8F8), sunburstOpacity: 0.2
    )

    static let festivusJuly4th = Theme(
        id: "festivus-july4th", name: "4th of July", isDark: true,
        bgPrimary: Color(hex: 0x0A0E1E), bgSecondary: Color(hex: 0x101828), surface: Color(hex: 0x121A2E),
        textPrimary: Color(hex: 0xE8E4F0), textSecondary: Color(hex: 0x7A8098), textMuted: Color(hex: 0x9A9EB8),
        accent: Color(hex: 0xE8E8F0), info: Color(hex: 0x4A8AD0),
        success: Color(hex: 0x4A7A4A), successText: Color(hex: 0x8FC88F),
        danger: Color(hex: 0xC83030), dangerText: Color(hex: 0xF08080),
        tileTop: Color(hex: 0x1A2440), tileBottom: Color(hex: 0x141C34), tileBorder: Color(hex: 0x2A3A5E),
        tileSelectedTop: Color(hex: 0x1A2A4A), tileSelectedBottom: Color(hex: 0x142040),
        correctTop: Color(hex: 0x1A2A1A), correctBottom: Color(hex: 0x142014), correctBorder: Color(hex: 0x4A7A4A),
        wrongTop: Color(hex: 0x3A1414), wrongBottom: Color(hex: 0x2E0E0E), wrongBorder: Color(hex: 0xC83030),
        playTop: Color(hex: 0xB02020), playBottom: Color(hex: 0x901818), playBorder: Color(hex: 0xC83030),
        sunburst1: Color(hex: 0x1A1040), sunburst2: Color(hex: 0x20184A), sunburstOpacity: 0.2
    )

    static let festivusHalloween = Theme(
        id: "festivus-halloween", name: "Halloween", isDark: true,
        bgPrimary: Color(hex: 0x0E0A0A), bgSecondary: Color(hex: 0x181010), surface: Color(hex: 0x1E1010),
        textPrimary: Color(hex: 0xF0DCC8), textSecondary: Color(hex: 0x8A7060), textMuted: Color(hex: 0xA88A78),
        accent: Color(hex: 0xE08020), info: Color(hex: 0x9060B0),
        success: Color(hex: 0x6A8A3A), successText: Color(hex: 0xA0C060),
        danger: Color(hex: 0xCC4444), dangerText: Color(hex: 0xFF8888),
        tileTop: Color(hex: 0x201418), tileBottom: Color(hex: 0x180E12), tileBorder: Color(hex: 0x4A2A3A),
        tileSelectedTop: Color(hex: 0x302010), tileSelectedBottom: Color(hex: 0x281808),
        correctTop: Color(hex: 0x1E2A14), correctBottom: Color(hex: 0x162010), correctBorder: Color(hex: 0x6A8A3A),
        wrongTop: Color(hex: 0x3A1A1A), wrongBottom: Color(hex: 0x2E1212), wrongBorder: Color(hex: 0xCC4444),
        playTop: Color(hex: 0xB06010), playBottom: Color(hex: 0x904A08), playBorder: Color(hex: 0xC87020),
        sunburst1: Color(hex: 0x2A1010), sunburst2: Color(hex: 0x3A1818), sunburstOpacity: 0.25
    )

    static let festivusThanksgiving = Theme(
        id: "festivus-thanksgiving", name: "Thanksgiving", isDark: true,
        bgPrimary: Color(hex: 0x12100A), bgSecondary: Color(hex: 0x1C1810), surface: Color(hex: 0x201C12),
        textPrimary: Color(hex: 0xF0E4D0), textSecondary: Color(hex: 0x8A7A60), textMuted: Color(hex: 0xA89878),
        accent: Color(hex: 0xC89030), info: Color(hex: 0xA08060),
        success: Color(hex: 0x6A7A3A), successText: Color(hex: 0xA0B860),
        danger: Color(hex: 0xBB4444), dangerText: Color(hex: 0xEE8888),
        tileTop: Color(hex: 0x242018), tileBottom: Color(hex: 0x1C1810), tileBorder: Color(hex: 0x4A3E28),
        tileSelectedTop: Color(hex: 0x302810), tileSelectedBottom: Color(hex: 0x282008),
        correctTop: Color(hex: 0x1E2414), correctBottom: Color(hex: 0x161C10), correctBorder: Color(hex: 0x6A7A3A),
        wrongTop: Color(hex: 0x3A1A1A), wrongBottom: Color(hex: 0x2E1212), wrongBorder: Color(hex: 0xBB4444),
        playTop: Color(hex: 0x8A6A20), playBottom: Color(hex: 0x6A5018), playBorder: Color(hex: 0xA07A28),
        sunburst1: Color(hex: 0x2A1E0A), sunburst2: Color(hex: 0x3A2A12), sunburstOpacity: 0.2
    )

    static let festivusChristmas = Theme(
        id: "festivus-christmas", name: "Christmas", isDark: true,
        bgPrimary: Color(hex: 0x0E0A0A), bgSecondary: Color(hex: 0x161010), surface: Color(hex: 0x1C1010),
        textPrimary: Color(hex: 0xF0E8D8), textSecondary: Color(hex: 0x8A7A6A), textMuted: Color(hex: 0xA89888),
        accent: Color(hex: 0xD4A830), info: Color(hex: 0x4A9A4A),
        success: Color(hex: 0x4A8A4A), successText: Color(hex: 0x80C880),
        danger: Color(hex: 0xC03030), dangerText: Color(hex: 0xF08080),
        tileTop: Color(hex: 0x221418), tileBottom: Color(hex: 0x1A0E12), tileBorder: Color(hex: 0x4A2028),
        tileSelectedTop: Color(hex: 0x2A2A10), tileSelectedBottom: Color(hex: 0x222208),
        correctTop: Color(hex: 0x1A2A1A), correctBottom: Color(hex: 0x142014), correctBorder: Color(hex: 0x4A8A4A),
        wrongTop: Color(hex: 0x3A1414), wrongBottom: Color(hex: 0x2E0E0E), wrongBorder: Color(hex: 0xC03030),
        playTop: Color(hex: 0x2A5A2A), playBottom: Color(hex: 0x1E4A1E), playBorder: Color(hex: 0x3A7A3A),
        sunburst1: Color(hex: 0x3A0A0A), sunburst2: Color(hex: 0x1A3A1A), sunburstOpacity: 0.2
    )
}
