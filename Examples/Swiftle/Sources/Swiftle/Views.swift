import ElementaryFlow
import ElementaryUI

@View
struct GameView {
    @State var game = Game()

    func onKeyPressed(_ key: EnteredKey) {
        game.handleKey(key)
    }

    var body: some View {
        FlexColumn(align: .center, gap: 20) {

            FlexRow(align: .center, gap: 16) {
                SwiftLogo()
                Heading("SWIFTLE")
                    .style(.fontSize(.xxl), .fontFamily(.serif), .letterSpacing(.em(0.1)))
                SwiftLogo()
            }

            FlexColumn(gap: 4) {
                for guess in game.guesses {
                    GuessView(guess: guess)
                }
            }.style(.fontWeight(.semiBold), .fontSize(.lg), .fontFamily(.monospace))

            Block {
                KeyboardView(keyboard: game.keyboard, onKeyPressed: onKeyPressed)
                GameEndOverlay(game: $game)
            }.style(.position(.relative))

            Paragraph {
                "This is a proof of concept demo of an Embedded Swift Wasm app."
                br()
                "Find the source code in the "
                a(.href("https://github.com/elementary-swift/elementary-ui")) {
                    "elementary-ui github repository."
                }
                .style(.color(.orange600))
                .style(when: .hover, .textDecoration("underline"))
            }.style(
                .color(.gray400),
                .fontFamily(.sansSerif),
                .textAlign(.center),
                .fontSize(.xs)
            )
        }
        .style(.color(.white), .padding(t: 20), .fontFamily(.sansSerif))
        .receive(GlobalDocument.onKeyDown) { event in
            guard let key = EnteredKey(event) else { return }
            onKeyPressed(key)
        }
    }
}

@View
struct SwiftLogo {
    var body: some View {
        img(.src("swift-bird.svg"))
            .style(.height(40))
    }
}

@View
struct GuessView {
    var guess: Guess

    var body: some View {
        FlexRow(gap: 4) {
            for letter in guess.letters {
                LetterView(guess: letter)
            }
        }
    }
}

@View
struct LetterView {
    var guess: LetterGuess?

    var body: some View {
        FlexRow(justify: .center, align: .center) {
            Paragraph { guess?.letter.value ?? "" }
        }
        .style(
            .width(40),
            .height(40),
            .color(guess?.status == .unknown ? .gray200 : .white),
            .borderColor(guess == nil ? .gray700 : .gray400),
            .borderWidth(guess == nil || guess?.status == .unknown ? .px(2) : 0),
            .background(guess?.status.backgroundColor ?? .transparent)
        )
    }
}

@View
struct KeyboardView {
    var keyboard: Keyboard
    var onKeyPressed: (EnteredKey) -> Void

    var body: some View {
        FlexColumn(align: .center, gap: 6) {
            FlexRow(gap: 4) {
                for letter in keyboard.topRow {
                    KeyboardLetterView(guess: letter, onKeyPressed: onKeyPressed)
                }
            }
            FlexRow(gap: 4) {
                for letter in keyboard.middleRow {
                    KeyboardLetterView(guess: letter, onKeyPressed: onKeyPressed)
                }
            }
            FlexRow(gap: 4) {
                BackspaceKeyView(onKeyPressed: onKeyPressed)
                for letter in keyboard.bottomRow {
                    KeyboardLetterView(guess: letter, onKeyPressed: onKeyPressed)
                }
                EnterKeyView(onKeyPressed: onKeyPressed)
            }
        }
    }
}

@View
struct KeyboardLetterView {
    var guess: LetterGuess
    var onKeyPressed: (EnteredKey) -> Void

    var body: some View {
        button {
            span {
                guess.letter.value
            }.style(.margin(.auto), .fontSize(.lg), .fontWeight(.semiBold))
        }
        .style(.width(28), .height(40), .display(.flex), .borderRadius(2))
        .enabledMobileActive()
        .style(.background(guess.status.backgroundColor ?? .gray400))
        .style(when: .active, .background(guess.status.activeBackgroundColor))
        .onClick { _ in
            onKeyPressed(.letter(guess.letter))
        }
    }
}

@View
struct EnterKeyView {
    var onKeyPressed: (EnteredKey) -> Void

    var body: some View {
        button {
            img(.src("enter.svg")).style(
                .maxWidth("100%")
            )
        }
        .style(
            .width(48),
            .height(40),
            .padding(8),
            .borderRadius(2),
            .display(.flex),
            .alignItems(.center),
            .background(.gray400)
        )
        .style(when: .active, .background(.gray300))
        .enabledMobileActive()
        .onClick { _ in
            onKeyPressed(.enter)
        }
    }
}

@View
struct BackspaceKeyView {
    var onKeyPressed: (EnteredKey) -> Void

    var body: some View {
        button {
            img(.src("backspace.svg")).style(
                .maxWidth("100%")
            )
        }
        .style(
            .width(48),
            .height(40),
            .padding(4),
            .borderRadius(2),
            .display(.flex),
            .alignItems(.center),
            .background(.gray400)
        )
        .style(when: .active, .background(.gray300))
        .enabledMobileActive()
        .onClick { _ in
            onKeyPressed(.backspace)
        }
    }
}

@View
struct GameEndOverlay {
    @Binding var game: Game

    var body: some View {
        if game.state != .playing {
            Block {
                FlexColumn(align: .center, gap: 2) {
                    Paragraph(game.state == .won ? "Nice job!" : "Oh no!")
                        .style(
                            .fontSize(.xl),
                            .letterSpacing(.em(0.1)),
                            .textTransform("uppercase")
                        )
                    button { "Restart" }
                        .style(.background(.orange500), .padding(y: 8, x: 24), .borderRadius(4))
                        .onClick { _ in
                            game = Game()
                        }
                }
            }.style(
                .position(.absolute),
                .inset(0),
                .background(.black60a),
                .padding(t: 16),
                .fontWeight(.semiBold)
            )
        }
    }
}

extension View where Tag == HTMLTag.button {
    func enabledMobileActive() -> _AttributedElement<Self> {
        attributes(.custom(name: "ontouchstart", value: ""))
    }
}

extension EnteredKey {
    init?(_ event: KeyboardEvent) {
        let key = event.key
        if let validLetter = ValidLetter(key) {
            self = .letter(validLetter)
        } else if key.utf8Equals("Backspace") {
            self = .backspace
        } else if key.utf8Equals("Enter") {
            self = .enter
        } else {
            return nil
        }
    }
}

extension LetterGuess.LetterStatus {
    var backgroundColor: CSSColor? {
        switch self {
        case .unknown:
            nil
        case .notInWord:
            .gray600
        case .inWord:
            .yellow600
        case .correctPosition:
            .green600
        }
    }

    var activeBackgroundColor: CSSColor {
        switch self {
        case .unknown:
            .gray300
        case .notInWord:
            .gray500
        case .inWord:
            .yellow500
        case .correctPosition:
            .green500
        }
    }
}
