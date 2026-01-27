import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum EntryMacro {}

// TODO: don't allow static vars, don't allow lets
// TODO: diagnostics for missing initializer expressions and accessor blocks

extension EntryMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
            property.isValidEntry,
            let identifier = property.trimmedIdentifier
        else {
            return []
        }

        let keyPropertyName = "Self.\(keyName(for: identifier.text))"

        return [
            "get { self[\(raw: keyPropertyName)] }",
            "set { self[\(raw: keyPropertyName)] = newValue }",
        ]
    }
}

extension EntryMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
            property.isValidEntry,
            let identifier = property.trimmedIdentifier,
            let binding = property.bindings.first
        else {
            return []
        }

        let uniqueName = context.makeUniqueName(identifier.text)

        var keyType: TokenSyntax
        if let typeAnnotation = binding.typeAnnotation {
            keyType = "_Key<\(typeAnnotation.type)>"
        } else {
            keyType = "_Key"
        }

        if let initializer = binding.initializer {
            return [
                DeclSyntax(
                    """
                    \(property.modifiers) static let \(raw: keyName(for: identifier.text)) = \(keyType)(
                        "\(uniqueName)", 
                        defaultValue: \(initializer.value)
                    )
                    """
                )
            ]
        } else {
            return [
                DeclSyntax(
                    """
                    \(property.modifiers) static let \(raw: keyName(for: identifier.text)) = \(keyType)("\(uniqueName)")
                    """
                )
            ]
        }
    }
}

enum EnvironmentKeyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        try AnyKeyMacro.expansion(for: "EnvironmentValues", of: node, in: context)
    }
}

enum AnyKeyMacro {
    public static func expansion(
        for baseType: String,
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard
            let keyPath = node.arguments.first?.expression.as(KeyPathExprSyntax.self),
            let propertyName = keyPath.components.first?.component.trimmedDescription
        else {
            // TODO: diagnostics
            return ""
        }

        return "\(raw: baseType).\(raw: keyName(for: propertyName))"
    }
}

private extension VariableDeclSyntax {
    var isValidEntry: Bool {
        // TODO: check some stuff
        true
    }
}

func keyName(for identifier: String) -> String { "_$key_\(identifier)" }
