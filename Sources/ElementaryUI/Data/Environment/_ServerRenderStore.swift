/// The environment of a server render pass.
///
/// Rendering is sequential, so environment modifiers set their value for their subtree and restore it after, instead of copying.
final class _ServerRenderStore: @unchecked Sendable {
    @TaskLocal static var current: _ServerRenderStore?

    var context: _ViewContext = .empty

    static func withValue<V, R>(
        _ value: V,
        for key: EnvironmentValues._Key<V>,
        _ body: () throws -> R
    ) rethrows -> R {
        if let current {
            return try current.withValue(value, for: key, body)
        }

        let store = _ServerRenderStore()
        return try $current.withValue(store) {
            try store.withValue(value, for: key, body)
        }
    }

    static func withValue<V, R>(
        _ value: V,
        for key: EnvironmentValues._Key<V>,
        _ body: () async throws -> R
    ) async rethrows -> R {
        if let current {
            return try await current.withValue(value, for: key, body)
        }

        let store = _ServerRenderStore()
        return try await $current.withValue(store) {
            try await store.withValue(value, for: key, body)
        }
    }

    private func withValue<V, R>(
        _ value: V,
        for key: EnvironmentValues._Key<V>,
        _ body: () throws -> R
    ) rethrows -> R {
        let previous = context.environment.boxes.updateValue(EnvironmentValues._Box(value), forKey: key.propertyID)
        defer { context.environment.boxes[key.propertyID] = previous }
        return try body()
    }

    private func withValue<V, R>(
        _ value: V,
        for key: EnvironmentValues._Key<V>,
        _ body: () async throws -> R
    ) async rethrows -> R {
        let previous = context.environment.boxes.updateValue(EnvironmentValues._Box(value), forKey: key.propertyID)
        defer { context.environment.boxes[key.propertyID] = previous }
        return try await body()
    }
}
