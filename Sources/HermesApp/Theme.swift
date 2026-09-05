import SwiftUI
#if canImport(HermesCore)
import HermesCore
#endif

/// Hermes design tokens, tuned to sit close to Telegram iOS (light theme).
enum HermesTheme {
    // Accent — one unmistakable blue.
    static let blue = Color(hex: 0x229ED9)
    static let deepBlue = Color(hex: 0x0088CC)
    static let lightBlue = Color(hex: 0x40A7E3)

    // Canvas + chrome.
    static let canvas = Color.white
    static let groupedCanvas = Color(hex: 0xF2F2F7)
    static let hairline = Color.black.opacity(0.08)
    static let strongHairline = Color.black.opacity(0.14)

    // Text.
    static let muted = Color(hex: 0x8E8E93)
    static let subtle = Color(hex: 0xAEAEB2)

    // Fields / pills.
    static let fieldFill = Color(hex: 0x767680).opacity(0.12)
    static let pillFill = Color(hex: 0xEFEFF4)

    // Bubbles.
    static let incomingBubble = Color.white
    static let outgoingBubbleTop = Color(hex: 0xE6F3FB)
    static let outgoingBubbleBottom = Color(hex: 0xDCEDF9)
    static let outgoingBubble = Color(hex: 0xE1F0FA)
    static let bubbleRadius: CGFloat = 13
    static let bubbleTailRadius: CGFloat = 5
    static let bubbleVerticalPadding: CGFloat = 7
    static let bubbleHorizontalPadding: CGFloat = 10

    // Avatars (Telegram's peer colour set).
    static let avatarPalette: [Color] = [
        Color(hex: 0xE17076), // red
        Color(hex: 0xFAA774), // orange
        Color(hex: 0xA695E7), // violet
        Color(hex: 0x7BC862), // green
        Color(hex: 0x6EC9CB), // cyan
        Color(hex: 0x65AADD), // blue
        Color(hex: 0xEE7AAE)  // pink
    ]

    static func avatarColor(for name: String) -> Color {
        avatarPalette[NameFormatting.paletteIndex(for: name, paletteCount: avatarPalette.count)]
    }

    static let outgoingGradient = LinearGradient(
        colors: [outgoingBubbleTop, outgoingBubbleBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Font {
    static let chatName = Font.system(size: 17, weight: .semibold)
    static let chatPreview = Font.system(size: 15)
    static let chatTime = Font.system(size: 13).monospacedDigit()
    static let bubbleBody = Font.system(size: 17)
    static let bubbleMeta = Font.system(size: 11)
    static let navTitle = Font.system(size: 17, weight: .semibold)
    static let navSubtitle = Font.system(size: 13)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    /// Blurred/glass chrome for nav and tab bars (iOS only; no-op elsewhere).
    @ViewBuilder
    func hermesGlassChrome() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

enum HermesTimeFormatting {
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    private static let dayHeading: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    private static let dayHeadingWithYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    /// Telegram chat list: time today, weekday this week, otherwise short date.
    static func chatListTime(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return clock.string(from: date)
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: now), date > weekAgo {
            return weekday.string(from: date)
        }
        return shortDate.string(from: date)
    }

    static func clockTime(_ date: Date) -> String {
        clock.string(from: date)
    }

    /// Date separator pill: Today / Yesterday / September 2 / September 2, 2025.
    static func separatorTitle(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return dayHeading.string(from: date)
        }
        return dayHeadingWithYear.string(from: date)
    }
}
