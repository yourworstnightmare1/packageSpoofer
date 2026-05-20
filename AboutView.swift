import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .cornerRadius(14)
                .shadow(radius: 3)

            Text(appName())
                .font(.title3).bold()

            Text("Version \(versionString())")
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("GUI Edition")
                Text("© 2026 yourworstnightmare1. All rights reserved.")
                Text("macOS, x86_64")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/yourworstnightmare1")!)
                Spacer()
                Button("OK") { dismiss() }
            }
        }
        .padding(18)
        .frame(width: 360, height: 240)
        .background(WindowConfigurator(disableMinimize: true, lockToContentSize: true))
    }
}

private func appName() -> String {
    Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "App"
}

private func versionString() -> String {
    let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    let versionLabel = short.hasPrefix("v") ? short : "v\(short)"
    guard !build.isEmpty else { return versionLabel }
    return "\(versionLabel) (\(build))"
}
