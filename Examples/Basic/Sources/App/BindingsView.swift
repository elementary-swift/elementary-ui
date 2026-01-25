import ElementaryUI

@View
struct BindingsView {
    @State var number: Double?
    @State var checked: Bool = false
    @State var text: String = "Hello"

    var body: some View {
        div {
            p {
                "Text: "
                input(.type(.text))
                    .bindValue($text)
                span { " - \(text)" }
            }

            p {
                "Number: "
                input(.type(.number)).bindValue($number)

                span { " - \(number.map { "\($0)" } ?? "nil")" }
            }

            p {
                "Checked: "
                input(.type(.checkbox))
                    .bindChecked($checked)
                span { " - \(checked)" }
            }

            button { "Set values" }
                .onClick { _ in
                    number = 42
                    checked = true
                    text = "Hello"
                }
        }

        // select {
        //     option { "Option 1" }
        //     option { "Option 2" }
        //     option { "Option 3" }
        // }
    }
}
