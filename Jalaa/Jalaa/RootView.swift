import SwiftUI

struct RootView: View {
    @State private var tab = 0
    var body: some View {
        ZStack {
            JalaaBackground()
            Group {
                switch tab {
                case 0: HomeView()
                case 1: StudyBoardView()
                case 2: LibraryView()
                default: SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) { JalaaTabBar(selection: $tab) }
        }
    }
}

struct JalaaBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.05, blue: 0.06).ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(0.09), .clear], center: .topTrailing, startRadius: 0, endRadius: 420).ignoresSafeArea()
            LinearGradient(colors: [Color.clear, Color(red: 0.18, green: 0.15, blue: 0.11).opacity(0.16)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
    }
}

struct JalaaTabBar: View {
    @Binding var selection: Int
    let items = [("house.fill","الرئيسية"),("point.3.connected.trianglepath.dotted","لوحتي"),("square.stack.3d.up.fill","المكتبة"),("slider.horizontal.3","الإعدادات")]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button { withAnimation(.spring(response: 0.35,dampingFraction: 0.8)){ selection = index } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.0).font(.system(size: 17, weight: .semibold))
                        Text(item.1).font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selection == index ? .black : .white.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(selection == index ? Color(red: 0.88, green: 0.82, blue: 0.68) : Color.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12)))
        .padding(.horizontal, 14).padding(.bottom, 4)
    }
}
