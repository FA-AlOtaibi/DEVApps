import SwiftUI

private struct MapNodeOffset: Codable {
    let x: Double
    let y: Double
}

struct StudyBoardView: View {
    @State private var recall = false
    @State private var selected: BoardNodeData?
    @State private var layout = 0
    @State private var showQuiz = false
    @State private var mapOffsets: [UUID: CGSize] = [:]

    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""
    @AppStorage("jalaaBoardNodesJSON") private var boardNodesJSON = ""
    @AppStorage("jalaaSuggestedLayout") private var suggestedLayout = 2
    @AppStorage("jalaaMapOffsets") private var mapOffsetsJSON = ""

    private let layouts = ["ذكي", "خريطة", "بطاقات", "خط زمني", "مقارنة", "مسار"]

    private var nodes: [BoardNodeData] {
        let saved = BoardEngine.decode(boardNodesJSON)
        return saved.isEmpty ? BoardEngine.nodes(from: boardSource) : saved
    }

    private var resolvedLayout: Int {
        layout == 0 ? max(1, min(5, suggestedLayout)) : layout
    }

    var body: some View {
        let p = JalaaPalette.value(theme)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if nodes.isEmpty {
                    emptyState(p)
                } else {
                    header(p)
                    compactControls(p)
                    board(p)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 116)
        }
        .onAppear { loadMapOffsets() }
        .sheet(item: $selected) { node in
            NodeDetailView(node: node, source: boardSource, theme: theme)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuiz) {
            QuizSheet(nodes: nodes, theme: theme)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func header(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(boardTitle.isEmpty ? "لوحتي" : boardTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(p.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(nodes.count) مفاهيم • اسحب لاستكشاف اللوحة واضغط للتفاصيل")
                .font(.caption)
                .foregroundStyle(p.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactControls(_ p: JalaaPalette) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(layouts.indices, id: \.self) { i in
                    Button(layouts[i]) { layout = i }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: iconForLayout(resolvedLayout))
                    Text(layout == 0 ? "ذكي · \(layouts[resolvedLayout])" : layouts[layout])
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(p.text)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(p.text.opacity(0.05), in: Capsule())
            }

            Spacer()

            iconButton(recall ? "eye.slash.fill" : "brain.head.profile", active: recall, p: p) {
                recall.toggle()
            }

            iconButton("bolt.fill", active: false, p: p) {
                showQuiz = true
            }
        }
    }

    private func iconButton(_ icon: String, active: Bool, p: JalaaPalette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? p.background : p.text)
                .frame(width: 38, height: 38)
                .background(active ? p.accent : p.text.opacity(0.05), in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func board(_ p: JalaaPalette) -> some View {
        switch resolvedLayout {
        case 1: draggableConceptMap(p)
        case 2: cardPager(p)
        case 3: timelinePager(p)
        case 4: comparison(p)
        case 5: flowPager(p)
        default: cardPager(p)
        }
    }

    // MARK: - Draggable concept canvas

    private func draggableConceptMap(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("خريطة المفاهيم")
                        .font(.headline)
                        .foregroundStyle(p.text)
                    Text("اسحب أي مفهوم لتعيد ترتيب الخريطة")
                        .font(.caption)
                        .foregroundStyle(p.muted)
                }
                Spacer()
                Button("إعادة ترتيب") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mapOffsets = [:]
                        saveMapOffsets()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(p.accent)
            }

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack {
                    mapBackground(p)
                    connectionLines(p)

                    ForEach(nodes.indices, id: \.self) { index in
                        draggableMapNode(nodes[index], index: index, p: p)
                    }
                }
                .frame(width: 720, height: 560)
                .contentShape(Rectangle())
            }
            .frame(height: 510)
            .background(p.text.opacity(0.02), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(p.text.opacity(0.06)))
        }
    }

    private func mapBackground(_ p: JalaaPalette) -> some View {
        Canvas { context, size in
            let step: CGFloat = 32
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(p.text.opacity(0.025)), lineWidth: 0.6)
        }
    }

    private func connectionLines(_ p: JalaaPalette) -> some View {
        Canvas { context, _ in
            guard !nodes.isEmpty else { return }
            let centerPoint = positionForNode(0)

            for index in nodes.indices.dropFirst() {
                let point = positionForNode(index)
                var path = Path()
                path.move(to: centerPoint)
                path.addLine(to: point)
                context.stroke(path, with: .color(p.accent.opacity(0.25)), lineWidth: 1.3)
            }

            if nodes.count > 2 {
                for index in 1..<(nodes.count - 1) {
                    var path = Path()
                    path.move(to: positionForNode(index))
                    path.addLine(to: positionForNode(index + 1))
                    context.stroke(path, with: .color(p.text.opacity(0.08)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
        }
    }

    private func draggableMapNode(_ node: BoardNodeData, index: Int, p: JalaaPalette) -> some View {
        let base = defaultPosition(index: index)
        let offset = mapOffsets[node.id] ?? .zero
        let isCenter = index == 0

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isCenter ? p.accent : p.accent.opacity(0.65))
                    .frame(width: 7, height: 7)
                Text(isCenter ? "الفكرة الرئيسية" : "مفهوم \(index + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isCenter ? p.accent : p.muted)
                Spacer(minLength: 0)
            }

            Text(recall ? "؟" : node.title)
                .font(isCenter ? .subheadline.weight(.bold) : .caption.weight(.semibold))
                .foregroundStyle(p.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: isCenter ? 190 : 170, alignment: .leading)
        .background(isCenter ? p.accent.opacity(0.12) : p.secondary.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isCenter ? p.accent.opacity(0.38) : p.text.opacity(0.07)))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .position(x: base.x + offset.width, y: base.y + offset.height)
        .highPriorityGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    mapOffsets[node.id] = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
                }
                .onEnded { value in
                    mapOffsets[node.id] = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
                    saveMapOffsets()
                }
        )
        .onTapGesture {
            selected = node
        }
    }

    private func defaultPosition(index: Int) -> CGPoint {
        let center = CGPoint(x: 360, y: 280)
        if index == 0 { return center }

        let satellites = max(nodes.count - 1, 1)
        let angle = Double(index - 1) / Double(satellites) * Double.pi * 2 - Double.pi / 2
        let rx = 250.0
        let ry = 185.0

        return CGPoint(
            x: center.x + CGFloat(cos(angle) * rx),
            y: center.y + CGFloat(sin(angle) * ry)
        )
    }

    private func positionForNode(_ index: Int) -> CGPoint {
        let node = nodes[index]
        let base = defaultPosition(index: index)
        let offset = mapOffsets[node.id] ?? .zero
        return CGPoint(x: base.x + offset.width, y: base.y + offset.height)
    }

    private func saveMapOffsets() {
        var payload: [String: MapNodeOffset] = [:]
        for (id, size) in mapOffsets {
            payload[id.uuidString] = MapNodeOffset(x: size.width, y: size.height)
        }
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else { return }
        mapOffsetsJSON = string
    }

    private func loadMapOffsets() {
        guard let data = mapOffsetsJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode([String: MapNodeOffset].self, from: data) else { return }
        var restored: [UUID: CGSize] = [:]
        for (key, value) in payload {
            if let id = UUID(uuidString: key) {
                restored[id] = CGSize(width: value.x, height: value.y)
            }
        }
        mapOffsets = restored
    }

    // MARK: - Other layouts

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
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(p.accent)

                Text(recall ? "؟" : node.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(p.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !recall {
                    Text(node.detail)
                        .font(.subheadline)
                        .foregroundStyle(p.muted)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
            .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func timelinePager(_ p: JalaaPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(nodes.indices, id: \.self) { i in
                    timelineCard(index: i, node: nodes[i], p: p)
                        .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func timelineCard(index: Int, node: BoardNodeData, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(p.background)
                        .frame(width: 32, height: 32)
                        .background(p.accent, in: Circle())
                    Rectangle().fill(p.accent.opacity(0.25)).frame(height: 1)
                }

                Text(recall ? "؟" : node.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(p.text)
                    .fixedSize(horizontal: false, vertical: true)

                if !recall {
                    Text(node.detail)
                        .font(.subheadline)
                        .foregroundStyle(p.muted)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
            .background(p.text.opacity(0.03), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func comparison(_ p: JalaaPalette) -> some View {
        let first = nodes[0]
        let second = nodes.count > 1 ? nodes[1] : nodes[0]

        return VStack(spacing: 10) {
            compareCard(first, badge: "A", p: p)
            compareCard(second, badge: "B", p: p)
        }
    }

    private func compareCard(_ node: BoardNodeData, badge: String, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(badge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(p.background)
                    .frame(width: 30, height: 30)
                    .background(p.accent, in: Circle())

                VStack(alignment: .leading, spacing: 7) {
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
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func flowPager(_ p: JalaaPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(nodes.indices, id: \.self) { i in
                    VStack(spacing: 8) {
                        flowItem(index: i, node: nodes[i], p: p)
                        if i < nodes.count - 1 {
                            Image(systemName: "arrow.left")
                                .foregroundStyle(p.accent.opacity(0.6))
                        }
                    }
                }
            }
        }
    }

    private func flowItem(index: Int, node: BoardNodeData, p: JalaaPalette) -> some View {
        Button { selected = node } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(p.background)
                    .frame(width: 30, height: 30)
                    .background(p.accent, in: Circle())

                Text(recall ? "؟" : node.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(p.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 190, alignment: .leading)
            .padding(16)
            .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
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

    private func emptyState(_ p: JalaaPalette) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 36))
                .foregroundStyle(p.accent)
            Text("لا توجد لوحة بعد")
                .font(.title2.weight(.bold))
                .foregroundStyle(p.text)
            Text("ارجع للرئيسية وارفع ملفًا أو ألصق نصًا.")
                .foregroundStyle(p.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }
}

// MARK: - Clear concept detail

private enum DetailMode: String, CaseIterable {
    case explain = "اشرح"
    case deepen = "تعمّق"
    case example = "مثال"

    var icon: String {
        switch self {
        case .explain: return "text.bubble"
        case .deepen: return "book.closed"
        case .example: return "lightbulb"
        }
    }

    var actionKey: String {
        switch self {
        case .explain: return "explain"
        case .deepen: return "deepen"
        case .example: return "example"
        }
    }
}

struct NodeDetailView: View {
    let node: BoardNodeData
    let source: String
    let theme: Int

    @State private var mode: DetailMode = .explain
    @State private var result = ""
    @State private var question = ""
    @State private var loading = false
    @State private var errorText = ""
    @AppStorage("jalaaAIModel") private var aiModel = "gpt-5.6-luna"

    var body: some View {
        let p = JalaaPalette.value(theme)

        ZStack {
            p.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    conceptHeader(p)
                    modePicker(p)
                    answerPanel(p)
                    askSection(p)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .task { await run(mode) }
    }

    private func conceptHeader(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("المفهوم")
                .font(.caption.weight(.semibold))
                .foregroundStyle(p.accent)

            Text(node.title)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(node.detail)
                .font(.body)
                .foregroundStyle(p.muted)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func modePicker(_ p: JalaaPalette) -> some View {
        HStack(spacing: 6) {
            ForEach(DetailMode.allCases, id: \.self) { item in
                Button {
                    mode = item
                    Task { await run(item) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.icon)
                        Text(item.rawValue)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(mode == item ? p.background : p.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(mode == item ? p.accent : p.text.opacity(0.045), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func answerPanel(_ p: JalaaPalette) -> some View {
        if loading {
            HStack(spacing: 10) {
                ProgressView().tint(p.accent)
                Text("جلاء يجهز الإجابة…")
                    .font(.subheadline)
                    .foregroundStyle(p.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(p.text.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        } else if !result.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(mode.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(p.accent)
                Text(result)
                    .font(.body)
                    .foregroundStyle(p.text)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.text.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        }

        if !errorText.isEmpty {
            Text(errorText)
                .font(.caption)
                .foregroundStyle(p.muted)
        }
    }

    private func askSection(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("اسأل عن هذا المفهوم")
                .font(.headline)
                .foregroundStyle(p.text)

            HStack(alignment: .bottom, spacing: 8) {
                TextField("مثلاً: لماذا يحدث هذا؟", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .foregroundStyle(p.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(p.text.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))

                Button { Task { await ask() } } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(p.background)
                        .frame(width: 44, height: 44)
                        .background(p.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
            }
        }
        .padding(.top, 4)
    }

    private func run(_ item: DetailMode) async {
        await MainActor.run {
            loading = true
            errorText = ""
            result = ""
        }

        do {
            let text = try await JalaaAIService.nodeAction(item.actionKey, node: node, source: source, model: aiModel)
            await MainActor.run {
                result = text
                loading = false
            }
        } catch {
            let fallback: String
            switch item {
            case .explain: fallback = BoardEngine.explain(node)
            case .deepen: fallback = BoardEngine.deepen(node, source: source)
            case .example: fallback = BoardEngine.example(node)
            }
            await MainActor.run {
                result = fallback
                errorText = "تعذر الاتصال بالذكاء الآن، لذلك عرضت نتيجة محلية."
                loading = false
            }
        }
    }

    private func ask() async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        await MainActor.run {
            loading = true
            errorText = ""
            result = ""
        }

        do {
            let text = try await JalaaAIService.nodeAction("ask", node: node, source: source, question: q, model: aiModel)
            await MainActor.run {
                result = text
                loading = false
            }
        } catch {
            await MainActor.run {
                result = BoardEngine.answer(question: q, node: node, source: source)
                errorText = "تعذر الاتصال بالذكاء الآن، لذلك أجبت من المحتوى المحلي."
                loading = false
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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("اختبار سريع")
                        .font(.title.weight(.bold))
                        .foregroundStyle(p.text)

                    Text("أي عنوان يطابق الفكرة التالية؟")
                        .foregroundStyle(p.muted)

                    Text(nodes.first?.detail ?? "")
                        .font(.headline)
                        .foregroundStyle(p.text)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .background(p.text.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))

                    ForEach(options.indices, id: \.self) { i in
                        Button { selected = i } label: {
                            HStack(spacing: 10) {
                                Text(options[i].title)
                                    .fixedSize(horizontal: false, vertical: true)
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
                }
                .padding(22)
            }
        }
    }
}
