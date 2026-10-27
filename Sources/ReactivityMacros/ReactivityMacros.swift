// original name: ObservableMacros.swift
// adjusted and renamed to match reactivity module

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum ReactiveMacro {
    static let moduleName = "Reactivity"

    static let conformanceName = "ReactiveObject"
    static var qualifiedConformanceName: String {
        "\(moduleName).\(conformanceName)"
    }

    static var observableConformanceType: TypeSyntax {
        "\(raw: qualifiedConformanceName)"
    }

    static let registrarTypeName = "ReactivityRegistrar"
    static var qualifiedRegistrarTypeName: String {
        "\(moduleName).\(registrarTypeName)"
    }

    static let trackedMacroName = "ReactiveProperty"
    static let ignoredMacroName = "ReactiveIgnored"

    static let registrarVariableName = "_$reactivity"

    static func registrarVariable(_: TokenSyntax) -> DeclSyntax {

        """
        @\(raw: ignoredMacroName) private let \(raw: registrarVariableName) = \(raw: qualifiedRegistrarTypeName)()
        """
    }

    static var ignoredAttribute: AttributeSyntax {
        AttributeSyntax(
            leadingTrivia: .space,
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier(ignoredMacroName)),
            trailingTrivia: .space
        )
    }
}

struct ObservationDiagnostic: DiagnosticMessage {
    enum ID: String {
        case invalidApplication = "invalid type"
        case missingInitializer = "missing initializer"
    }

    var message: String
    var diagnosticID: MessageID
    var severity: DiagnosticSeverity

    init(message: String, diagnosticID: SwiftDiagnostics.MessageID, severity: SwiftDiagnostics.DiagnosticSeverity = .error) {
        self.message = message
        self.diagnosticID = diagnosticID
        self.severity = severity
    }

    init(message: String, domain: String, id: ID, severity: SwiftDiagnostics.DiagnosticSeverity = .error) {
        self.message = message
        diagnosticID = MessageID(domain: domain, id: id.rawValue)
        self.severity = severity
    }
}

extension DiagnosticsError {
    init<S: SyntaxProtocol>(
        syntax: S,
        message: String,
        domain: String = "Observation",
        id: ObservationDiagnostic.ID,
        severity: SwiftDiagnostics.DiagnosticSeverity = .error
    ) {
        self.init(diagnostics: [
            Diagnostic(node: Syntax(syntax), message: ObservationDiagnostic(message: message, domain: domain, id: id, severity: severity))
        ])
    }
}

extension DeclModifierListSyntax {
    func privatePrefixed(_: String) -> DeclModifierListSyntax {
        let modifier = DeclModifierSyntax(name: "private", trailingTrivia: .space)
        return [modifier]
            + filter {
                switch $0.name.tokenKind {
                case let .keyword(keyword):
                    switch keyword {
                    case .fileprivate, .private, .internal, .package, .public:
                        return false
                    default:
                        return true
                    }
                default:
                    return true
                }
            }
    }

    init(keyword: Keyword) {
        self.init([DeclModifierSyntax(name: .keyword(keyword))])
    }
}

extension TokenSyntax {
    func privatePrefixed(_ prefix: String) -> TokenSyntax {
        switch tokenKind {
        case let .identifier(identifier):
            return TokenSyntax(
                .identifier(prefix + identifier),
                leadingTrivia: leadingTrivia,
                trailingTrivia: trailingTrivia,
                presence: presence
            )
        default:
            return self
        }
    }
}

extension PatternBindingListSyntax {
    func privatePrefixed(_ prefix: String) -> PatternBindingListSyntax {
        var bindings = map { $0 }
        for index in 0..<bindings.count {
            let binding = bindings[index]
            if let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
                bindings[index] = PatternBindingSyntax(
                    leadingTrivia: binding.leadingTrivia,
                    pattern: IdentifierPatternSyntax(
                        leadingTrivia: identifier.leadingTrivia,
                        identifier: identifier.identifier.privatePrefixed(prefix),
                        trailingTrivia: identifier.trailingTrivia
                    ),
                    typeAnnotation: binding.typeAnnotation,
                    initializer: binding.initializer,
                    accessorBlock: binding.accessorBlock,
                    trailingComma: binding.trailingComma,
                    trailingTrivia: binding.trailingTrivia
                )
            }
        }

