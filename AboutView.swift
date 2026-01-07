import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .cornerRadius(16)
                .shadow(radius: 4)

            Text(appName())
                .font(.title2).bold()

            Text("Version \(versionString())")
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("GUI Edition")
                Text("© 2026 yourworstnightmare1. All rights reserved.")
                Text("A CLI edition is also available on GitHub if you don't like GUIs.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/yourworstnightmare1")!)
                Spacer()
                Button("OK") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 420, height: 320)
    }
}

private func appName() -> String {
    Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "App"
}

private func versionString() -> String {
    let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    return [short, build.isEmpty ? nil : "(\(build))"].compactMap { $0 }.joined(separator: " ")
}
