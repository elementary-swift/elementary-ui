import Reactivity

// Type-erased node reference
enum DOM {
    // TODO: remove anyobject and make reconcier runs generic over this
    protocol Interactor: AnyObject {

        func makeEventSink(_ handler: @escaping (String, Event) -> Void) -> EventSink

        func makePropertyAccessor(_ node: Node, name: String) -> PropertyAccessor
        func makeStyleAccessor(_ node: Node, cssName: String) -> StyleAccessor
        func makeComputedStyleAccessor(_ node: Node) -> ComputedStyleAccessor
        func makeFocusAccessor(_ node: Node, onEvent: @escaping (FocusEvent) -> Void) -> FocusAccessor

        // Fine-grained style property operations
        func setStyleProperty(_ node: Node, name: String, value: String)
        func removeStyleProperty(_ node: Node, name: String)

        func createText(_ text: String) -> Node
        func createElement(_ element: String) -> Node

        // Low-level DOM-like attribute APIs
        func setAttribute(_ node: Node, name: String, value: String?)
        func removeAttribute(_ node: Node, name: String)

        func animateElement(_ element: Node, _ effect: Animation.KeyframeEffect, onFinish: @escaping () -> Void) -> Animation

        // Measurement API for FLIP animations
        func getBoundingClientRect(_ node: Node) -> Rect
        func getOffsetParent(_ node: Node) -> Node?

        // Scroll offset API for FLIP animations
        func getScrollOffset() -> (x: Double, y: Double)

        // Low-level DOM-like event listener APIs
        func addEventListener(_ node: Node, event: String, sink: EventSink)
        func removeEventListener(_ node: Node, event: String, sink: EventSink)
        func patchText(_ node: Node, with text: String)
        func replaceChildren(_ children: [Node], in parent: Node)
        // New explicit child list operations
        func insertChild(_ child: Node, before sibling: Node?, in parent: Node)
        func removeChild(_ child: Node, from parent: Node)

        // Document query APIs
        func querySelector(_ selector: String) -> Node?

        // TODO: these are more scheduling APIs, but they kind of fit here...
        func requestAnimationFrame(_ callback: @escaping (Double) -> Void)
        func queueMicrotask(_ callback: @escaping () -> Void)
        func setTimeout(_ callback: @escaping () -> Void, _ timeout: Double)
        func getCurrentTime() -> Double
    }
}

extension DOM.Interactor {
    func runNext(_ callback: @escaping () -> Void) {
        setTimeout(callback, 0)
    }

    func patchElementAttributes(
        _ node: DOM.Node,
        with attributes: _AttributeStorage,
        replacing: _AttributeStorage
    ) {
        // fast pass
        guard attributes != .none || replacing != .none else { return }

        var previous = replacing.flattened().reversed()
        for attribute in attributes.flattened() {
            if let previousIndex = previous.firstIndex(where: { $0.name.utf8Equals(attribute.name) }) {
                let oldValue = previous.remove(at: previousIndex)
                if !oldValue.value.utf8Equals(attribute.value) {
                    if attribute.name.utf8Equals("style") {
                        // TODO: really, really don't do this. expose the style dictionary from Elementary and use it directly
                        let oldMap = _parseInlineStyle(oldValue.value)
                        let newMap = _parseInlineStyle(attribute.value)
                        _applyInlineStyles(node, old: oldMap, new: newMap)
                    } else {

                        logTrace(
                            "updating attribute \(attribute.name) from \(oldValue.value ?? "") to \(attribute.value ?? "")"
                        )
                        setAttribute(node, name: attribute.name, value: attribute.value)
                    }
                }
            } else {
                if attribute.name.utf8Equals("style") {
                    let newMap = _parseInlineStyle(attribute.value)
                    _applyInlineStyles(node, old: [:], new: newMap)
                } else {
                    logTrace("setting attribute \(attribute.name) to \(attribute.value ?? "")")
                    setAttribute(node, name: attribute.name, value: attribute.value)
                }
            }
        }

        for attribute in previous {
            if attribute.name.utf8Equals("style") {
                let oldMap = _parseInlineStyle(attribute.value)
                _applyInlineStyles(node, old: oldMap, new: [:])
            } else {
                logTrace("removing attribute \(attribute.name)")
                removeAttribute(node, name: attribute.name)
            }
        }
    }
}

// NOTE: AI slop below, don't judge me
private func _isASCIISpace(_ byte: UInt8) -> Bool {
    // space, tab, LF, CR, FF
    byte == 32 || byte == 9 || byte == 10 || byte == 13 || byte == 12
}

func _parseInlineStyle(_ value: String?) -> [PropertyID: String] {
    guard let value, !value.isEmpty else { return [:] }
    var result: [PropertyID: String] = [:]

    let bytes = value.utf8
    var i = bytes.startIndex
    let end = bytes.endIndex

    let colon: UInt8 = 58  // ':'
    let semicolon: UInt8 = 59  // ';'

    var nameBuf: [UInt8] = []
    var valueBuf: [UInt8] = []

    while i < end {
        // skip leading whitespace
        while i < end, _isASCIISpace(bytes[i]) { i = bytes.index(after: i) }
        if i >= end { break }

        // read name
        nameBuf.removeAll(keepingCapacity: true)
        var nameLen = 0
        while i < end {
            let b = bytes[i]
            if b == colon || b == semicolon { break }
            nameBuf.append(b)
            if !_isASCIISpace(b) { nameLen = nameBuf.count }
            i = bytes.index(after: i)
        }
        if nameLen < nameBuf.count { nameBuf.removeLast(nameBuf.count - nameLen) }

        // check for value
        var hasValue = false
        if i < end, bytes[i] == colon {
            hasValue = true
            i = bytes.index(after: i)  // skip ':'
        } else {
            // skip until semicolon or end
            while i < end, bytes[i] != semicolon { i = bytes.index(after: i) }
        }

        valueBuf.removeAll(keepingCapacity: true)
        var valueLen = 0
        if hasValue {
            // skip whitespace after ':'
            while i < end, _isASCIISpace(bytes[i]) { i = bytes.index(after: i) }
            while i < end, bytes[i] != semicolon {
                let b = bytes[i]
                valueBuf.append(b)
                if !_isASCIISpace(b) { valueLen = valueBuf.count }
                i = bytes.index(after: i)
            }
            if valueLen < valueBuf.count { valueBuf.removeLast(valueBuf.count - valueLen) }
        }

        if !nameBuf.isEmpty {
            let nameString = String(decoding: nameBuf, as: UTF8.self)
            let valueString = String(decoding: valueBuf, as: UTF8.self)
            if !nameString.isEmpty {
                result[PropertyID(nameString)] = valueString
            }
        }

        // skip semicolon if present
        if i < end, bytes[i] == semicolon {
            i = bytes.index(after: i)
        }
    }

    return result
}

private extension DOM.Interactor {
    func _applyInlineStyles(_ node: DOM.Node, old: [PropertyID: String], new: [PropertyID: String]) {
        // Set or update
        for (k, v) in new {
            if let ov = old[k] {
                if !ov.utf8Equals(v) {
                    setStyleProperty(node, name: k.description, value: v)
                }
            } else {
                setStyleProperty(node, name: k.description, value: v)
            }
        }
        // Removals
        for (k, _) in old {
            if new[k] == nil {
                removeStyleProperty(node, name: k.description)
            }
        }
    }
}
