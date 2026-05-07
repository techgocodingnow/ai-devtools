import Foundation
import Combine

/// JSON snapshot of `RegistryStore` (omits secrets).
public struct RegistrySnapshot: Codable, Sendable {
    public var skills: [Skill]
    public var plugins: [Plugin]
    public var connectors: [Connector]
    public var mcpServers: [MCPServer]
    public var agents: [Agent]
    public var globalEnabled: [GlobalEntry]

    public struct GlobalEntry: Codable, Sendable {
        public var ref: CapabilityRef
        public var enabled: Bool
    }
}

/// JSON snapshot of `ProjectsStore`.
public struct ProjectsSnapshot: Codable, Sendable {
    public var projects: [Project]
    public var selectedProjectID: UUID?
    public var discovered: [Project]
}

public struct PersistencePaths: Sendable {
    public let directory: URL
    public let registryFile: URL
    public let projectsFile: URL

    public init(directory: URL) {
        self.directory = directory
        self.registryFile = directory.appendingPathComponent("registry.json")
        self.projectsFile = directory.appendingPathComponent("projects.json")
    }
}

/// Loads and persists registry + projects state to JSON files in Application Support.
///
/// Writes are debounced via `scheduleSave(_:)` so rapid edits coalesce.
@MainActor
public final class PersistenceService {
    public let paths: PersistencePaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var pendingSaveTask: Task<Void, Never>?
    private let debounceNanoseconds: UInt64

    public init(
        paths: PersistencePaths? = nil,
        fileManager: FileManager = .default,
        debounce: TimeInterval = 0.5
    ) {
        let resolved = paths ?? Self.defaultPaths(fileManager: fileManager)
        self.paths = resolved
        self.fileManager = fileManager
        self.debounceNanoseconds = UInt64(max(debounce, 0) * 1_000_000_000)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        try? fileManager.createDirectory(at: resolved.directory, withIntermediateDirectories: true)
    }

    public static func defaultPaths(fileManager: FileManager = .default) -> PersistencePaths {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("AgentCapabilityManager", isDirectory: true)
        return PersistencePaths(directory: dir)
    }

    // MARK: - Snapshots

    public func makeRegistrySnapshot(_ store: RegistryStore) -> RegistrySnapshot {
        RegistrySnapshot(
            skills: Array(store.skills.values),
            plugins: Array(store.plugins.values),
            connectors: Array(store.connectors.values),
            mcpServers: Array(store.mcpServers.values),
            agents: Array(store.agents.values),
            globalEnabled: store.globalEnabled.map { .init(ref: $0.key, enabled: $0.value) }
        )
    }

    public func makeProjectsSnapshot(_ store: ProjectsStore) -> ProjectsSnapshot {
        ProjectsSnapshot(
            projects: Array(store.projects.values),
            selectedProjectID: store.selectedProjectID,
            discovered: store.discovered
        )
    }

    public func apply(_ snap: RegistrySnapshot, to store: RegistryStore) {
        store.skills = Dictionary(uniqueKeysWithValues: snap.skills.map { ($0.id, $0) })
        store.plugins = Dictionary(uniqueKeysWithValues: snap.plugins.map { ($0.id, $0) })
        store.connectors = Dictionary(uniqueKeysWithValues: snap.connectors.map { ($0.id, $0) })
        store.mcpServers = Dictionary(uniqueKeysWithValues: snap.mcpServers.map { ($0.id, $0) })
        store.agents = Dictionary(uniqueKeysWithValues: snap.agents.map { ($0.id, $0) })
        store.globalEnabled = Dictionary(uniqueKeysWithValues: snap.globalEnabled.map { ($0.ref, $0.enabled) })
    }

    public func apply(_ snap: ProjectsSnapshot, to store: ProjectsStore) {
        store.projects = Dictionary(uniqueKeysWithValues: snap.projects.map { ($0.id, $0) })
        store.selectedProjectID = snap.selectedProjectID
        store.discovered = snap.discovered
    }

    // MARK: - I/O

    public func loadRegistry(into store: RegistryStore) throws {
        guard fileManager.fileExists(atPath: paths.registryFile.path) else { return }
        let data = try Data(contentsOf: paths.registryFile)
        let snap = try decoder.decode(RegistrySnapshot.self, from: data)
        apply(snap, to: store)
    }

    public func loadProjects(into store: ProjectsStore) throws {
        guard fileManager.fileExists(atPath: paths.projectsFile.path) else { return }
        let data = try Data(contentsOf: paths.projectsFile)
        let snap = try decoder.decode(ProjectsSnapshot.self, from: data)
        apply(snap, to: store)
    }

    public func saveRegistry(_ store: RegistryStore) throws {
        let data = try encoder.encode(makeRegistrySnapshot(store))
        try data.write(to: paths.registryFile, options: [.atomic])
    }

    public func saveProjects(_ store: ProjectsStore) throws {
        let data = try encoder.encode(makeProjectsSnapshot(store))
        try data.write(to: paths.projectsFile, options: [.atomic])
    }

    /// Debounced save of both stores; safe to call on every change.
    public func scheduleSave(registry: RegistryStore, projects: ProjectsStore) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self, debounceNanoseconds] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            if Task.isCancelled { return }
            try? self.saveRegistry(registry)
            try? self.saveProjects(projects)
        }
    }
}
