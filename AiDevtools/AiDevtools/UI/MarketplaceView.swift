import SwiftUI

struct MarketplaceView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var marketplace: MarketplaceService
    @State private var showInstallSheet = false
    @State private var manualURL: String = ""
    @State private var manualBranch: String = "main"
    @State private var installError: String?
    @State private var installing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    Task { await marketplace.reload() }
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                Spacer()
                Button {
                    showInstallSheet = true
                } label: {
                    Label("Install from GitHub…", systemImage: "plus")
                }
            }
            .padding(8)

            if marketplace.isLoading {
                ProgressView().padding()
            }
            if let error = marketplace.lastError {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 8)
            }

            List(selection: bindingSelection()) {
                if marketplace.items.isEmpty && !marketplace.isLoading {
                    Text("No marketplace items. Configure endpoints, then Reload.")
                        .foregroundStyle(.secondary)
                }
                ForEach(marketplace.items) { item in
                    MarketplaceRow(item: item, install: { await installItem(item) })
                        .tag(ContentSelection.marketplaceItem(item.id))
                }
            }
        }
        .navigationTitle("Marketplace")
        .sheet(isPresented: $showInstallSheet) {
            InstallFromGitHubSheet(
                manualURL: $manualURL,
                manualBranch: $manualBranch,
                installing: $installing,
                installError: $installError,
                onInstall: { url, branch in
                    Task { await installFromManual(url: url, branch: branch) }
                }
            )
        }
    }

    private func bindingSelection() -> Binding<ContentSelection?> {
        Binding(
            get: { env.contentSelection },
            set: { env.contentSelection = $0 }
        )
    }

    private func installItem(_ item: MarketplaceItem) async {
        do {
            try await env.install(item.repoURL, branch: item.branch ?? "main")
        } catch {
            installError = error.localizedDescription
        }
    }

    private func installFromManual(url: String, branch: String) async {
        installError = nil
        installing = true
        defer { installing = false }
        guard let parsed = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            installError = "Invalid URL"
            return
        }
        do {
            try await env.install(parsed, branch: branch)
            showInstallSheet = false
        } catch {
            installError = error.localizedDescription
        }
    }
}

private struct MarketplaceRow: View {
    let item: MarketplaceItem
    let install: () async -> Void
    @State private var isInstalling = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body)
                Text(item.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            Spacer()
            Button {
                Task {
                    isInstalling = true
                    await install()
                    isInstalling = false
                }
            } label: {
                if isInstalling {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Install")
                }
            }
            .disabled(isInstalling)
        }
    }
}

struct MarketplaceDetailView: View {
    @EnvironmentObject private var marketplace: MarketplaceService
    let itemID: String

    var body: some View {
        if let item = marketplace.items.first(where: { $0.id == itemID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.name).font(.title2).bold()
                    Text(item.summary).foregroundStyle(.secondary)
                    LabeledContent("Repository") {
                        Link(item.repoURL.absoluteString, destination: item.repoURL)
                    }
                    LabeledContent("Branch") { Text(item.branch ?? "main") }
                    LabeledContent("Kind") { Text(item.kind.rawValue) }
                    if !item.tags.isEmpty {
                        LabeledContent("Tags") { Text(item.tags.joined(separator: ", ")) }
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Item not available", systemImage: "questionmark")
        }
    }
}

private struct InstallFromGitHubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var manualURL: String
    @Binding var manualBranch: String
    @Binding var installing: Bool
    @Binding var installError: String?
    let onInstall: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install from GitHub").font(.title3).bold()
            TextField("https://github.com/owner/repo", text: $manualURL)
                .textFieldStyle(.roundedBorder)
            TextField("Branch", text: $manualBranch)
                .textFieldStyle(.roundedBorder)
            if let installError {
                Text(installError).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button {
                    onInstall(manualURL, manualBranch.isEmpty ? "main" : manualBranch)
                } label: {
                    if installing { ProgressView().controlSize(.small) } else { Text("Install") }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(installing || manualURL.isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 480)
    }
}
