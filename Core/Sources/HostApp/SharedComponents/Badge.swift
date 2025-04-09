import SwiftUI

struct BadgeItem {
    enum Level: String, Equatable {
        case warning = "Warning"
        case danger = "Danger"
    }
    let text: String
    let level: Level
    
    init(text: String, level: Level) {
        self.text = text
        self.level = level
    }
}

struct Badge: View {
    let text: String
    let level: BadgeItem.Level
    
    init(badgeItem: BadgeItem) {
        self.text = badgeItem.text
        self.level = badgeItem.level
    }
    
    init(text: String, level: BadgeItem.Level) {
        self.text = text
        self.level = level
    }
    
    var body: some View {
        Text(text).font(.callout)
            .padding(.horizontal, 4)
            .foregroundColor(
                Color("\(level.rawValue)ForegroundColor")
            )
            .background(
                Color("\(level.rawValue)BackgroundColor"),
                in: RoundedRectangle(
                    cornerRadius: 8,
                    style: .circular
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .circular
                )
                .stroke(Color("\(level.rawValue)StrokeColor"), lineWidth: 1)
            )
    }
}
