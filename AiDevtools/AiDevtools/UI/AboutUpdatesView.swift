import SwiftUI

struct AboutUpdatesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Software Update")
                        .font(.title2.bold())
                    Text("Distributed via GitHub Releases")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            content

            Divider()

            HStack {
                Button("Check Now") {
                    env.checkForUpdates(force: true)
                }
                .disabled(env.updateState.isLoading)

                Spacer()

                if let info = env.updateState.value {
                    Button("View on GitHub") {
                        env.openReleasesPage()
                    }
                    if info.isNewer {
                        Button("Download") {
                            env.openReleasesPage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
    }

    @ViewBuilder
    private var content: some View {
        switch env.updateState {
        case .idle:
            Text("No update check has run yet.")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking GitHub for the latest release…")
            }
        case .loaded(let info):
            VStack(alignment: .leading, spacing: 8) {
                versionRow(label: "Installed", value: info.currentVersion)
                versionRow(label: "Latest", value: info.latestVersion)
                if let date = info.publishedAt {
                    versionRow(label: "Published", value: date.formatted(date: .abbreviated, time: .shortened))
                }
                Text(info.isNewer ? "An update is available." : "You're up to date.")
                    .font(.headline)
                    .foregroundStyle(info.isNewer ? .orange : .green)
                    .padding(.top, 4)

                if !info.releaseNotes.isEmpty {
                    Text("Release notes")
                        .font(.subheadline.bold())
                        .padding(.top, 4)
                    ScrollView {
                        Text(LocalizedStringKey(info.releaseNotes))
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 180)
                }
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("Couldn't check for updates", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func versionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}
