import ElementaryUI
import Testing

@Suite
struct ViewMacroTests {
    @Test
    func viewMacro() {
        let view = MyView(number: 2)
        let storage = MyView.__initializeState(from: view)

        var view2 = MyView()
        MyView.__restoreState(storage, in: &view2)
        #expect(view2.number == 2)
    }

    @Test
    func viewMacroWithPublicAccess() {
        let view = PublicMacroView(number: 7)
        let body = view.body as! HTMLText
        #expect(body.text == "Hello 7")
    }

    @Test
    func viewMacroWithPackageAccess() {
        let view = PackageMacroView(number: 11)
        let body = view.body as! HTMLText
        #expect(body.text == "Hello 11")
    }

    @Test
    func viewMacroWithInternalAccess() {
        let view = MyInternalView(number: 3)
        let body = view.body as! HTMLText
        #expect(body.text == "Hello 3")
    }
}

@View
struct MyView {
    @State var number = 0

    var body: some View {
        "Hello \(number)"
    }
}

@View
struct StatelessView {
    var body: some View {
        "Hello"
    }
}

@View
internal struct MyInternalView {
    @State internal var number = 0

    internal var body: some View {
        "Hello \(number)"
    }
}

@View
public struct PublicMacroView {
    @State public var number = 0

    public var body: some View {
        "Hello \(number)"
    }
}

@View
package struct PackageMacroView {
    @State package var number = 0

    package var body: some View {
        "Hello \(number)"
    }
}
