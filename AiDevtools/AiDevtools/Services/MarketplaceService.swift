import Foundation
import Combine

public protocol HTTPDataFetching: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataFetching {
    public func data(from url: URL) async throws -> (Data, URLResponse) {
        try await self.data(from: url, delegate: nil)
    }
}

/// Loads marketplace catalogs (JSON arrays of `MarketplaceItem`) from one or more endpoints.
@MainActor
public final class MarketplaceService: ObservableObject {
    @Published public private(set) var items: [MarketplaceItem] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?

    public var endpoints: [URL]
    private let fetcher: HTTPDataFetching

    public init(
        endpoints: [URL] = [],
        fetcher: HTTPDataFetching = URLSession.shared
    ) {
        self.endpoints = endpoints
        self.fetcher = fetcher
    }

    public func reload() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        var combined: [MarketplaceItem] = []
        let decoder = JSONDecoder()
        for url in endpoints {
            do {
                let (data, _) = try await fetcher.data(from: url)
                let decoded = try decoder.decode([MarketplaceItem].self, from: data)
                combined.append(contentsOf: decoded)
            } catch {
                lastError = "Failed to load \(url.absoluteString): \(error.localizedDescription)"
            }
        }
        // Dedupe by id, last wins.
        var byID: [String: MarketplaceItem] = [:]
        for item in combined { byID[item.id] = item }
        items = byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
