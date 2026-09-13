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
    @State private var nodeDragStarts: [UUID: CGSize] = [:]
    @State private var mapScale: CGFloat = 0.82
    @State private var mapPan: CGSize = .zero
    @GestureState private var livePan: CGSize = .zero
    @GestureState private var liveScale: CGFloat = 1

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

    private var effectiveScale: CGFloat {
        min(max(mapScale * liveScale, 0.50), 1.55)
    }

    var body: some View {
        let p = JalaaPalette.value(theme)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if nodes.isEmpty {
                    emptyState(p)
                } else {
                    compactHeader(p)
                    compactControls(p)
                    board(p)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 112)
        }
        .onAppear { loadMapOffsets() }
        .sheet(item: $selected) { node in
            NodeDetailView(node: node, source: boardSource, theme: theme)
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuiz) {
            QuizSheet(nodes: nodes, theme: theme)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func compactHeader(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(boardTitle.isEmpty ? "لوحتي" : boardTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(p.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(nodes.count) مفاهيم")
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
        case 1: conceptWorkspace(p)
        case 2: cardPager(p)
        case 3: timelinePager(p)
        case 4: comparison(p)
        case 5: flowPager(p)
        default: cardPager(p)
        }
    }

    // MARK: - Concept Workspace

    private func conceptWorkspace(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("خريطة المفاهيم")
                        .font(.headline)
                        .foregroundStyle(p.text)
                    Text("حرّك اللوحة بإصبع • قرّب بإصبعين • اسحب العقدة لتعديل مكانها")
                        .font(.caption2)
                        .foregroundStyle(p.muted)
                }

                Spacer()

                HStack(spacing: 4) {
                    mapToolButton("minus", p: p) { setScale(mapScale - 0.12) }
                    mapToolButton("viewfinder", p: p) { fitMap() }
                    mapToolButton("plus", p: p) { setScale(mapScale + 0.12) }
                }
            }

            GeometryReader { geo in
                let viewport = geo.size

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(p.text.opacity(0.018))

                    subtleMapBackground(p)

                    ZStack {
                        connectionLines(p)

                        ForEach(nodes.indices, id: \.self) { index in
                            conceptNode(nodes[index], index: index, p: p)
                        }
                    }
                    .frame(width: 980, height: 720)
                    .scaleEffect(effectiveScale)
                    .offset(
                        x: centeredPanX(viewport: viewport) + mapPan.width + livePan.width,
                        y: centeredPanY(viewport: viewport) + mapPan.height + livePan.height
                    )
                    .contentShape(Rectangle())
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(canvasPanGesture())
                .simultaneousGesture(canvasZoomGesture())
                .onTapGesture(count: 2) { fitMap() }
            }
            .frame(height: 470)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(p.text.opacity(0.055), lineWidth: 1)
            )

            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                Text("اضغط على أي مفهوم لفتحه")
                Spacer()
                Button("إعادة ترتيب") { resetNodePositions() }
                    .fontWeight(.semibold)
                    .foregroundStyle(p.accent)
            }
            .font(.caption2)
            .foregroundStyle(p.muted)
        }
    }

    private func mapToolButton(_ icon: String, p: JalaaPalette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.text)
                .frame(width: 31, height: 31)
                .background(p.text.opacity(0.05), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func subtleMapBackground(_ p: JalaaPalette) -> some View {
        Canvas { context, size in
            let step: CGFloat = 34
            var x: CGFloat = step
            while x < size.width {
                var y: CGFloat = step
                while y < size.height {
                    let rect = CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4)
                    context.fill(Path(ellipseIn: rect), with: .color(p.text.opacity(0.045)))
                    y += step
                }
                x += step
            }
        }
        .allowsHitTesting(false)
    }

    private func connectionLines(_ p: JalaaPalette) -> some View {
        Canvas { context, _ in
            guard !nodes.isEmpty else { return }
            let root = positionForNode(0)

            for index in nodes.indices.dropFirst() {
                let target = positionForNode(index)
                let midX = (root.x + target.x) / 2

                var path = Path()
                path.move(to: root)
                path.addCurve(
                    to: target,
                    control1: CGPoint(x: midX, y: root.y),
                    control2: CGPoint(x: midX, y: target.y)
                )
                context.stroke(
                    path,
                    with: .color(p.accent.opacity(index == 1 ? 0.38 : 0.24)),
                    style: StrokeStyle(lineWidth: index == 1 ? 1.8 : 1.25, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func conceptNode(_ node: BoardNodeData, index: Int, p: JalaaPalette) -> some View {
        let base = defaultPosition(index: index)
        let stored = mapOffsets[node.id] ?? .zero
        let isRoot = index == 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(isRoot ? p.accent : p.accent.opacity(0.70))
                    .frame(width: 7, height: 7)

                Text(isRoot ? "الفكرة الرئيسية" : "مفهوم \(index + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isRoot ? p.accent : p.muted)

                Spacer(minLength: 0)
            }

            Text(recall ? "؟" : node.title)
                .font(isRoot ? .body.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(p.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(width: isRoot ? 260 : 220, alignment: .leading)
        .background(
            isRoot ? p.accent.opacity(0.13) : p.secondary.opacity(0.96),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isRoot ? p.accent.opacity(0.48) : p.text.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isRoot ? 0.10 : 0.055), radius: 12, y: 5)
        .position(x: base.x + stored.width, y: base.y + stored.height)
        .highPriorityGesture(nodeDragGesture(node))
        .onTapGesture { selected = node }
    }

    private func nodeDragGesture(_ node: BoardNodeData) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if nodeDragStarts[node.id] == nil {
                    nodeDragStarts[node.id] = mapOffsets[node.id] ?? .zero
                }
                let start = nodeDragStarts[node.id] ?? .zero
                let scale = max(effectiveScale, 0.5)
                mapOffsets[node.id] = CGSize(
                    width: start.width + value.translation.width / scale,
                    height: start.height + value.translation.height / scale
                )
            }
            .onEnded { value in
                let start = nodeDragStarts[node.id] ?? (mapOffsets[node.id] ?? .zero)
                let scale = max(effectiveScale, 0.5)
                mapOffsets[node.id] = CGSize(
                    width: start.width + value.translation.width / scale,
                    height: start.height + value.translation.height / scale
                )
                nodeDragStarts[node.id] = nil
                saveMapOffsets()
            }
    }

    private func canvasPanGesture() -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($livePan) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                mapPan.width += value.translation.width
                mapPan.height += value.translation.height
                clampPan()
            }
    }

    private func canvasZoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($liveScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                setScale(mapScale * value)
            }
    }

    private func setScale(_ value: CGFloat) {
        withAnimation(.easeOut(duration: 0.16)) {
            mapScale = min(max(value, 0.50), 1.55)
            clampPan()
        }
    }

    private func fitMap() {
        withAnimation(.easeInOut(duration: 0.22)) {
            mapScale = 0.72
            mapPan = .zero
        }
    }

    private func resetNodePositions() {
        withAnimation(.easeInOut(duration: 0.2)) {
            mapOffsets = [:]
            nodeDragStarts = [:]
            saveMapOffsets()
            fitMap()
        }
    }

    private func clampPan() {
        let limit: CGFloat = 360
        mapPan.width = min(max(mapPan.width, -limit), limit)
        mapPan.height = min(max(mapPan.height, -limit), limit)
    }

    private func centeredPanX(viewport: CGSize) -> CGFloat {
        (viewport.width - 980 * effectiveScale) / 2
    }

    private func centeredPanY(viewport: CGSize) -> CGFloat {
        (viewport.height - 720 * effectiveScale) / 2
    }

    private func defaultPosition(index: Int) -> CGPoint {
        let root = CGPoint(x: 490, y: 360)
        if index == 0 { return root }

        let positions: [CGPoint] = [
            CGPoint(x: 490, y: 125),
            CGPoint(x: 770, y: 220),
            CGPoint(x: 775, y: 505),
            CGPoint(x: 490, y: 610),
            CGPoint(x: 205, y: 505),
            CGPoint(x: 205, y: 220)
        ]

        if index - 1 < positions.count {
            return positions[index - 1]
        }

        let satellites = max(nodes.count - 1, 1)
        let angle = Double(index - 1) / Double(satellites) * Double.pi * 2 - Double.pi / 2
        return CGPoint(
            x: root.x + CGFloat(cos(angle) * 310),
            y: root.y + CGFloat(sin(angle) * 245)
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
                    HStack(spacing: 8) {
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

// MARK: - Concept Detail

private enum DetailMode: String, CaseIterable {
    case explain = "شرح"
    case deepen = "تعمّق"
    case example = "مثال"

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
                VStack(alignment: .leading, spacing: 18) {
                    conceptHeader(p)
                    modePicker(p)
                    answerPanel(p)
                    Divider().overlay(p.text.opacity(0.08))
                    askSection(p)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .task { await run(mode) }
    }

    private func conceptHeader(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("المفهوم")
                .font(.caption.weight(.semibold))
                .foregroundStyle(p.accent)

            Text(node.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(node.detail)
                .font(.body)
                .foregroundStyle(p.muted)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modePicker(_ p: JalaaPalette) -> some View {
        HStack(spacing: 4) {
            ForEach(DetailMode.allCases, id: \.self) { item in
                Button {
                    mode = item
                    Task { await run(item) }
                } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(mode == item ? p.background : p.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(mode == item ? p.accent : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(p.text.opacity(0.045), in: Capsule())
    }

    @ViewBuilder
    private func answerPanel(_ p: JalaaPalette) -> some View {
        if loading {
            HStack(spacing: 10) {
                ProgressView().tint(p.accent)
                Text("جلاء يرتب الفكرة…")
                    .font(.subheadline)
                    .foregroundStyle(p.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        } else if !result.isEmpty {
            Text(result)
                .font(.body)
                .foregroundStyle(p.text)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if !errorText.isEmpty {
            Text(errorText)
                .font(.caption2)
                .foregroundStyle(p.muted)
        }
    }

    private func askSection(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("اسأل عن الفكرة")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(p.text)

            HStack(alignment: .bottom, spacing: 8) {
                TextField("مثلاً: لماذا يحدث هذا؟", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .foregroundStyle(p.text)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(p.text.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))

                Button { Task { await ask() } } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(p.background)
                        .frame(width: 42, height: 42)
                        .background(p.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
            }
        }
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
                errorText = "تعذر الاتصال بالذكاء الآن؛ عرضت نتيجة محلية."
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
                errorText = "تعذر الاتصال بالذكاء الآن؛ أجبت من المحتوى المحلي."
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
