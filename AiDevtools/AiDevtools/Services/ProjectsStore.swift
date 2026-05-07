import Foundation
import Combine

/// Owns managed projects, selection, and override resolution.
@MainActor
public final class ProjectsStore: ObservableObject {
    @Published public var projects: [UUID: Project] = [:]
    @Published public var selectedProjectID: UUID?
    @Published public var discovered: [Project] = []

    public init() {}

    public var orderedProjects: [Project] {
        projects.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func addOrUpdate(_ project: Project) {
        projects[project.id] = project
    }

    public func remove(_ id: UUID) {
        projects.removeValue(forKey: id)
        if selectedProjectID == id { selectedProjectID = nil }
    }

    public func setOverride(projectID: UUID, ref: CapabilityRef, value: CapabilityScopeOverride) {
        guard var project = projects[projectID] else { return }
        if value == .inherit {
            project.overrides.removeValue(forKey: ref)
        } else {
            project.overrides[ref] = value
        }
        projects[projectID] = project
    }

    public func override(projectID: UUID, ref: CapabilityRef) -> CapabilityScopeOverride {
        projects[projectID]?.overrides[ref] ?? .inherit
    }

    /// Resolve effective enable state given the global default.
    public func effectiveState(projectID: UUID, ref: CapabilityRef, global: Bool) -> Bool {
        switch override(projectID: projectID, ref: ref) {
        case .inherit: return global
        case .enabled: return true
        case .disabled: return false
        }
    }

    /// Promote a discovered project candidate into the managed set.
    public func promoteDiscovered(_ candidate: Project) {
        discovered.removeAll { $0.rootPath == candidate.rootPath }
        addOrUpdate(candidate)
    }
}
