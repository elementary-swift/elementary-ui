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
            addHTMLAttributes(initialValue, to: node, using: context.dom)
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
            applyHTMLAttributes(from: previousAttributes, to: newValue, on: node, using: context.dom)
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

struct DOMAttributePatcher {
    let dom: DOMInteractor

    private typealias StylePair = (key: Substring.UTF8View, value: Substring.UTF8View)

    func addHTMLAttributes(_ node: DOM.Node, _ attributes: _AttributeStorage) {
        guard attributes != .none else { return }

        for attribute in attributes.flattened() {
            if let newStyle = attribute._styleKeyValuePairs {
                applyStyleChanges(node, from: nil, to: newStyle)
            } else {
                dom.setAttribute(node, name: attribute.name, value: attribute.value)
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
                    dom.setAttribute(node, name: new.name, value: new.value)
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
        var oldAttributes: [_StoredAttribute] = []
        oldAttributes.reserveCapacity(4)
        if let firstOld {
            oldAttributes.append(firstOld)
        }
        while let old = oldIterator.next() {
            oldAttributes.append(old)
        }

        if let firstNew {
            applyAttribute(firstNew, to: node, matching: &oldAttributes)
        }
        while let new = newIterator.next() {
            applyAttribute(new, to: node, matching: &oldAttributes)
        }

        var oldIndex = 0
        while oldIndex < oldAttributes.count {
            let old = oldAttributes[oldIndex]
            if let oldStylePairs = old._styleKeyValuePairs {
                applyStyleChanges(node, from: oldStylePairs, to: nil)
            } else {
                logTrace("removing attribute \(old.name)")
                dom.removeAttribute(node, name: old.name)
            }
            oldIndex += 1
        }
    }

    private func applyAttribute(
        _ new: _StoredAttribute,
        to node: DOM.Node,
        matching oldAttributes: inout [_StoredAttribute]
    ) {
        var old: _StoredAttribute?
        var index = 0
        while index < oldAttributes.count {
            if oldAttributes[index].name.utf8Equals(new.name) {
                old = oldAttributes.remove(at: index)
                break
            }
            index += 1
        }
        let oldStyle = old?._styleKeyValuePairs
        let newStyle = new._styleKeyValuePairs
        if oldStyle != nil || newStyle != nil {
            applyStyleChanges(node, from: oldStyle, to: newStyle)
        } else if old == nil || !old!.value.utf8Equals(new.value) {
            dom.setAttribute(node, name: new.name, value: new.value)
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
                    dom.removeStyleProperty(node, name: String(decoding: oldKey, as: UTF8.self))
                }
            }
            return
        }

        guard let oldStylePairs else {
            for (newKey, newValue) in newStylePairs {
                dom.setStyleProperty(
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
                    dom.setStyleProperty(
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
        var oldStyles: [StylePair] = []
        oldStyles.reserveCapacity(4)
        if let firstOld {
            oldStyles.append(firstOld)
        }
        while let pair = oldIterator.next() {
            oldStyles.append(pair)
        }

        if let firstNew {
            applyStyle(firstNew, to: node, matching: &oldStyles)
        }
        while let pair = newIterator.next() {
            applyStyle(pair, to: node, matching: &oldStyles)
        }

        while let remaining = oldStyles.popLast() {
            removeStyles(named: remaining.key, from: &oldStyles)
            dom.removeStyleProperty(node, name: String(decoding: remaining.key, as: UTF8.self))
        }
    }

    private func applyStyle(
        _ new: StylePair,
        to node: DOM.Node,
        matching oldStyles: inout [StylePair]
    ) {
        if let oldValue = removeStyles(named: new.key, from: &oldStyles),
            oldValue.utf8Equals(new.value)
        {
            return
        }
        dom.setStyleProperty(
            node,
            name: String(decoding: new.key, as: UTF8.self),
            value: String(decoding: new.value, as: UTF8.self)
        )
    }

    @discardableResult
    private func removeStyles(
        named key: Substring.UTF8View,
        from oldStyles: inout [StylePair]
    ) -> Substring.UTF8View? {
        var oldValue: Substring.UTF8View?
        var index = oldStyles.count
        while index > 0 {
            index -= 1
            guard oldStyles[index].key.utf8Equals(key) else { continue }

            if oldValue == nil {
                oldValue = oldStyles[index].value
            }
            oldStyles.remove(at: index)
        }
        return oldValue
    }
}
