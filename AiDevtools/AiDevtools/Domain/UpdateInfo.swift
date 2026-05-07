import Foundation

public struct Version: Sendable, Comparable, CustomStringConvertible {
    public let components: [Int]
    public let raw: String

    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let core = stripped.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? stripped
        let parts = core.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return nil }
        var nums: [Int] = []
        for p in parts {
            guard let n = Int(p) else { return nil }
            nums.append(n)
        }
        self.components = nums
        self.raw = trimmed
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for i in 0..<count {
            let l = i < lhs.components.count ? lhs.components[i] : 0
            let r = i < rhs.components.count ? rhs.components[i] : 0
            if l != r { return l < r }
        }
        return false
    }

    public static func == (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for i in 0..<count {
            let l = i < lhs.components.count ? lhs.components[i] : 0
            let r = i < rhs.components.count ? rhs.components[i] : 0
            if l != r { return false }
        }
        return true
    }

    public var description: String { raw }
}

public struct UpdateInfo: Sendable, Equatable {
    public let currentVersion: String
    public let latestVersion: String
    public let releaseURL: URL
    public let releaseNotes: String
    public let publishedAt: Date?
    public let isNewer: Bool

    public init(
        currentVersion: String,
        latestVersion: String,
        releaseURL: URL,
        releaseNotes: String,
        publishedAt: Date?,
        isNewer: Bool
    ) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseURL = releaseURL
        self.releaseNotes = releaseNotes
        self.publishedAt = publishedAt
        self.isNewer = isNewer
    }
}

public enum UpdateCheckError: Error, Sendable, CustomStringConvertible {
    case network(String)
    case decode(String)
    case rateLimited
    case notFound
    case invalidVersion(String)

    public var description: String {
        switch self {
        case .network(let msg): return "Network error: \(msg)"
        case .decode(let msg): return "Could not parse release: \(msg)"
        case .rateLimited: return "GitHub API rate limit reached. Try again later."
        case .notFound: return "No releases published yet."
        case .invalidVersion(let v): return "Invalid version string: \(v)"
        }
    }
}
