import SwiftSyntax
import SwiftSyntaxMacros

// marker only: the @View macro skips attributed properties when generating __arePropertiesEqual
public enum ViewEquatableIgnoredMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
