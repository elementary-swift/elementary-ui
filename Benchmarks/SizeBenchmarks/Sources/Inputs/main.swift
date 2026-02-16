import ElementaryUI

extension EnvironmentValues {
    @Entry var formLabel: String = ""
}

@View
struct InputsApp {
    @State var text = "Hello"
    @State var number: Double? = 1.0
    @State var checked = false
    @FocusState var focusedField: Field?

    enum Field: Hashable {
        case text
        case number
    }

    var body: some View {
        div {
            LabeledField(name: "Text") {
                input(.type(.text), .placeholder("Type here"))
                    .bindValue($text)
                    .focused($focusedField, equals: .text)
            }

            LabeledField(name: "Number") {
                input(.type(.number))
                    .bindValue($number)
                    .focused($focusedField, equals: .number)
            }

            p {
                input(.type(.checkbox))
                    .bindChecked($checked)
                " Accept terms"
            }

            div {
                button { "Focus text" }
                    .onClick { focusedField = .text }
                button { "Focus number" }
                    .onClick { focusedField = .number }
                button { "Clear focus" }
                    .onClick { focusedField = nil }
            }
        }
        .environment(#Key(\.formLabel), "Settings")
    }
}

@View
struct LabeledField<Input: View & HTML> {
    var name: String
    @Environment(#Key(\.formLabel)) var formLabel

    @HTMLBuilder var input: () -> Input

    var body: some View {
        p {
            "\(formLabel) — \(name): "
            input()
        }
    }
}

Application(InputsApp()).mount(in: "#app")
