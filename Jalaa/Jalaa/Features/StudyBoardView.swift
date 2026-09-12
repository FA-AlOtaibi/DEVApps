import SwiftUI

struct StudyBoardView: View {
    @State private var recall = false
    @State private var selected: BoardNodeData?
    @State private var layout = 0
    @State private var showQuiz = false

    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""
    @AppStorage("jalaaBoardNodesJSON") private var boardNodesJSON = ""
    @AppStorage("jalaaSuggestedLayout") private var suggestedLayout = 2

    private let layouts = ["ذكي", "خريطة", "بطاقات", "خط زمني", "مقارنة", "مسار"]
    private var nodes: [BoardNodeData] {
        let saved = BoardEngine.decode(boardNodesJSON)
        return saved.isEmpty ? BoardEngine.nodes(from: boardSource) : saved
    }
    private var resolvedLayout: Int { layout == 0 ? max(1, min(5, suggestedLayout)) : layout }

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if nodes.isEmpty {
                    emptyState(p)
                } else {
                    header(p)
                    controls(p)
                    board(p)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 116)
        }
        .sheet(item: $selected) { node in
            NodeSheet(node: node, source: boardSource, theme: theme)
        }
        .sheet(isPresented: $showQuiz) {
            QuizSheet(nodes: nodes, theme: theme)
        }
    }

    private func header(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(boardTitle.isEmpty ? "لوحتي" : boardTitle)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(nodes.count) مفاهيم • اضغط على أي عنصر للتفاصيل")
                .font(.caption)
                .foregroundStyle(p.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controls(_ p: JalaaPalette) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(layouts.indices, id: \.self) { i in
                    Button(layouts[i]) { layout = i }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: iconForLayout(resolvedLayout))
                    Text(layout == 0 ? "ذكي · \(layouts[resolvedLayout])" : layouts[layout]).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(p.text)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(p.text.opacity(0.055), in: Capsule())
            }

            Spacer(minLength: 4)

            roundButton(recall ? "eye.slash.fill" : "brain.head.profile", active: recall, p: p) { recall.toggle() }
            roundButton("bolt.fill", active: false, p: p) { showQuiz = true }
        }
    }

    private func roundButton(_ icon: String, active: Bool, p: JalaaPalette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? p.background : p.text)
                .frame(width: 38, height: 38)
                .background(active ? p.accent : p.text.opacity(0.055), in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func board(_ p: JalaaPalette) -> some View {
        switch resolvedLayout {
        case 1: conceptMap(p)
        case 2: cardPager(p)
        case 3: timelinePager(p)
        case 4: comparison(p)
        case 5: flowPager(p)
        default: cardPager(p)
        }
    }

    private func conceptMap(_ p: JalaaPalette) -> some View {
        GeometryReader { geo in
            let visible = Array(nodes.prefix(6))
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                RoundedRectangle(cornerRadius: 26).fill(p.text.opacity(0.028))
                mapLines(visible.count, center: center, size: geo.size, color: p.accent.opacity(0.24))
                centerNode(visible, center: center, p: p)
                ForEach(visible.indices, id: \.self) { i in
                    mapNode(visible[i], index: i, count: visible.count, size: geo.size, p: p)
                }
            }
        }
        .frame(height: 350)
    }

    private func mapLines(_ count: Int, center: CGPoint, size: CGSize, color: Color) -> some View {
        Path { path in
            for i in 0..<count {
                let point = mapPoint(i, count: count, size: size)
                path.move(to: center)
                path.addLine(to: point)
            }
        }
        .stroke(color, lineWidth: 1.2)
    }

    private func centerNode(_ visible: [BoardNodeData], center: CGPoint, p: JalaaPalette) -> some View {
        Button {
            selected = visible.first
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "circle.hexagongrid.fill").foregroundStyle(p.accent)
                Text(recall ? "؟" : short(boardTitle.isEmpty ? visible.first?.title ?? "الموضوع" : boardTitle, max: 36))
                    .font(.caption.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .foregroundStyle(p.text)
            .frame(width: 128, height: 82)
            .background(p.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(p.accent.opacity(0.38)))
        }
        .buttonStyle(.plain)
        .position(center)
    }

    private func mapNode(_ node: BoardNodeData, index: Int, count: Int, size: CGSize, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            Text(recall ? "؟" : short(node.title, max: 28))
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(p.text)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(width: 104, height: 54)
                .background(p.secondary.opacity(0.82), in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .position(mapPoint(index, count: count, size: size))
    }

    private func mapPoint(_ index: Int, count: Int, size: CGSize) -> CGPoint {
        guard count > 0 else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        let angle = Double(index) / Double(count) * Double.pi * 2 - Double.pi / 2
        let rx = min(Double(size.width) * 0.34, 118)
        let ry = min(Double(size.height) * 0.33, 112)
        return CGPoint(x: Double(size.width) / 2 + cos(angle) * rx, y: Double(size.height) / 2 + sin(angle) * ry)
    }

    private func cardPager(_ p: JalaaPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(nodes) { node in
                    studyCard(node, p: p)
                        .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func studyCard(_ node: BoardNodeData, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted").foregroundStyle(p.accent)
                    Spacer()
                    Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(p.muted)
                }
                Text(recall ? "؟" : node.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(p.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !recall {
                    Text(node.detail)
                        .font(.subheadline)
                        .foregroundStyle(p.muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(minHeight: 238, alignment: .topLeading)
            .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func timelinePager(_ p: JalaaPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(nodes.indices, id: \.self) { i in
                    timelineCard(index: i, node: nodes[i], p: p)
                        .containerRelativeFrame(.horizontal, count: 1, spacing: 10)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func timelineCard(index: Int, node: BoardNodeData, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(p.background)
                        .frame(width: 30, height: 30)
                        .background(p.accent, in: Circle())
                    Rectangle().fill(p.accent.opacity(0.25)).frame(height: 1)
                }
                Text(recall ? "؟" : node.title)
                    .font(.headline)
                    .foregroundStyle(p.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !recall {
                    Text(node.detail)
                        .font(.subheadline)
                        .foregroundStyle(p.muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(minHeight: 228, alignment: .topLeading)
            .background(p.text.opacity(0.03), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func comparison(_ p: JalaaPalette) -> some View {
        let first = nodes[0]
        let second = nodes.count > 1 ? nodes[1] : nodes[0]
        return HStack(alignment: .top, spacing: 10) {
            compareCard(first, badge: "A", p: p)
            compareCard(second, badge: "B", p: p)
        }
    }

    private func compareCard(_ node: BoardNodeData, badge: String, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            VStack(alignment: .leading, spacing: 11) {
                Text(badge).font(.caption.weight(.bold)).foregroundStyle(p.background).frame(width: 28, height: 28).background(p.accent, in: Circle())
                Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).fixedSize(horizontal: false, vertical: true)
                if !recall {
                    Text(node.detail).font(.caption).foregroundStyle(p.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(15)
            .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func flowPager(_ p: JalaaPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(nodes.indices, id: \.self) { i in
                    flowItem(index: i, node: nodes[i], p: p)
                    if i < nodes.count - 1 {
                        Image(systemName: "arrow.left").foregroundStyle(p.accent.opacity(0.65))
                    }
                }
            }
        }
    }

    private func flowItem(index: Int, node: BoardNodeData, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            VStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(p.background)
                    .frame(width: 30, height: 30)
                    .background(p.accent, in: Circle())
                Text(recall ? "؟" : node.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(p.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 150)
            .frame(minHeight: 128)
            .padding(14)
            .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func iconForLayout(_ index: Int) -> String {
        switch index {
        case 1: return "point.3.connected.trianglepath.dotted"
        case 2: return "rectangle.stack"
        case 3: return "timeline.selection"
        case 4: return "rectangle.split.2x1"
        case 5: return "arrow.triangle.branch"
        default: return "rectangle.3.group"
        }
    }

    private func short(_ text: String, max: Int) -> String {
        guard text.count > max else { return text }
        return String(text.prefix(max)) + "…"
    }

    private func emptyState(_ p: JalaaPalette) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash").font(.system(size: 36)).foregroundStyle(p.accent)
            Text("لا توجد لوحة بعد").font(.title2.weight(.bold)).foregroundStyle(p.text)
            Text("ارجع للرئيسية وارفع ملفًا أو ألصق نصًا.").foregroundStyle(p.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }
}

struct NodeSheet: View {
    let node: BoardNodeData
    let source: String
    let theme: Int

    @State private var result: String?
    @State private var question = ""
    @State private var loading = false
    @State private var errorText = ""
    @AppStorage("jalaaAIModel") private var aiModel = "gpt-5.6-luna"

    var body: some View {
        let p = JalaaPalette.value(theme)
        ZStack {
            p.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule().fill(p.text.opacity(0.18)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                    Text(node.title).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(p.text).fixedSize(horizontal: false, vertical: true)
                    Text(node.detail).font(.body).foregroundStyle(p.muted).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        aiAction("اشرح", "text.bubble", "explain", p)
                        aiAction("تعمّق", "book.closed", "deepen", p)
                        aiAction("مثال", "lightbulb", "example", p)
                    }
                    TextField("اسأل جلاء عن هذه النقطة…", text: $question, axis: .vertical)
                        .foregroundStyle(p.text)
                        .padding(13)
                        .background(p.text.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
                    Button { ask() } label: {
                        HStack(spacing: 8) {
                            if loading { ProgressView().tint(p.background) }
                            Label("اسأل جلاء", systemImage: "sparkles")
                        }
                        .font(.headline)
                        .foregroundStyle(p.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(p.accent, in: RoundedRectangle(cornerRadius: 15))
                    }
                    .disabled(loading || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !errorText.isEmpty { Text(errorText).font(.caption).foregroundStyle(.red) }
                    if let result {
                        Text(result)
                            .foregroundStyle(p.text)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .background(p.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(22)
                .padding(.bottom, 30)
            }
        }
    }

    private func aiAction(_ title: String, _ icon: String, _ kind: String, _ p: JalaaPalette) -> some View {
        Button { run(kind) } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                Text(title).font(.caption.weight(.bold))
            }
            .foregroundStyle(p.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(p.text.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    private func run(_ kind: String) {
        loading = true
        errorText = ""
        Task {
            do {
                let text = try await JalaaAIService.nodeAction(kind, node: node, source: source, model: aiModel)
                await MainActor.run { result = text; loading = false }
            } catch {
                let fallback = kind == "explain" ? BoardEngine.explain(node) : kind == "deepen" ? BoardEngine.deepen(node, source: source) : BoardEngine.example(node)
                await MainActor.run {
                    result = fallback
                    errorText = "الـAI غير متصل الآن؛ عرضت نتيجة محلية بدلًا منه."
                    loading = false
                }
            }
        }
    }

    private func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        loading = true
        errorText = ""
        Task {
            do {
                let text = try await JalaaAIService.nodeAction("ask", node: node, source: source, question: q, model: aiModel)
                await MainActor.run { result = text; loading = false }
            } catch {
                await MainActor.run {
                    result = BoardEngine.answer(question: q, node: node, source: source)
                    errorText = "تعذر AI؛ هذه إجابة مستخرجة محليًا من المحتوى."
                    loading = false
                }
            }
        }
    }
}

struct QuizSheet: View {
    let nodes: [BoardNodeData]
    let theme: Int
    @State private var selected: Int?

    var body: some View {
        let p = JalaaPalette.value(theme)
        let options = Array(nodes.prefix(min(4, nodes.count)))
        ZStack {
            p.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Capsule().fill(p.text.opacity(0.18)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                Text("اختبار سريع").font(.title.weight(.bold)).foregroundStyle(p.text)
                Text("أي عنوان يطابق الفكرة التالية؟").foregroundStyle(p.muted)
                Text(nodes.first?.detail ?? "")
                    .font(.headline)
                    .foregroundStyle(p.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))

                ForEach(options.indices, id: \.self) { i in
                    Button { selected = i } label: {
                        HStack(spacing: 10) {
                            Text(options[i].title).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            if selected == i {
                                Image(systemName: i == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(i == 0 ? .green : .red)
                            }
                        }
                        .foregroundStyle(p.text)
                        .padding(14)
                        .background(p.text.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(22)
        }
    }
}
