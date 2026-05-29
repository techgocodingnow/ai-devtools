import Foundation

/// Fetches the plugin catalog (`.claude-plugin/marketplace.json`) for known GitHub-backed
/// marketplaces and maps it into the UI feed.
///
/// Pure network reads over `raw.githubusercontent.com`; failures yield an empty result for
/// that source rather than throwing, so a flaky or private source never breaks the feed.
public nonisolated struct MarketplaceCatalogService: Sendable {

    public struct CatalogResult: Sendable {
        public var marketID: String
        public var items: [CatalogItem]
    }

    public struct CatalogItem: Sendable {
        public var id: String
        public var name: String
        public var vendor: String
        public var description: String
        public var category: String?
    }

    /// A marketplace we know how to fetch: id + GitHub owner/repo.
    public struct Source: Sendable {
        public var id: String
        public var owner: String
        public var repo: String
        public init(id: String, owner: String, repo: String) {
            self.id = id; self.owner = owner; self.repo = repo
        }
    }

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Parse `owner`/`repo` out of a GitHub URL (`https://github.com/owner/repo[.git]`).
    public static func source(id: String, url: String) -> Source? {
        guard let comps = URLComponents(string: url), let host = comps.host,
              host.contains("github.com") else { return nil }
        let parts = comps.path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        let repo = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
        return Source(id: id, owner: parts[0], repo: repo)
    }

    /// Fetch all sources concurrently. Each result carries its source id and parsed items.
    public func fetchAll(_ sources: [Source]) async -> [CatalogResult] {
        await withTaskGroup(of: CatalogResult?.self) { group in
            for source in sources {
                group.addTask { await fetch(source) }
            }
            var out: [CatalogResult] = []
            for await result in group { if let result { out.append(result) } }
            return out
        }
    }

    private func fetch(_ source: Source) async -> CatalogResult? {
        for branch in ["main", "master"] {
            let urlString = "https://raw.githubusercontent.com/\(source.owner)/\(source.repo)/\(branch)/.claude-plugin/marketplace.json"
            guard let url = URL(string: urlString) else { continue }
            guard let (data, response) = try? await session.data(from: url),
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
            guard let items = parse(data, marketID: source.id), !items.isEmpty else { continue }
            return CatalogResult(marketID: source.id, items: items)
        }
        return nil
    }

    private func parse(_ data: Data, marketID: String) -> [CatalogItem]? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let plugins = root["plugins"] as? [[String: Any]] else { return nil }
        let marketOwner = ownerName(root["owner"])

        return plugins.compactMap { plugin -> CatalogItem? in
            guard let name = plugin["name"] as? String else { return nil }
            let vendor = ownerName(plugin["author"]) ?? marketOwner ?? marketID
            return CatalogItem(
                id: "\(marketID)/\(name)",
                name: name,
                vendor: vendor,
                description: (plugin["description"] as? String) ?? "",
                category: plugin["category"] as? String
            )
        }
    }

    /// `owner`/`author` can be a string or a `{ "name": ... }` object.
    private func ownerName(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any] { return dict["name"] as? String }
        return nil
    }
}
