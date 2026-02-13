import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum ViewMacro {}

let skippableAttributesForEquating = Set<String>([
    "Environment",
    "State",
    "ViewEquatableIgnored",
    "FocusState",
])

let wrappingAttributesForEquating = Set<String>([
    "Binding"
])

extension ViewMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard !protocols.isEmpty else { return [] }

        var result: [ExtensionDeclSyntax] = []

        let needsFunctionView = protocols.contains { $0.trimmed.description == "__FunctionView" }
        let needsViewEquatable = protocols.contains { $0.trimmed.description == "__ViewEquatable" }
        let members = declaration.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }

        // add _StatefulView conformance if any @State member is declared
        if needsFunctionView {
            var decls: [DeclSyntax] = []

            // add loading environment properties
            let environmentLoads =
                members
                .filter { $0.isEnvironmentProperty }
                .map { variable -> DeclSyntax in
                    let name = variable.trimmedIdentifier!.text
                    return "view._\(raw: name).__load(from: context)"
                }

            decls.append(
                DeclSyntax(
                    """
                    static func __applyContext(_ context: borrowing _ViewContext, to view: inout Self) {
                        \(raw: environmentLoads.map { $0.description }.joined(separator: "\n"))
                    }
                    """
                )
            )

            // add state members
            let stateMembers = members.filter { $0.isStateProperty }
            if !stateMembers.isEmpty {
                var initCalls: [DeclSyntax] = []
                var restoreCalls: [DeclSyntax] = []

                for (index, member) in stateMembers.enumerated() {
                    let name = member.trimmedIdentifier!.text

                    initCalls.append("view._\(raw: name).__initializeState(storage: storage, index: \(raw: index))")
                    restoreCalls.append("view._\(raw: name).__restoreState(storage: storage, index: \(raw: index))")
                }

                decls.append(
                    DeclSyntax(
                        """
                        static func __initializeState(from view: borrowing Self) -> _ViewStateStorage {
                            let storage = _ViewStateStorage()
                            storage.reserveCapacity(\(raw: stateMembers.count))
                            \(raw: initCalls.map { $0.description }.joined(separator: "\n"))
                            return storage
                        }
                        """
                    )
                )
                decls.append(
                    DeclSyntax(
                        """
                        static func __restoreState(_ storage: _ViewStateStorage, in view: inout Self) {
                            \(raw: restoreCalls.map { $0.description }.joined(separator: "\n"))
                        }
                        """
                    )
                )
            } else {
                decls.append(
                    DeclSyntax(
                        """
                        typealias __ViewState = Void
                        """
                    )
                )
            }

            let extensionDecl: DeclSyntax = """
                extension \(raw: type.trimmedDescription): __FunctionView {
                    //typealias _MountedNode = _FunctionNode<Self, Self.Content._MountedNode>
                    
                    \(raw: decls.map { $0.description }.joined(separator: "\n"))
                }
                """

            result.append(extensionDecl.cast(ExtensionDeclSyntax.self))
        }

        if needsViewEquatable {
            let properties = members
                .lazy
                .filter { $0.isStoredProperty }
                .filter { !$0.hasAnyAttribute(named: skippableAttributesForEquating) }

            let shouldNotEvenTry = properties.contains(where: { $0.isKnownToBeClosure })

            if !shouldNotEvenTry {
                let propDecls = properties.map { property in
                    let shouldUnderscore = property.hasAnyAttribute(named: wrappingAttributesForEquating)

                    let name = shouldUnderscore ? "_\(property.trimmedIdentifier!.text)" : property.trimmedIdentifier!.text
                    return DeclSyntax("&& __ViewProperty.areKnownEqual(a.\(raw: name), b.\(raw: name))")
                }

                try result.append(
                    ExtensionDeclSyntax(
                        """
                        extension \(raw: type.trimmedDescription): __ViewEquatable {
                            static func __arePropertiesEqual(a: Self, b: Self) -> Bool {
                                return true 
                                \(raw: propDecls.map { $0.description }.joined(separator: "\n"))
                            }
                        }
                        """
                    )
                )
            }
        }

        return result
    }
}

extension ViewMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let variable = member.as(VariableDeclSyntax.self), variable.isBodyProperty else {
            return []
        }

        return [AttributeSyntax("@HTMLBuilder")]
    }
}

extension VariableDeclSyntax {
    var isVar: Bool {
        bindingSpecifier.trimmed.text == "var"
    }

    var isBodyProperty: Bool {
        guard isVar, let trimmedIdentifier else { return false }

        return trimmedIdentifier.text == "body"
    }

    var trimmedIdentifier: TokenSyntax? {
        bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed
    }

    var isStateProperty: Bool {
        isVar && (hasAttribute(named: "State") || hasAttribute(named: "FocusState"))
    }

    var isEnvironmentProperty: Bool {
        isVar && hasAttribute(named: "Environment")
    }

    var isInstance: Bool {
        for modifier in modifiers {
            for token in modifier.tokens(viewMode: .all) {
                if token.tokenKind == .keyword(.static) || token.tokenKind == .keyword(.class) {
                    return false
                }
            }
        }
        return true
    }

    var isStoredProperty: Bool {
        guard isInstance else { return false }

        for binding in bindings {
            if let accessorBlock = binding.accessorBlock {
                switch accessorBlock.accessors {
                case .getter:
                    return false
                case .accessors(let accessorList):
                    for accessor in accessorList {
                        let specifier = accessor.accessorSpecifier.trimmed.text
                        if specifier == "get" || specifier == "set" {
                            return false
                        }
                    }
                    continue
                }
            }
        }
        return true
    }

    var isKnownToBeClosure: Bool {
        guard var type = bindings.first?.typeAnnotation?.type else { return false }

        if let optType = type.as(OptionalTypeSyntax.self) {
            type = optType.wrappedType
        } else if let optType = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            type = optType.wrappedType
        }

        return type.is(FunctionTypeSyntax.self)
    }

    func hasAttribute(named name: String) -> Bool {
        attributes.contains { a in a.as(AttributeSyntax.self)?.trimmedName == name }
    }

    func hasAnyAttribute(named name: Set<String>) -> Bool {
        attributes.contains { a in name.contains(a.as(AttributeSyntax.self)?.trimmedName ?? "") }
    }
}

extension AttributeSyntax {
    var trimmedName: String? {
        attributeName.as(IdentifierTypeSyntax.self)?.name.trimmed.text
    }
}
