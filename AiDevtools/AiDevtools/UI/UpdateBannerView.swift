import SwiftUI

struct UpdateBannerView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        if let info = env.updateState.value, info.isNewer, !env.updateBannerDismissed {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.tint)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version \(info.latestVersion) is available")
                        .font(.system(.body, weight: .semibold))
                    Text("You're on \(info.currentVersion). Download the latest release to upgrade.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Release notes") {
                    env.showUpdateSheet = true
                }
                .buttonStyle(.bordered)
                Button("Download") {
                    env.openReleasesPage()
                }
                .buttonStyle(.borderedProminent)
                Button {
                    env.updateBannerDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .overlay(alignment: .bottom) {
                Divider()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
