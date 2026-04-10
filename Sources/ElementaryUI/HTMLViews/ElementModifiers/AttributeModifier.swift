import _UTF8Internals

public final class _AttributeModifier: DOMElementModifier, Invalidateable {
    typealias Value = _AttributeStorage

    let upstream: _AttributeModifier?
    var tracker: DependencyTracker = .init()

    private var lastValue: Value

    var value: Value {
        var combined = lastValue
        combined.append(upstream?.value ?? .none)
        return combined
    }

    init(value: consuming Value, upstream: borrowing DOMElementModifiers) {
        self.lastValue = value
        self.upstream = upstream[_AttributeModifier.key]
        self.upstream?.tracker.addDependency(self)
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        if value != lastValue {
            lastValue = value
            tracker.invalidateAll(&context)
        }
    }

    func mount(_ node: DOM.Node, _ context: inout _MountContext) -> AnyUnmountable {
        logTrace("mounting attribute modifier")
        return AnyUnmountable(MountedInstance(node, self, &context))
    }

    func invalidate(_ context: inout _TransactionContext) {
        self.tracker.invalidateAll(&context)
    }
}

extension _AttributeModifier {
    final class MountedInstance: Unmountable, Invalidateable {
        let modifier: _AttributeModifier
        let node: DOM.Node

        var isDirty: Bool = false
        var previousAttributes: _AttributeStorage = .none

        init(_ node: DOM.Node, _ modifier: _AttributeModifier, _ context: inout _MountContext) {
            self.node = node
            self.modifier = modifier
            self.modifier.tracker.addDependency(self)
            let initialValue = modifier.value
            context.dom.addHTMLAttributes(node, initialValue)
            previousAttributes = initialValue
        }

        func invalidate(_ context: inout _TransactionContext) {
            guard !isDirty else { return }
            logTrace("invalidating attribute modifier")
            isDirty = true
            context.scheduler.addCommitAction(updateDOMNode(_:))
        }

        func updateDOMNode(_ context: inout _CommitContext) {
            logTrace("updating attribute modifier")
            let newValue = modifier.value
            context.dom.applyHTMLAttributes(node, from: previousAttributes, to: newValue)
            previousAttributes = newValue
            isDirty = false
        }

        func unmount(_ context: inout _CommitContext) {
            logTrace("unmounting attribute modifier")
            self.modifier.tracker.removeDependency(self)
        }
    }
}

// MARK: - Attribute patching

extension DOM.Interactor {
    private typealias StylePair = (key: Substring.UTF8View, value: Substring.UTF8View)

    func addHTMLAttributes(_ node: DOM.Node, _ attributes: _AttributeStorage) {
        guard attributes != .none else { return }

        for attribute in attributes.flattened() {
            if let newStyle = attribute._styleKeyValuePairs {
                applyStyleChanges(node, from: nil, to: newStyle)
            } else {
                setAttribute(node, name: attribute.name, value: attribute.value)
            }
        }
    }

    func applyHTMLAttributes(_ node: DOM.Node, from previousAttributes: _AttributeStorage, to newAttributes: _AttributeStorage) {
        if previousAttributes == .none {
            addHTMLAttributes(node, newAttributes)
        } else {
            var oldIterator = previousAttributes.flattened().makeIterator()
            var newIterator = newAttributes.flattened().makeIterator()
            applyAttributeChanges(node, oldIterator: &oldIterator, newIterator: &newIterator)
        }
    }

    private func applyAttributeChanges(
        _ node: DOM.Node,
        oldIterator: inout _MergedAttributes.Iterator,
        newIterator: inout _MergedAttributes.Iterator
    ) {
        while true {
            let oldNext = oldIterator.next()
            let newNext = newIterator.next()

            switch (oldNext, newNext) {
            case let (.some(old), .some(new)):
                guard old.name.utf8Equals(new.name) else {
                    applyAttributesSlowPath(
                        node,
                        firstOld: old,
                        oldIterator: &oldIterator,
                        firstNew: new,
                        newIterator: &newIterator
                    )
                    return
                }

                let oldStyle = old._styleKeyValuePairs
                let newStyle = new._styleKeyValuePairs
                if oldStyle != nil || newStyle != nil {
                    applyStyleChanges(node, from: oldStyle, to: newStyle)
                } else if !old.value.utf8Equals(new.value) {
                    logTrace("updating attribute \(new.name) from \(old.value ?? "") to \(new.value ?? "")")
                    setAttribute(node, name: new.name, value: new.value)
                }
            case (.none, .none):
                return
            default:
                applyAttributesSlowPath(
                    node,
                    firstOld: oldNext,
                    oldIterator: &oldIterator,
                    firstNew: newNext,
                    newIterator: &newIterator
                )
                return
            }
        }
    }

