import struct Reactivity.HashableUTF8View

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

    init(value: consuming Value, upstream: borrowing DOMElementModifiers, _ context: inout _TransactionContext) {
        self.lastValue = value
        self.upstream = upstream[_AttributeModifier.key]
        self.upstream?.tracker.addDependency(self)

        #if hasFeature(Embedded)
        if __omg_this_was_annoying_I_am_false {
            // this is to force inclusion of types
            _ = p {}.attributes(.class([""]), .style(["": ""]))
            var f = [HashableUTF8View: _StoredAttribute]()
            f[HashableUTF8View("")] = .none
            var u = [HashableUTF8View: Substring.UTF8View]()
            u[HashableUTF8View("")] = .none
        }
        #endif
    }

    func updateValue(_ value: consuming Value, _ context: inout _TransactionContext) {
        if value != lastValue {
            lastValue = value
            tracker.invalidateAll(&context)
        }
    }

    func mount(_ node: DOM.Node, _ context: inout _CommitContext) -> AnyUnmountable {
        logTrace("mounting attribute modifier")
        return AnyUnmountable(MountedInstance(node, self, &context))
    }

    func invalidate(_ context: inout _TransactionContext) {
        self.tracker.invalidateAll(&context)
    }
}

extension _AttributeModifier {
    final class MountedInstance: Unmountable, Invalidateable {
        private typealias StylePair = (key: Substring.UTF8View, value: Substring.UTF8View)

        let modifier: _AttributeModifier
        let node: DOM.Node

        var isDirty: Bool = false
        var previousAttributes: _AttributeStorage = .none

        init(_ node: DOM.Node, _ modifier: _AttributeModifier, _ context: inout _CommitContext) {
            self.node = node
            self.modifier = modifier
            self.modifier.tracker.addDependency(self)
            updateDOMNode(&context)
        }

        func invalidate(_ context: inout _TransactionContext) {
            guard !isDirty else { return }
            logTrace("invalidating attribute modifier")
            isDirty = true
            context.scheduler.addCommitAction(updateDOMNode(_:))
        }

        func updateDOMNode(_ context: inout _CommitContext) {
            logTrace("updating attribute modifier")
            patchAttributes(with: modifier.value, on: context.dom)
            isDirty = false
        }

        func unmount(_ context: inout _CommitContext) {
            logTrace("unmounting attribute modifier")
            self.modifier.tracker.removeDependency(self)
        }

        // MARK: - Attribute patching

        private func patchAttributes(with attributes: _AttributeStorage, on dom: any DOM.Interactor) {
            guard attributes != .none || previousAttributes != .none else { return }

            var oldIterator = previousAttributes.flattened().makeIterator()
            var newIterator = attributes.flattened().makeIterator()
            applyAttributeChanges(
                oldIterator: &oldIterator,
                newIterator: &newIterator,
                on: dom
            )
            previousAttributes = attributes
        }

        private func applyAttributeChanges(
            oldIterator: inout _MergedAttributes.Iterator,
            newIterator: inout _MergedAttributes.Iterator,
            on dom: any DOM.Interactor
        ) {
            while true {
                let oldNext = oldIterator.next()
                let newNext = newIterator.next()

                switch (oldNext, newNext) {
                case let (.some(old), .some(new)):
                    guard old.name.utf8Equals(new.name) else {
                        applyAttributesSlowPath(
                            firstOld: old,
                            oldIterator: &oldIterator,
                            firstNew: new,
                            newIterator: &newIterator,
                            on: dom
                        )
                        return
                    }

                    let oldStyle = old._styleKeyValuePairs
                    let newStyle = new._styleKeyValuePairs
                    if oldStyle != nil || newStyle != nil {
                        applyStyleChanges(from: oldStyle, to: newStyle, on: dom)
                    } else if !old.value.utf8Equals(new.value) {
                        logTrace("updating attribute \(new.name) from \(old.value ?? "") to \(new.value ?? "")")
                        dom.setAttribute(node, name: new.name, value: new.value)
                    }
                case (.none, .none):
                    return
                default:
                    applyAttributesSlowPath(
                        firstOld: oldNext,
                        oldIterator: &oldIterator,
                        firstNew: newNext,
                        newIterator: &newIterator,
                        on: dom
                    )
                    return
                }
            }
        }

