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
            var dict = [MountedInstance.StyleKey: Substring.UTF8View]()
            dict[.init(""[...].utf8)] = ""[...].utf8
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
        fileprivate struct StyleKey: Hashable {
            let raw: Substring.UTF8View

            init(_ raw: Substring.UTF8View) {
                self.raw = raw
            }

            static func == (lhs: StyleKey, rhs: StyleKey) -> Bool {
                lhs.raw.elementsEqual(rhs.raw)
            }

            func hash(into hasher: inout Hasher) {
                raw.withContiguousStorageIfAvailable {
                    hasher.combine(bytes: UnsafeRawBufferPointer($0))
                }
            }

            var stringValue: String {
                String(raw)
            }
        }

        let modifier: _AttributeModifier
        let node: DOM.Node

        var isDirty: Bool = false
        var previousAttributes: _AttributeStorage = .none
        private var cachedStylePairs: _StoredAttribute._StyleKeyValuePairs?

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

            var previous = previousAttributes.flattened().reversed()
            var newStylePairs: _StoredAttribute._StyleKeyValuePairs?

            for attribute in attributes.flattened() {
                if let pairs = attribute._styleKeyValuePairs {
                    newStylePairs = pairs
                    if let idx = previous.firstIndex(where: { $0._styleKeyValuePairs != nil }) {
                        previous.remove(at: idx)
                    }
                } else if let idx = previous.firstIndex(where: { $0.name.utf8Equals(attribute.name) }) {
                    let old = previous.remove(at: idx)
                    if !old.value.utf8Equals(attribute.value) {
                        logTrace("updating attribute \(attribute.name) from \(old.value ?? "") to \(attribute.value ?? "")")
                        dom.setAttribute(node, name: attribute.name, value: attribute.value)
                    }
                } else {
                    logTrace("setting attribute \(attribute.name) to \(attribute.value ?? "")")
                    dom.setAttribute(node, name: attribute.name, value: attribute.value)
                }
            }

            for attribute in previous where attribute._styleKeyValuePairs == nil {
                logTrace("removing attribute \(attribute.name)")
                dom.removeAttribute(node, name: attribute.name)
            }

            applyStyleChanges(newStylePairs, on: dom)
            previousAttributes = attributes
        }

        private func applyStyleChanges(_ newStylePairs: _StoredAttribute._StyleKeyValuePairs?, on dom: any DOM.Interactor) {
            let oldStylePairs = cachedStylePairs

            guard let newStylePairs else {
                if let oldStylePairs {
                    for (oldKey, _) in oldStylePairs {
                        dom.removeStyleProperty(node, name: String(oldKey))
                    }
                }
                cachedStylePairs = nil
                return
            }

            guard let oldStylePairs else {
                for (newKey, newValue) in newStylePairs {
                    dom.setStyleProperty(node, name: String(newKey), value: String(newValue))
                }
                cachedStylePairs = newStylePairs
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
                        applyStyleFallback(
                            firstOld: oldPair,
                            oldIterator: &oldIterator,
                            firstNew: newPair,
                            newIterator: &newIterator,
                            on: dom
                        )
                        cachedStylePairs = newStylePairs
                        return
                    }

                    if !oldPair.value.elementsEqual(newPair.value) {
                        dom.setStyleProperty(node, name: String(newPair.key), value: String(newPair.value))
                    }
                case (.none, .none):
                    cachedStylePairs = newStylePairs
                    return
                default:
                    applyStyleFallback(
                        firstOld: oldNext,
                        oldIterator: &oldIterator,
                        firstNew: newNext,
                        newIterator: &newIterator,
                        on: dom
                    )
                    cachedStylePairs = newStylePairs
                    return
                }
            }
        }

        private func applyStyleFallback(
            firstOld: (key: Substring.UTF8View, value: Substring.UTF8View)?,
            oldIterator: inout _StoredAttribute._StyleKeyValuePairs.Iterator,
            firstNew: (key: Substring.UTF8View, value: Substring.UTF8View)?,
            newIterator: inout _StoredAttribute._StyleKeyValuePairs.Iterator,
            on dom: any DOM.Interactor
        ) {
            var oldByKey: [StyleKey: Substring.UTF8View] = [:]
            if let firstOld {
                oldByKey[StyleKey(firstOld.key)] = firstOld.value
            }
            while let oldPair = oldIterator.next() {
                oldByKey[StyleKey(oldPair.key)] = oldPair.value
            }

            func apply(_ newPair: (key: Substring.UTF8View, value: Substring.UTF8View)) {
                let key = StyleKey(newPair.key)
                if let oldValue = oldByKey.removeValue(forKey: key) {
                    if !oldValue.elementsEqual(newPair.value) {
                        dom.setStyleProperty(node, name: key.stringValue, value: String(newPair.value))
                    }
                } else {
                    dom.setStyleProperty(node, name: key.stringValue, value: String(newPair.value))
                }
            }

            if let firstNew {
                apply(firstNew)
            }
            while let newPair = newIterator.next() {
                apply(newPair)
            }

            for remainingKey in oldByKey.keys {
                dom.removeStyleProperty(node, name: remainingKey.stringValue)
            }
        }

    }
}

private extension String {
    init(_ content: Substring.UTF8View) {
        self = String(Substring(content))
    }
}