        return PatternBindingListSyntax(bindings)
    }
}

extension VariableDeclSyntax {
    func privatePrefixed(_ prefix: String, addingAttribute attribute: AttributeSyntax) -> VariableDeclSyntax {
        let newAttributes = attributes + [.attribute(attribute)]
        return VariableDeclSyntax(
            leadingTrivia: leadingTrivia,
            attributes: newAttributes,
            modifiers: modifiers.privatePrefixed(prefix),
            bindingSpecifier: TokenSyntax(bindingSpecifier.tokenKind, leadingTrivia: .space, trailingTrivia: .space, presence: .present),
            bindings: bindings.privatePrefixed(prefix),
            trailingTrivia: trailingTrivia
        )
    }

    var isValidForObservation: Bool {
        !isComputed && isInstance && !isImmutable && identifier != nil
    }
}

extension ReactiveMacro: MemberMacro {
    public static func expansion<
        Declaration: DeclGroupSyntax,
        Context: MacroExpansionContext
    >(
        of node: AttributeSyntax,
        providingMembersOf declaration: Declaration,
        conformingTo protocols: [TypeSyntax],
        in context: Context
    ) throws -> [DeclSyntax] {
        guard let identified = declaration.asProtocol(NamedDeclSyntax.self) else {
            return []
        }

        let observableType = identified.name.trimmed

        if declaration.isEnum {
            // enumerations cannot store properties
            throw DiagnosticsError(
                syntax: node,
                message: "'@Reactive' cannot be applied to enumeration type '\(observableType.text)'",
                id: .invalidApplication
            )
        }
        if declaration.isStruct {
            // structs are not yet supported; copying/mutation semantics tbd
            throw DiagnosticsError(
                syntax: node,
                message: "'@Reactive' cannot be applied to struct type '\(observableType.text)'",
                id: .invalidApplication
            )
        }
        if declaration.isActor {
            // actors cannot yet be supported for their isolation
            throw DiagnosticsError(
                syntax: node,
                message: "'@Reactive' cannot be applied to actor type '\(observableType.text)'",
                id: .invalidApplication
            )
        }

        var declarations = [DeclSyntax]()

        declaration.addIfNeeded(ReactiveMacro.registrarVariable(observableType), to: &declarations)
        // declaration.addIfNeeded(ReactiveMacro.accessFunction(observableType), to: &declarations)
        // declaration.addIfNeeded(ReactiveMacro.withMutationFunction(observableType), to: &declarations)

        return declarations
    }
}

extension ReactiveMacro: MemberAttributeMacro {
    public static func expansion<
        Declaration: DeclGroupSyntax,
        MemberDeclaration: DeclSyntaxProtocol,
        Context: MacroExpansionContext
    >(
        of node: AttributeSyntax,
        attachedTo declaration: Declaration,
        providingAttributesFor member: MemberDeclaration,
        in context: Context
    ) throws -> [AttributeSyntax] {
        guard let property = member.as(VariableDeclSyntax.self), property.isValidForObservation,
            property.identifier != nil
        else {
            return []
        }

        // dont apply to ignored properties or properties that are already flagged as tracked
        if property.hasMacroApplication(ReactiveMacro.ignoredMacroName) || property.hasMacroApplication(ReactiveMacro.trackedMacroName) {
            return []
        }

        // Direct properties are numbered in declaration order; conditional ones keep their name.
        let properties = declaration.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { $0.isValidForObservation && !$0.hasMacroApplication(ReactiveMacro.ignoredMacroName) }
        guard let index = properties.firstIndex(where: { $0.identifier?.text == property.identifier?.text }) else {
            return [
                AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier(ReactiveMacro.trackedMacroName)))
            ]
        }
        return [AttributeSyntax("@ReactiveProperty(propertyIndex: \(raw: index))")]
    }
}