        private func applyAttributesSlowPath(
            firstOld: _StoredAttribute?,
            oldIterator: inout _MergedAttributes.Iterator,
            firstNew: _StoredAttribute?,
            newIterator: inout _MergedAttributes.Iterator,
            on dom: any DOM.Interactor
        ) {
            var oldByKey: [HashableUTF8View: _StoredAttribute] = [:]
            if let firstOld {
                oldByKey[HashableUTF8View(firstOld.name)] = firstOld
            }
            while let old = oldIterator.next() {
                oldByKey[HashableUTF8View(old.name)] = old
            }

            func apply(_ new: _StoredAttribute) {
                let key = HashableUTF8View(new.name)
                let old = oldByKey.removeValue(forKey: key)
                let oldStyle = old?._styleKeyValuePairs
                let newStyle = new._styleKeyValuePairs
                if oldStyle != nil || newStyle != nil {
                    applyStyleChanges(from: oldStyle, to: newStyle, on: dom)
                } else if old == nil || !old!.value.utf8Equals(new.value) {
                    dom.setAttribute(node, name: new.name, value: new.value)
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
                    applyStyleChanges(from: oldStylePairs, to: nil, on: dom)
                } else {
                    logTrace("removing attribute \(old.name)")
                    dom.removeAttribute(node, name: old.name)
                }
            }
        }

        private func applyStyleChanges(
            from oldStylePairs: _StoredAttribute._StyleKeyValuePairs?,
            to newStylePairs: _StoredAttribute._StyleKeyValuePairs?,
            on dom: any DOM.Interactor
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
                        name: String(decoding: newKey, as: UTF8.self),
                        value: String(decoding: newValue, as: UTF8.self)
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
                    guard oldPair.key.elementsEqual(newPair.key) else {
                        applyStylesSlowPath(
                            firstOld: oldPair,
                            oldIterator: &oldIterator,
                            firstNew: newPair,
                            newIterator: &newIterator,
                            on: dom
                        )
                        return
                    }

                    if !oldPair.value.elementsEqual(newPair.value) {
                        dom.setStyleProperty(
                            node,
                            name: String(decoding: newPair.key, as: UTF8.self),
                            value: String(decoding: newPair.value, as: UTF8.self)
                        )
                    }
                case (.none, .none):
                    return
                default:
                    applyStylesSlowPath(
                        firstOld: oldNext,
                        oldIterator: &oldIterator,
                        firstNew: newNext,
                        newIterator: &newIterator,
                        on: dom
                    )
                    return
                }
            }
        }

        private func applyStylesSlowPath(
            firstOld: StylePair?,
            oldIterator: inout _StoredAttribute._StyleKeyValuePairs.Iterator,
            firstNew: StylePair?,
            newIterator: inout _StoredAttribute._StyleKeyValuePairs.Iterator,
            on dom: any DOM.Interactor
        ) {
            var oldByKey: [HashableUTF8View: Substring.UTF8View] = [:]
            if let firstOld {
                oldByKey[HashableUTF8View(firstOld.key)] = firstOld.value
            }
            while let pair = oldIterator.next() {
                oldByKey[HashableUTF8View(pair.key)] = pair.value
            }

            func apply(_ pair: StylePair) {
                let key = HashableUTF8View(pair.key)
                if let oldValue = oldByKey.removeValue(forKey: key), oldValue.elementsEqual(pair.value) { return }
                dom.setStyleProperty(node, name: key.stringValue, value: String(decoding: pair.value, as: UTF8.self))
            }

            if let firstNew {
                apply(firstNew)
            }
            while let pair = newIterator.next() {
                apply(pair)
            }

            for remainingKey in oldByKey.keys {
                dom.removeStyleProperty(node, name: remainingKey.stringValue)
            }
        }

    }
}
