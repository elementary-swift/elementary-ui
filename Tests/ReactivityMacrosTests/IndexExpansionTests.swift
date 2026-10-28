import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import Testing

@testable import ReactivityMacros

struct IndexExpansionTests {
    @Test func indexesOnlyEligibleDirectProperties() throws {
        let declaration = DeclSyntax(
            """
            class Model {
                var first = 0
                @ReactiveIgnored var ignored = 0
                let constant = 0
                static var global = 0
                var computed: Int { first }
                var second = 0
                #if DEBUG
                var conditional = 0
                #endif
            }
            """
        ).cast(ClassDeclSyntax.self)
        let context = BasicMacroExpansionContext()
        let indices = try declaration.memberBlock.members.compactMap { member -> String? in
            guard let property = member.decl.as(VariableDeclSyntax.self) else { return nil }
            return try ReactiveMacro.expansion(
                of: AttributeSyntax("@Reactive"),
                attachedTo: declaration,
                providingAttributesFor: property,
                in: context
            ).first?.trimmedDescription
        }
        #expect(indices == ["@ReactiveProperty(propertyIndex: 0)", "@ReactiveProperty(propertyIndex: 1)"])
        let conditional = declaration.memberBlock.members.last!.decl.cast(IfConfigDeclSyntax.self)
            .clauses.first!.elements!.cast(MemberBlockItemListSyntax.self).first!.decl.cast(VariableDeclSyntax.self)
        let attributes = try ReactiveMacro.expansion(
            of: AttributeSyntax("@Reactive"),
            attachedTo: declaration,
            providingAttributesFor: conditional,
            in: context
        )
        #expect(attributes.map(\.trimmedDescription) == ["@ReactiveProperty"])
    }

    @Test func indexBecomesThePropertyIdentity() throws {
        let property = DeclSyntax("@ReactiveProperty(propertyIndex: 7) var value = 0").cast(VariableDeclSyntax.self)
        let attribute = AttributeSyntax("@ReactiveProperty(propertyIndex: 7)")
        let peers = try ReactivePropertyMacro.expansion(of: attribute, providingPeersOf: property, in: BasicMacroExpansionContext())
        #expect(peers.count == 2)
        #expect(peers[0].description.contains("_value"))
        #expect(peers[1].description.contains("PropertyID(7)"))
    }

    @Test func propertiesWithoutIndexKeepTheirName() throws {
        let property = DeclSyntax("var value = 0").cast(VariableDeclSyntax.self)
        let peers = try ReactivePropertyMacro.expansion(
            of: AttributeSyntax("@ReactiveProperty"),
            providingPeersOf: property,
            in: BasicMacroExpansionContext()
        )
        #expect(peers[1].description.contains("PropertyID(\"value\")"))
    }
}
