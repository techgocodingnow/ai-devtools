import Foundation

public actor UpdateService {
    public static let repoOwner = "techgocodingnow"
    public static let repoName = "ai-devtools"
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    public static let releasesPageURL = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!

    private let session: URLSession
    private let bundle: Bundle
    private var lastChecked: Date?

    public init(session: URLSession = .shared, bundle: Bundle = .main) {
        self.session = session
        self.bundle = bundle
    }

    public var currentVersion: String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    public func shouldCheck(now: Date = .now, minInterval: TimeInterval = 6 * 3600) -> Bool {
        guard let last = lastChecked else { return true }
        return now.timeIntervalSince(last) >= minInterval
    }

    public func fetchLatest() async throws(UpdateCheckError) -> UpdateInfo {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("AiDevtools/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw .network("non-HTTP response")
        }
        switch http.statusCode {
        case 200: break
        case 403: throw .rateLimited
        case 404: throw .notFound
        default: throw .network("HTTP \(http.statusCode)")
        }

        let payload: GitHubRelease
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            payload = try decoder.decode(GitHubRelease.self, from: data)
        } catch {
            throw .decode(error.localizedDescription)
        }

        if payload.draft == true || payload.prerelease == true {
            throw .notFound
        }

        guard let latest = Version(payload.tag_name) else {
            throw .invalidVersion(payload.tag_name)
        }
        let current = Version(currentVersion) ?? Version("0.0.0")!
        let url = URL(string: payload.html_url) ?? Self.releasesPageURL

        let info = UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latest.raw,
            releaseURL: url,
            releaseNotes: payload.body ?? "",
            publishedAt: payload.published_at,
            isNewer: latest > current
        )
        lastChecked = Date()
        return info
    }

    private struct GitHubRelease: Decodable, Sendable {
        let tag_name: String
        let html_url: String
        let body: String?
        let published_at: Date?
        let draft: Bool?
        let prerelease: Bool?
    }
}
