import SwiftUI

struct RootView: View {
    @State private var tab = 0
    @AppStorage("jalaaTheme") private var theme = 0

    var body: some View {
        ZStack {
            JalaaBackground(theme: theme)
            Group {
                switch tab {
                case 0: HomeView(tab: $tab)
                case 1: StudyBoardView()
                case 2: LibraryView()
                default: SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) { JalaaTabBar(selection: $tab, theme: theme) }
        }
        .preferredColorScheme(theme == 1 || theme == 5 ? .light : .dark)
    }
}

struct JalaaPalette {
    let background: Color
    let secondary: Color
    let accent: Color
    let text: Color
    let muted: Color

    static func value(_ index: Int) -> JalaaPalette {
        switch index {
        case 1: return .init(background: Color(red:0.94,green:0.92,blue:0.87), secondary: Color(red:0.88,green:0.85,blue:0.78), accent: Color(red:0.12,green:0.12,blue:0.13), text: .black, muted: .black.opacity(0.52))
        case 2: return .init(background: Color(red:0.015,green:0.025,blue:0.055), secondary: Color(red:0.05,green:0.10,blue:0.19), accent: Color(red:0.34,green:0.67,blue:1.0), text: .white, muted: .white.opacity(0.55))
        case 3: return .init(background: Color(red:0.055,green:0.075,blue:0.065), secondary: Color(red:0.10,green:0.15,blue:0.12), accent: Color(red:0.55,green:0.73,blue:0.60), text: .white, muted: .white.opacity(0.55))
        case 4: return .init(background: Color(red:0.08,green:0.045,blue:0.055), secondary: Color(red:0.17,green:0.08,blue:0.10), accent: Color(red:0.91,green:0.43,blue:0.34), text: .white, muted: .white.opacity(0.56))
        case 5: return .init(background: Color(red:0.93,green:0.94,blue:0.92), secondary: Color(red:0.83,green:0.87,blue:0.84), accent: Color(red:0.12,green:0.28,blue:0.20), text: .black, muted: .black.opacity(0.52))
        case 6: return .init(background: Color(red:0.035,green:0.032,blue:0.05), secondary: Color(red:0.09,green:0.07,blue:0.15), accent: Color(red:0.62,green:0.48,blue:0.92), text: .white, muted: .white.opacity(0.55))
        case 7: return .init(background: Color(red:0.025,green:0.045,blue:0.045), secondary: Color(red:0.05,green:0.12,blue:0.12), accent: Color(red:0.16,green:0.75,blue:0.72), text: .white, muted: .white.opacity(0.55))
        default: return .init(background: Color(red:0.035,green:0.04,blue:0.05), secondary: Color(red:0.09,green:0.095,blue:0.11), accent: Color(red:0.40,green:0.67,blue:0.96), text: .white, muted: .white.opacity(0.55))
        }
    }
}

struct JalaaBackground: View {
    let theme: Int
    var body: some View {
        let p = JalaaPalette.value(theme)
        ZStack {
            p.background.ignoresSafeArea()
            RadialGradient(colors: [p.accent.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 430).ignoresSafeArea()
            LinearGradient(colors: [.clear, p.secondary.opacity(0.28)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
    }
}

struct JalaaTabBar: View {
    @Binding var selection: Int
    let theme: Int
    let items = [("house.fill","الرئيسية"),("point.3.connected.trianglepath.dotted","لوحتي"),("square.stack.3d.up.fill","المكتبة"),("slider.horizontal.3","المظهر")]
    var body: some View {
        let p = JalaaPalette.value(theme)
        HStack(spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.spring(response: 0.32,dampingFraction: 0.82)){ selection = index }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.0).font(.system(size: 17, weight: .semibold))
                        Text(item.1).font(.caption2.weight(.semibold)).lineLimit(1)
                    }
                    .foregroundStyle(selection == index ? p.background : p.text.opacity(0.68))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(selection == index ? p.accent : Color.clear, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(p.text.opacity(0.10)))
        .padding(.horizontal, 14).padding(.bottom, 4)
    }
}
