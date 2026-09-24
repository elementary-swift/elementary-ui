import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum CustomElementMacro {}

private struct CustomElementDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity = .error

    init(_ message: String, id: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "ElementaryWebComponents.CustomElement", id: id)
    }
}

private func customElementDiagnostic(
    at node: some SyntaxProtocol,
    _ message: String,
    id: String
) -> Diagnostic {
    Diagnostic(
        node: Syntax(node),
        message: CustomElementDiagnostic(message, id: id)
    )
}

private struct CustomElementAttributeDeclaration {
    let identifier: String
    let attributeName: String
    let defaultValue: String
}

extension CustomElementMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let attributes = try validateAndCollectAttributes(
            macroNode: node,
            declaration: declaration
        )
        let access = declaration.customElementAccessModifier
        let names = attributes.map { "\"\($0.attributeName)\"" }.joined(separator: ", ")
        let slots = attributes.map { attribute in
            "view._\(attribute.identifier).slot(named: \"\(attribute.attributeName)\", declarationDefault: \(attribute.defaultValue))"
        }.joined(separator: ",\n")

        return [
            DeclSyntax(
                """
                \(access)static var observedAttributes: [String] {
                    [\(raw: names)]
                }
                """
            ),
            DeclSyntax(
                """
                \(access)static func __attributes(from view: borrowing Self) -> ElementaryWebComponents._CustomElementAttributeStorage {
                    ElementaryWebComponents._CustomElementAttributeStorage([
                        \(raw: slots)
                    ])
                }
                """
            ),
        ]
    }
}

extension CustomElementMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard declaration.isValidCustomElementDeclarationShape else { return [] }
        return try ViewMacro.expansion(
            of: node,
            attachedTo: declaration,
            providingAttributesFor: member,
            in: context
        )
    }
}

extension CustomElementMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard (try? validateAndCollectAttributes(macroNode: node, declaration: declaration)) != nil else {
            return []
        }
        var extensions = try ViewMacro.expansion(
            of: node,
            attachedTo: declaration,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )

        extensions.append(
            try ExtensionDeclSyntax(
                """
                extension \(type): CustomElement {}
                """
            )
        )
        return extensions
    }
}

private func validateAndCollectAttributes(
    macroNode: AttributeSyntax,
    declaration: some DeclGroupSyntax
) throws -> [CustomElementAttributeDeclaration] {
    var diagnostics: [Diagnostic] = []

    guard declaration.is(StructDeclSyntax.self) else {
        throw DiagnosticsError(diagnostics: [
            customElementDiagnostic(
                at: macroNode,
                "'@CustomElement' can only be applied to a struct",
                id: "not-a-struct"
            )
        ])
    }

    let variables = declaration.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
    if variables.contains(where: { $0.isBodyProperty && $0.bodyReturnTypeContains("SVGView") }) {
        diagnostics.append(
            customElementDiagnostic(
                at: macroNode,
                "a custom element body must be an HTML View, not an SVGView",
                id: "svg-body"
            )
        )
    }

    var result: [CustomElementAttributeDeclaration] = []

    for property in variables where property.hasAttribute(named: "Attribute") {
        guard property.bindings.count == 1, let identifier = property.trimmedIdentifier?.text else {
            diagnostics.append(
                customElementDiagnostic(
                    at: property,
                    "'@Attribute' must be applied to a declaration containing one property",
                    id: "multiple-bindings"
                )
            )
            continue
        }

        guard property.isVar, property.isInstance, property.isStoredProperty else {
            diagnostics.append(
                customElementDiagnostic(
                    at: property,
                    "'@Attribute' requires a stored instance variable",
                    id: "invalid-property"
                )
            )
            continue
        }

        let binding = property.bindings.first!
        let isOptional = binding.typeAnnotation?.type.isOptionalAttributeType ?? false
        if binding.initializer == nil && !isOptional {
            diagnostics.append(
                customElementDiagnostic(
                    at: property,
                    "non-optional '@Attribute' property '\(identifier)' requires a default value",
                    id: "missing-default"
                )
            )
            continue
        }

        let attributeSyntax = property.attributes.compactMap { $0.as(AttributeSyntax.self) }
            .first { $0.trimmedName == "Attribute" }!
        let explicitName: String?
        do {
            explicitName = try attributeSyntax.explicitCustomElementAttributeName()
        } catch let diagnostic as CustomElementNameDiagnostic {
            diagnostics.append(
                customElementDiagnostic(
                    at: attributeSyntax,
                    diagnostic.message,
                    id: diagnostic.id
                )
            )
            continue
        }

        let attributeName = explicitName ?? kebabCase(identifier)
        guard isValidAttributeName(attributeName) else {
            diagnostics.append(
                customElementDiagnostic(
                    at: attributeSyntax,
                    "'\(attributeName)' is not a valid lowercase HTML attribute name",
                    id: "invalid-name"
                )
            )
            continue
        }

        if let previous = result.first(where: { $0.attributeName == attributeName }) {
            diagnostics.append(
                customElementDiagnostic(
                    at: property,
                    "attribute name '\(attributeName)' is already used by '\(previous.identifier)'",
                    id: "duplicate-name"
                )
            )
            continue
        }

        result.append(
            .init(
                identifier: identifier,
                attributeName: attributeName,
                defaultValue: binding.initializer?.value.trimmedDescription ?? "nil"
            )
        )
    }

    if !diagnostics.isEmpty {
        throw DiagnosticsError(diagnostics: diagnostics)
    }
    return result
}

