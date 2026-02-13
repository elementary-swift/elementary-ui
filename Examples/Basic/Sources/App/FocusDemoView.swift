import ElementaryUI

@View
struct FocusDemoView {
    enum Field: Hashable, CustomStringConvertible {
        case first
        case second

        var description: String {
            switch self {
            case .first: return "first"
            case .second: return "second"
            }
        }
    }

    @State var firstText: String = "First"
    @State var secondText: String = "Second"

    @FocusState var focusedField: Field?
    @FocusState var isFocused: Bool
    @State var showDoubleBind: Bool = false

    var body: some View {
        div {
            h3 { "Focus demo" }

            p {
                "focusedField: "
                b { "\(focusedField.map { $0.description } ?? "nil")" }
            }

            div {
                button { "Focus first" }
                    .onClick { focusedField = .first }
                button { "Focus second" }
                    .onClick { focusedField = .second }
                button { "Clear focus" }
                    .onClick { focusedField = nil }
            }

            div {
                p {
                    "First: "
                    input(.type(.text))
                        .bindValue($firstText)
                        .focused($focusedField, equals: .first)
                        .focused($isFocused)
                }

                p {
                    "Second: "
                    input(.type(.text))
                        .bindValue($secondText)
                        .focused($focusedField, equals: .second)
                }

                p {
                    button { showDoubleBind ? "Hide double-bind" : "Show double-bind" }
                        .onClick { _ in showDoubleBind.toggle() }
                }
            }
            .onChange(of: isFocused) {
                print("isFocused changed to \(isFocused)")
            }
            .onChange(of: focusedField) {
                print("focusedField changed to \(focusedField)")
            }
            .onChange(of: secondText) {
                if secondText.isEmpty {
                    focusedField = .first
                }
            }

            if showDoubleBind {
                p {
                    "Double-bound to `.first` (should warn): "
                    input(.type(.text))
                        .bindValue($firstText)
                        .focused($focusedField, equals: .first)
                }
            }
        }
    }
}
