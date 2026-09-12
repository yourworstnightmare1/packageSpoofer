import Foundation
import SwiftUI

struct EmbeddedShellANSIStyle {
    var foreground: Color = .white
    var bold = false
}

enum EmbeddedShellANSI {
    static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    /// Parses ANSI SGR color/style sequences into an AttributedString for terminal display.
    static func attributed(from raw: String, state: inout EmbeddedShellANSIStyle) -> AttributedString {
        var result = AttributedString()
        var index = raw.startIndex

        while index < raw.endIndex {
            if raw[index] == "\u{001B}",
               raw.index(after: index) < raw.endIndex,
               raw[raw.index(after: index)] == "[" {
                let csiStart = raw.index(index, offsetBy: 2)
                if let end = raw[csiStart...].firstIndex(where: { $0.isLetter }) {
                    let params = String(raw[csiStart..<end])
                    let command = raw[end]
                    index = raw.index(after: end)

                    if command == "m" {
                        applySGR(params, to: &state)
                    } else if command == "J" || command == "K" || command == "H" || command == "f" {
                        // Clear / cursor moves — ignore for attributed log.
                        continue
                    }
                    continue
                }
            }

            if raw[index] == "\u{000C}" {
                // Form feed / clear: insert a blank line instead of wiping history.
                result.append(AttributedString("\n"))
                index = raw.index(after: index)
                continue
            }

            let nextEscape = raw[index...].firstIndex(of: "\u{001B}") ?? raw.endIndex
            let chunk = String(raw[index..<nextEscape])
            if !chunk.isEmpty {
                var piece = AttributedString(chunk)
                piece.foregroundColor = state.foreground
                piece.font = .system(size: 13, design: .monospaced).weight(state.bold ? .bold : .regular)
                result.append(piece)
            }
            index = nextEscape
        }

        return result
    }

    private static func applySGR(_ params: String, to state: inout EmbeddedShellANSIStyle) {
        let codes = params.split(separator: ";").compactMap { Int($0) }
        let effective = codes.isEmpty ? [0] : codes

        for code in effective {
            switch code {
            case 0:
                state = EmbeddedShellANSIStyle()
            case 1:
                state.bold = true
            case 22:
                state.bold = false
            case 30: state.foreground = Color(red: 0.0, green: 0.0, blue: 0.0)
            case 31: state.foreground = Color(red: 1.0, green: 0.25, blue: 0.25) // red
            case 32: state.foreground = Color(red: 0.25, green: 0.9, blue: 0.35) // green
            case 33: state.foreground = Color(red: 1.0, green: 0.85, blue: 0.2) // yellow
            case 34: state.foreground = Color(red: 0.35, green: 0.55, blue: 1.0)
            case 35: state.foreground = Color(red: 0.9, green: 0.4, blue: 0.9)
            case 36: state.foreground = Color(red: 0.3, green: 0.9, blue: 0.9)
            case 37: state.foreground = Color.white
            case 39: state.foreground = .white
            case 90: state.foreground = Color(white: 0.55)
            case 91: state.foreground = Color(red: 1.0, green: 0.4, blue: 0.4)
            case 92: state.foreground = Color(red: 0.4, green: 1.0, blue: 0.45)
            case 93: state.foreground = Color(red: 1.0, green: 0.95, blue: 0.4)
            case 94: state.foreground = Color(red: 0.5, green: 0.7, blue: 1.0)
            case 95: state.foreground = Color(red: 1.0, green: 0.55, blue: 1.0)
            case 96: state.foreground = Color(red: 0.45, green: 1.0, blue: 1.0)
            case 97: state.foreground = Color.white
            default:
                break
            }
        }
    }
}
