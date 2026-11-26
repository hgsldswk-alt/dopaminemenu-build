import SwiftUI

enum DesignPalette {
    static let background = Color(red: 248/255, green: 246/255, blue: 240/255)
    static let surface = Color.white
    static let ink = Color(red: 40/255, green: 38/255, blue: 35/255)
    static let accent = Color(red: 242/255, green: 102/255, blue: 90/255)
    static let mint = Color(red: 108/255, green: 197/255, blue: 176/255)
    static let yellow = Color(red: 246/255, green: 210/255, blue: 122/255)
    static let blue = Color(red: 138/255, green: 168/255, blue: 216/255)
}

extension Budget {
    var tileColor: Color {
        switch self {
        case .five: DesignPalette.mint
        case .fifteen: DesignPalette.yellow
        case .thirty: DesignPalette.blue
        }
    }

    var tileSymbol: String {
        switch self {
        case .five: "bolt.fill"
        case .fifteen: "cup.and.saucer.fill"
        case .thirty: "clock"
        }
    }
}
