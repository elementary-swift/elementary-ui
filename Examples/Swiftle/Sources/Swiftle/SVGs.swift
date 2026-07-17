import ElementaryUI

@View
struct SwiftLogo {
    var id: String

    private var gradientID: String {
        "swift-logo-gradient-\(id)"
    }

    var body: some View {
        SVG.svg(.width(40), .height(40), .viewBox(0, 0, 32, 32), .fill(.none)) {
            SVG.path(
                .d(
                    "M22.1356 25.2715C18.835 27.17 14.2967 27.3651 9.73079 25.4166C6.03387 23.8505 2.96639 21.109 1 17.9767C1.94387 18.7598 3.04503 19.3865 4.22484 19.9344C8.9401 22.135 13.6544 21.9843 16.972 19.94C12.2526 16.3374 8.23626 11.6326 5.2475 7.79547C4.61799 7.16887 4.14605 6.38567 3.67412 5.68084C7.29225 8.97014 13.0343 13.1207 15.0789 14.296C10.7535 9.75321 6.8991 4.1147 7.0561 4.27103C13.8993 11.163 20.2707 15.079 20.2707 15.079C20.4815 15.1974 20.6442 15.2959 20.775 15.384C20.9129 15.0347 21.0338 14.672 21.1357 14.296C22.2368 10.3018 20.9787 5.759 18.2254 2C24.5962 5.83752 28.3721 13.0425 26.7985 19.0732C26.7575 19.2359 26.7129 19.3965 26.6648 19.5542C29.8106 23.4703 29.0008 27.6884 28.6076 26.9053C26.901 23.5801 23.7418 24.5969 22.1356 25.2715Z"
                ),
                .fill(.init("url(#\(gradientID))"))
            )
            SVG.defs {
                SVG.linearGradient(
                    .id(gradientID),
                    .x1(15.0103),
                    .y1(2),
                    .x2(15.0103),
                    .y2(27.0013),
                    .gradientUnits(.userSpaceOnUse)
                ) {
                    SVG.stop(.stopColor("#F88A36"))
                    SVG.stop(.offset(1), .stopColor("#FD2020"))
                }
            }
        }
    }
}

@View
struct EnterIcon {
    var body: some View {
        SVG.svg(
            .width(800),
            .height(800),
            .viewBox(0, 0, 24, 24),
            .fill(.none)
        ) {
            SVG.path(
                .d(
                    "M20 7V8.2C20 9.88016 20 10.7202 19.673 11.362C19.3854 11.9265 18.9265 12.3854 18.362 12.673C17.7202 13 16.8802 13 15.2 13H4M4 13L8 9M4 13L8 17"
                ),
                .stroke("#FFFFFF"),
                .strokeWidth(2),
                .strokeLinecap(.round),
                .strokeLinejoin(.round)
            )
        }
    }
}

@View
struct BackspaceIcon {
    var body: some View {
        SVG.svg(.width(800), .height(800), .viewBox(0, 0, 21, 21)) {
            SVG.g(
                .fill(.none),
                .fillRule(.evenodd),
                .stroke("#FFFFFF"),
                .strokeLinecap(.round),
                .strokeLinejoin(.round),
                .transform("matrix(0 -1 1 0 2.5 15.5)")
            ) {
                SVG.path(
                    .d(
                        "m0 5.82842712v7.17157288c0 1.1045695.8954305 2 2 2h6c1.1045695 0 2-.8954305 2-2v-7.17157288c0-.53043297-.21071368-1.0391408-.58578644-1.41421356l-3.70710678-3.70710678c-.39052429-.39052429-1.02368927-.39052429-1.41421356 0l-3.70710678 3.70710678c-.37507276.37507276-.58578644.88378059-.58578644 1.41421356z"
                    )
                )
                SVG.g(.transform("matrix(0 1 -1 0 14 4)")) {
                    SVG.path(.d("m3 11 4-4"))
                    SVG.path(.d("m3 7 4 4"))
                }
            }
        }
    }
}
