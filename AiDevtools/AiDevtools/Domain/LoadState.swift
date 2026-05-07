import Foundation

public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    public var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
