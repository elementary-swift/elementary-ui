import BasicContainers
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
        attributes._withSpan { attributes in
            for index in attributes.indices {
                addAttribute(attributes[unchecked: index], to: node)
            }
        }
    }

    func applyHTMLAttributes(_ node: DOM.Node, from previousAttributes: _AttributeStorage, to newAttributes: _AttributeStorage) {
        previousAttributes._withSpan { oldAttributes in
            newAttributes._withSpan { newAttributes in
                applyAttributeChanges(node, from: oldAttributes, to: newAttributes)
            }
        }
    }

    // NOTE: attribute names are unique within each span, so attributes can be matched by name without bookkeeping
    private func applyAttributeChanges(
        _ node: DOM.Node,
        from oldAttributes: Span<_StoredAttribute>,
        to newAttributes: Span<_StoredAttribute>
    ) {
        // fast path: the same attributes in the same order
        let commonCount = min(oldAttributes.count, newAttributes.count)
        var index = 0
        while index < commonCount, oldAttributes[unchecked: index].name.utf8Equals(newAttributes[unchecked: index].name) {
            applyAttributeChange(oldAttributes[unchecked: index], newAttributes[unchecked: index], to: node)
            index &+= 1
        }

        guard index < oldAttributes.count || index < newAttributes.count else { return }

        // slow path: match the remaining attributes by name
        var newIndex = index
        while newIndex < newAttributes.count {
            let new = newAttributes[unchecked: newIndex]
            if let oldIndex = oldAttributes.firstIndex(named: new.name, from: index) {
                applyAttributeChange(oldAttributes[unchecked: oldIndex], new, to: node)
            } else {
                addAttribute(new, to: node)
            }
            newIndex &+= 1
        }

        var oldIndex = index
        while oldIndex < oldAttributes.count {
            let old = oldAttributes[unchecked: oldIndex]
            if newAttributes.firstIndex(named: old.name, from: index) == nil {
                removeAttribute(old, from: node)
            }
            oldIndex &+= 1
        }
    }

    private func addAttribute(_ new: borrowing _StoredAttribute, to node: DOM.Node) {
        if let newStyle = new._styleKeyValuePairs {
            applyStyleChanges(node, from: nil, to: newStyle)
        } else {
            dom.setAttribute(node, name: new.name, value: new.value)
        }
    }

    private func applyAttributeChange(_ old: borrowing _StoredAttribute, _ new: borrowing _StoredAttribute, to node: DOM.Node) {
        // skips flattening classes and parsing styles for unchanged values
        guard !old._hasKnownEqualValue(to: new) else { return }

        let oldStyle = old._styleKeyValuePairs
        let newStyle = new._styleKeyValuePairs
        if oldStyle != nil || newStyle != nil {
            applyStyleChanges(node, from: oldStyle, to: newStyle)
        } else if !old.value.utf8Equals(new.value) {
            logTrace("updating attribute \(new.name) from \(old.value ?? "") to \(new.value ?? "")")
            dom.setAttribute(node, name: new.name, value: new.value)
        }
    }

    private func removeAttribute(_ old: borrowing _StoredAttribute, from node: DOM.Node) {
        if let oldStylePairs = old._styleKeyValuePairs {
            applyStyleChanges(node, from: oldStylePairs, to: nil)
        } else {
            logTrace("removing attribute \(old.name)")
            dom.removeAttribute(node, name: old.name)
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
                    dom.removeStyleProperty(node, name: String(Substring(oldKey)))
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
        var oldStyles = UniqueArray<StylePair>()
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
            dom.removeStyleProperty(node, name: String(Substring(remaining.key)))
        }
    }

    private func applyStyle(
        _ new: StylePair,
        to node: DOM.Node,
        matching oldStyles: inout UniqueArray<StylePair>
    ) {
        if let oldValue = removeStyles(named: new.key, from: &oldStyles),
            oldValue.utf8Equals(new.value)
        {
            return
        }
        dom.setStyleProperty(
            node,
            name: String(Substring(new.key)),
            value: String(Substring(new.value))
        )
    }

    @discardableResult
    private func removeStyles(
        named key: Substring.UTF8View,
        from oldStyles: inout UniqueArray<StylePair>
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

private extension Span<_StoredAttribute> {
    func firstIndex(named name: borrowing String, from start: Int) -> Int? {
        var index = start
        while index < count {
            if self[unchecked: index].name.utf8Equals(name) {
                return index
            }
            index &+= 1
        }
        return nil
    }
}
