import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ViewMacro.self,
        CustomElementMacro.self,
        EntryMacro.self,
        EnvironmentKeyMacro.self,
        BindingMacro.self,
    ]
}