private struct CustomElementNameDiagnostic: Error {
    let message: String
    let id: String
}

private extension AttributeSyntax {
    func explicitCustomElementAttributeName() throws -> String? {
        guard let arguments else { return nil }
        guard case .argumentList(let list) = arguments, list.count == 1,
            list.first?.label == nil,
            let literal = list.first?.expression.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            let segment = literal.segments.first?.as(StringSegmentSyntax.self)
        else {
            throw CustomElementNameDiagnostic(
                message: "'@Attribute' name must be a single unlabeled string literal",
                id: "nonliteral-name"
            )
        }
        return segment.content.text
    }
}

private extension TypeSyntax {
    var isOptionalAttributeType: Bool {
        if self.is(OptionalTypeSyntax.self) || self.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return true
        }
        guard let identifier = `as`(IdentifierTypeSyntax.self) else { return false }
        return identifier.name.text == "Optional"
    }
}

private extension DeclGroupSyntax {
    var isValidCustomElementDeclarationShape: Bool {
        guard self.is(StructDeclSyntax.self) else { return false }
        let variables = memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
        return !variables.contains { $0.isBodyProperty && $0.bodyReturnTypeContains("SVGView") }
    }

    var customElementAccessModifier: DeclModifierListSyntax {
        guard
            let access = modifiers.first(where: {
                $0.detail == nil && ($0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.package))
            })
        else {
            return []
        }
        return [access]
    }
}

private func kebabCase(_ value: String) -> String {
    let characters = Array(value)
    var result = ""

    for index in characters.indices {
        let character = characters[index]
        if character == "_" {
            if !result.isEmpty && result.last != "-" { result.append("-") }
            continue
        }

        if character.isUppercase {
            let previous = index > characters.startIndex ? characters[characters.index(before: index)] : nil
            let nextIndex = characters.index(after: index)
            let next = nextIndex < characters.endIndex ? characters[nextIndex] : nil
            let startsWord = previous?.isLowercase == true || previous?.isNumber == true
            let endsAcronym = previous?.isUppercase == true && next?.isLowercase == true
            if !result.isEmpty && (startsWord || endsAcronym) && result.last != "-" {
                result.append("-")
            }
            result.append(contentsOf: character.lowercased())
        } else {
            result.append(character)
        }
    }
    return result
}

private func isValidAttributeName(_ name: String) -> Bool {
    guard !name.isEmpty, name == name.lowercased() else { return false }
    let forbidden = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: "\"'>/=")
    )
    return name.unicodeScalars.allSatisfy { !forbidden.contains($0) && $0.value != 0 }
}