    private func applyAttributesSlowPath(
        _ node: DOM.Node,
        firstOld: _StoredAttribute?,
        oldIterator: inout _MergedAttributes.Iterator,
        firstNew: _StoredAttribute?,
        newIterator: inout _MergedAttributes.Iterator
    ) {
        var oldByKey: [UTF8Key: _StoredAttribute] = [:]
        if let firstOld {
            oldByKey[UTF8Key(firstOld.name)] = firstOld
        }
        while let old = oldIterator.next() {
            oldByKey[UTF8Key(old.name)] = old
        }

        func apply(_ new: _StoredAttribute) {
            let key = UTF8Key(new.name)
            let old = oldByKey.removeValue(forKey: key)
            let oldStyle = old?._styleKeyValuePairs
            let newStyle = new._styleKeyValuePairs
            if oldStyle != nil || newStyle != nil {
                applyStyleChanges(node, from: oldStyle, to: newStyle)
            } else if old == nil || !old!.value.utf8Equals(new.value) {
                setAttribute(node, name: new.name, value: new.value)
            }
        }

        if let firstNew {
            apply(firstNew)
        }
        while let new = newIterator.next() {
            apply(new)
        }

        for old in oldByKey.values {
            if let oldStylePairs = old._styleKeyValuePairs {
                applyStyleChanges(node, from: oldStylePairs, to: nil)
            } else {
                logTrace("removing attribute \(old.name)")
                removeAttribute(node, name: old.name)
            }
        }
    }

    private func applyStyleChanges(
        _ node: DOM.Node,
        from oldStylePairs: _StoredAttribute._StyleKeyValuePairs?,
        to newStylePairs: _StoredAttribute._StyleKeyValuePairs?
    ) {
        guard let newStylePairs else {
            if let oldStylePairs {
                for (oldKey, _) in oldStylePairs {
                    removeStyleProperty(node, name: String(decoding: oldKey, as: UTF8.self))
                }
            }
            return
        }

        guard let oldStylePairs else {
            for (newKey, newValue) in newStylePairs {
                setStyleProperty(
                    node,
                    name: String(Substring(newKey)),
                    value: String(Substring(newValue))
                )
            }
            return
        }

        var oldIterator = oldStylePairs.makeIterator()
        var newIterator = newStylePairs.makeIterator()

        while true {
            let oldNext = oldIterator.next()
            let newNext = newIterator.next()

            switch (oldNext, newNext) {
            case let (.some(oldPair), .some(newPair)):
                guard oldPair.key.utf8Equals(newPair.key) else {
                    applyStylesSlowPath(
                        node,
                        firstOld: oldPair,
                        oldIterator: &oldIterator,
                        firstNew: newPair,
                        newIterator: &newIterator
                    )
                    return
                }

                if !oldPair.value.utf8Equals(newPair.value) {
                    setStyleProperty(
                        node,
                        name: String(Substring(newPair.key)),
                        value: String(Substring(newPair.value))
                    )
                }
            case (.none, .none):
                return
            default:
                applyStylesSlowPath(
                    node,
                    firstOld: oldNext,
                    oldIterator: &oldIterator,
                    firstNew: newNext,
                    newIterator: &newIterator
                )
                return
            }
        }
    }

    private func applyStylesSlowPath(
        _ node: DOM.Node,
        firstOld: StylePair?,
        oldIterator: inout _StoredAttribute._StyleKeyValuePairs.Iterator,
        firstNew: StylePair?,
        newIterator: inout _StoredAttribute._StyleKeyValuePairs.Iterator
    ) {
        var oldByKey: [_StyleUTF8Key: Substring.UTF8View] = [:]
        if let firstOld {
            oldByKey[_StyleUTF8Key(firstOld.key)] = firstOld.value
        }
        while let pair = oldIterator.next() {
            oldByKey[_StyleUTF8Key(pair.key)] = pair.value
        }

        func apply(_ pair: StylePair) {
            let key = _StyleUTF8Key(pair.key)
            if let oldValue = oldByKey.removeValue(forKey: key), oldValue.utf8Equals(pair.value) { return }
            setStyleProperty(node, name: key.stringValue, value: String(decoding: pair.value, as: UTF8.self))
        }

        if let firstNew {
            apply(firstNew)
        }
        while let pair = newIterator.next() {
            apply(pair)
        }

        for remainingKey in oldByKey.keys {
            removeStyleProperty(node, name: remainingKey.stringValue)
        }
    }
}

// TODO: get rid of this Substring stuff, properly fix this in elementary
private struct _StyleUTF8Key: Hashable {
    let raw: Substring.UTF8View

    @inline(__always)
    init(_ raw: Substring.UTF8View) {
        self.raw = raw
    }

    @inline(__always)
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.raw.utf8Equals(rhs.raw)
    }

    @inline(__always)
    func hash(into hasher: inout Hasher) {
        hasher.combine(utf8Bytes: raw)
    }

    @inline(__always)
    var stringValue: String {
        String(decoding: raw, as: UTF8.self)
    }
}