extension ReactiveMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // This method can be called twice - first with an empty `protocols` when
        // no conformance is needed, and second with a `MissingTypeSyntax` instance.
        if protocols.isEmpty {
            return []
        }

        let decl: DeclSyntax = """
            extension \(raw: type.trimmedDescription): \(raw: qualifiedConformanceName) {
            }
            """
        let ext = decl.cast(ExtensionDeclSyntax.self)

        if let availability = declaration.attributes.availability {
            return [ext.with(\.attributes, availability)]
        } else {
            return [ext]
        }
    }
}

public struct ReactivePropertyMacro: AccessorMacro {
    public static func expansion<
        Context: MacroExpansionContext,
        Declaration: DeclSyntaxProtocol
    >(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: Declaration,
        in context: Context
    ) throws -> [AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
            property.isValidForObservation,
            let identifier = property.identifier?.trimmed
        else {
            return []
        }

        if property.hasMacroApplication(ReactiveMacro.ignoredMacroName) {
            return []
        }

        let initAccessor: AccessorDeclSyntax =
            """
            @storageRestrictions(initializes: _\(identifier))
            init(initialValue) {
            _\(identifier) = initialValue
            }
            """

        let getAccessor: AccessorDeclSyntax =
            """
            get {
            \(raw: ReactiveMacro.registrarVariableName).access(Self.$propertyID_\(identifier))
            return _\(identifier)
            }
            """

        let setAccessor: AccessorDeclSyntax =
            """
            set {
            \(raw: ReactiveMacro.registrarVariableName).willSet(Self.$propertyID_\(identifier))
            defer { \(raw: ReactiveMacro.registrarVariableName).didSet(Self.$propertyID_\(identifier)) } 
            _\(identifier) = newValue
            }
            """

        let modifyAccessor: AccessorDeclSyntax =
            """
            _modify {
            \(raw: ReactiveMacro.registrarVariableName).access(Self.$propertyID_\(identifier))
            \(raw: ReactiveMacro.registrarVariableName).willSet(Self.$propertyID_\(identifier))
            defer { \(raw: ReactiveMacro.registrarVariableName).didSet(Self.$propertyID_\(identifier)) } 
            yield &_\(identifier)
            }
            """

        return [initAccessor, getAccessor, setAccessor, modifyAccessor]
    }
}

extension ReactivePropertyMacro: PeerMacro {
    public static func expansion<
        Context: MacroExpansionContext,
        Declaration: DeclSyntaxProtocol
    >(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
            property.isValidForObservation
        else {
            return []
        }

        if property.hasMacroApplication(ReactiveMacro.ignoredMacroName) {
            return []
        }

        let storage = DeclSyntax(property.privatePrefixed("_", addingAttribute: ReactiveMacro.ignoredAttribute))
        // An index from `@Reactive` is the property's identity, which makes tracking cheaper.
        let identity = node.propertyIndex.map { "\($0)" } ?? "\"\(property.identifier!.trimmed)\""
        let propertyID = DeclSyntax(
            """
            private static let $propertyID_\(property.identifier!.trimmed) = PropertyID(\(raw: identity))
            """
        )
        return [storage, propertyID]
    }
}

public struct ReactiveIgnoredMacro: AccessorMacro {
    public static func expansion<
        Context: MacroExpansionContext,
        Declaration: DeclSyntaxProtocol
    >(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: Declaration,
        in context: Context
    ) throws -> [AccessorDeclSyntax] {
        []
    }
}

private extension AttributeSyntax {
    /// The `propertyIndex` that `@Reactive` assigns to `@ReactiveProperty`, if any.
    var propertyIndex: Int? {
        arguments?.as(LabeledExprListSyntax.self)?.first { $0.label?.text == "propertyIndex" }?.expression
            .as(IntegerLiteralExprSyntax.self).flatMap { Int($0.literal.text) }
    }
}
