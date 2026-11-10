import BasicContainers
import _UTF8Internals

/// Attributes for the elements below it, combined with the attributes of the modifier above.
///
/// An element gets its own modifier on top of the inherited one and mounts only that, so a
/// mounted modifier belongs to exactly one element. Modifiers that are not mounted only pass
/// their changes down.
final class AttributeModifier: DependencyNode, DOMElementModifier {
    typealias Value = _AttributeStorage

    let upstream: AttributeModifier?

    private var lastValue: Value
    private var mountedNode: DOM.Node?
    private var previousAttributes: _AttributeStorage = .none
    private var isDirty = false

    var value: Value {
        var combined = lastValue
        combined.append(upstream?.value ?? .none)
        return combined
    }

    /// Follows the inherited modifier until the enclosing slot is dropped.
    init(value: consuming Value, upstream: borrowing DOMElementModifiers, ctx: inout _MountContext) {
        self.lastValue = value
        self.upstream = upstream[AttributeModifier.key]
        super.init()
        if let upstream = self.upstream {
            ctx.follow(upstream, with: self)
        }
    }

    // inline(never): keeps the change check out of every element patch (code size)
    @inline(never)
    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        if value != lastValue {
            lastValue = value
            invalidate(&context)
        }
    }

    func mount(_ node: DOM.Node, _ context: inout _MountContext) {
        logTrace("mounting attribute modifier")
        precondition(mountedNode == nil, "attribute modifier mounted twice")
        mountedNode = node
        let initialValue = value
        addHTMLAttributes(initialValue, to: node, using: context.dom)
        previousAttributes = initialValue
    }

    override func invalidate(_ context: inout _TransactionContext) {
        dependents.invalidateAll(&context)
        guard mountedNode != nil, !isDirty else { return }
        logTrace("invalidating attribute modifier")
        isDirty = true
        context.scheduler.addCommitAction(updateDOMNode(_:))
    }

    private func updateDOMNode(_ context: inout _CommitContext) {
        logTrace("updating attribute modifier")
        let newValue = value
        applyHTMLAttributes(from: previousAttributes, to: newValue, on: mountedNode!, using: context.dom)
        previousAttributes = newValue
        isDirty = false
    }
}

/// The mounted state of attributes applied to content; keeps the modifier type internal.
public struct _AttributedContentState {
    let modifier: AttributeModifier
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
        // NOTE: rare false negatives (equal values built differently) only cause a redundant setAttribute
        guard !old._hasKnownEqualValue(to: new) else { return }

        let oldStyle = old._styleKeyValuePairs
        let newStyle = new._styleKeyValuePairs
        if oldStyle != nil || newStyle != nil {
            applyStyleChanges(node, from: oldStyle, to: newStyle)
        } else {
            logTrace("updating attribute \(new.name)")
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
