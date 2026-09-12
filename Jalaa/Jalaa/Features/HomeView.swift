import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct HomeView: View {
    @Binding var tab: Int
    @State private var showingImporter = false
    @State private var showingTextEntry = false
    @State private var pastedText = ""
    @State private var pulse = false
    @State private var analysisVisible = false
    @State private var analysisStep = 0
    @State private var analysisDone = false
    @State private var analysisStatus = ""
    @State private var errorMessage = ""
    @State private var showError = false

    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""
    @AppStorage("jalaaBoardNodesJSON") private var boardNodesJSON = ""
    @AppStorage("jalaaSuggestedLayout") private var suggestedLayout = 0
    @AppStorage("jalaaMotionEnabled") private var motionEnabled = true
    @AppStorage("jalaaAIModel") private var aiModel = "gpt-5.6-luna"

    private let steps = ["قراءة المحتوى","فهم المفاهيم","اكتشاف العلاقات","اختيار العرض","بناء اللوحة"]

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header(p)
                hero(p)
                sourceGrid(p)
                recentSection(p)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 130)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf,.plainText,.text]) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure(let error): presentError(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingTextEntry) { textEntrySheet(p) }
        .sheet(isPresented: $analysisVisible) { analysisSheet(p) }
        .alert("تعذر إكمال العملية", isPresented: $showError) { Button("حسنًا", role: .cancel) {} } message: { Text(errorMessage) }
    }

    private func header(_ p: JalaaPalette) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("جلاء").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(p.text)
                Text("حوّل التعقيد إلى وضوح").font(.subheadline).foregroundStyle(p.muted)
            }
            Spacer()
            Circle().fill(.ultraThinMaterial).frame(width: 44,height: 44)
                .overlay(Image(systemName:"person.crop.circle.fill").font(.title2).foregroundStyle(p.text))
        }
    }

    private func hero(_ p: JalaaPalette) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.thinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(p.text.opacity(0.10)))
                .frame(height: 214)
            Circle().fill(p.accent.opacity(0.16)).frame(width: 138,height: 138).blur(radius: 6).offset(x: 220,y:-62)
            if motionEnabled {
                Circle().stroke(p.text.opacity(0.11), lineWidth: 1).frame(width: 88,height: 88).offset(x: 264,y:18)
                    .scaleEffect(pulse ? 1.10 : 0.94).opacity(pulse ? 0.24 : 0.68)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("ابدأ من أي محتوى").font(.title.bold()).foregroundStyle(p.text)
                Text("ارفع PDF أو ألصق نصًا. جلاء يفهم المحتوى ثم يختار طريقة العرض الأنسب تلقائيًا.")
                    .font(.body).foregroundStyle(p.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                HStack(spacing:10) {
                    Button { showingImporter = true } label: {
                        Label("رفع ملف", systemImage: "doc.fill").font(.headline).foregroundStyle(p.background)
                            .padding(.horizontal,16).padding(.vertical,11).background(p.accent, in: Capsule())
                    }
                    Button { showingTextEntry = true } label: {
                        Label("لصق نص", systemImage: "text.alignright").font(.headline).foregroundStyle(p.text)
                            .padding(.horizontal,16).padding(.vertical,11).background(p.text.opacity(0.06), in: Capsule())
                    }
                }.padding(.top,4)
            }.padding(22)
        }
        .onAppear {
            guard motionEnabled else { pulse = false; return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)){ pulse.toggle() }
        }
    }

    private func sourceGrid(_ p: JalaaPalette) -> some View {
        HStack(spacing: 12) {
            sourceCard("doc.fill","PDF / TXT", p) { showingImporter = true }
            sourceCard("text.alignright","نص", p) { showingTextEntry = true }
        }
    }

    private func sourceCard(_ icon:String,_ title:String,_ p:JalaaPalette, action:@escaping()->Void)->some View {
        Button(action: action) {
            HStack(spacing:10){ Image(systemName: icon).font(.title3); Text(title).font(.subheadline.bold()) }
                .foregroundStyle(p.text).frame(maxWidth:.infinity).frame(height:68)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius:20,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:20).stroke(p.text.opacity(0.08)))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func recentSection(_ p: JalaaPalette) -> some View {
        VStack(alignment:.leading,spacing:12){
            Text("لوحتي الأخيرة").font(.headline).foregroundStyle(p.text)
            if boardSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing:12){
                    Image(systemName:"square.stack.3d.up.slash").font(.title2).foregroundStyle(p.accent)
                    VStack(alignment:.leading,spacing:4){Text("ما فيه شيء هنا للحين").font(.headline).foregroundStyle(p.text);Text("أول لوحة تنشئها بتظهر هنا.").font(.caption).foregroundStyle(p.muted)}
                    Spacer()
                }.padding(18).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:20,style:.continuous))
            } else {
                Button { tab = 1 } label: {
                    HStack(spacing:14){
                        ZStack{Circle().fill(p.text.opacity(0.05)).frame(width:52,height:52);Circle().stroke(p.accent,lineWidth:2.5).frame(width:52,height:52);Image(systemName:"circle.hexagongrid.fill").foregroundStyle(p.text)}
                        VStack(alignment:.leading,spacing:4){Text(boardTitle.isEmpty ? "لوحتي" : boardTitle).font(.subheadline.bold()).foregroundStyle(p.text).lineLimit(2);Text("اضغط للمتابعة").font(.caption).foregroundStyle(p.muted)}
                        Spacer();Image(systemName:"chevron.left").foregroundStyle(p.muted)
                    }.padding(14).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:20,style:.continuous))
                }.buttonStyle(.plain)
            }
        }
    }

    private func textEntrySheet(_ p: JalaaPalette) -> some View {
        NavigationStack {
            ZStack {
                p.background.ignoresSafeArea()
                VStack(spacing:16) {
                    TextEditor(text:$pastedText)
                        .scrollContentBackground(.hidden).foregroundStyle(p.text).padding(12)
                        .background(p.text.opacity(0.05),in:RoundedRectangle(cornerRadius:20))
                        .overlay(RoundedRectangle(cornerRadius:20).stroke(p.text.opacity(0.08)))
                    Button {
                        let text = pastedText.trimmingCharacters(in:.whitespacesAndNewlines)
                        guard text.count >= 12 else { presentError("اكتب نصًا أطول قليلًا حتى يستطيع جلاء بناء لوحة مفيدة."); return }
                        boardSource = text
                        showingTextEntry = false
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.2){ startAnalysis() }
                    } label: {
                        Text("حوّله إلى لوحة").font(.headline).foregroundStyle(p.background).frame(maxWidth:.infinity).padding(.vertical,14).background(p.accent,in:RoundedRectangle(cornerRadius:18))
                    }
                }.padding(20)
            }
            .navigationTitle("ألصق المحتوى")
            .toolbar { ToolbarItem(placement:.topBarLeading){Button("إلغاء"){showingTextEntry=false}.foregroundStyle(p.accent)} }
        }
    }

    private func importFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        var text = ""
        if ext == "pdf" { text = PDFDocument(url:url)?.string ?? "" }
        else if ["txt","md","rtf"].contains(ext) { text = (try? String(contentsOf:url,encoding:.utf8)) ?? "" }
        else { presentError("استخدم PDF أو TXT حاليًا، أو الصق النص مباشرة."); return }
        text = text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard text.count >= 12 else { presentError("لم أتمكن من استخراج نص كافٍ من الملف."); return }
        boardSource = text
        let cleanName = url.deletingPathExtension().lastPathComponent
        boardTitle = cleanName.isEmpty ? BoardEngine.suggestedTitle(from:text) : cleanName
        startAnalysis()
    }

    private func startAnalysis() {
        analysisStep = 0
        analysisDone = false
        analysisStatus = JalaaKeychain.load().isEmpty ? "تحليل محلي — أضف مفتاح AI من الإعدادات لتفعيل الذكاء الكامل" : "تحليل ذكي عبر جلاء AI"
        analysisVisible = true

        Task {
            await MainActor.run { analysisStep = 1 }
            try? await Task.sleep(nanoseconds: 260_000_000)
            await MainActor.run { analysisStep = 2 }

            if !JalaaKeychain.load().isEmpty {
                do {
                    let payload = try await JalaaAIService.analyzeBoard(source: boardSource, model: aiModel)
                    let aiNodes = BoardEngine.fromAI(payload)
                    await MainActor.run {
                        boardTitle = payload.title
                        boardNodesJSON = BoardEngine.encode(aiNodes)
                        suggestedLayout = BoardEngine.layoutIndex(for: payload.recommendedLayout)
                        analysisStep = 4
                    }
                } catch {
                    let fallback = BoardEngine.nodes(from: boardSource)
                    await MainActor.run {
                        boardNodesJSON = BoardEngine.encode(fallback)
                        if boardTitle.isEmpty { boardTitle = BoardEngine.suggestedTitle(from: boardSource) }
                        suggestedLayout = 2
                        analysisStatus = "تعذر الاتصال بالـAI — تم بناء لوحة محلية بدلًا من إيقافك"
                    }
                }
            } else {
                let fallback = BoardEngine.nodes(from: boardSource)
                await MainActor.run {
                    boardNodesJSON = BoardEngine.encode(fallback)
                    if boardTitle.isEmpty { boardTitle = BoardEngine.suggestedTitle(from: boardSource) }
                    suggestedLayout = 2
                    analysisStep = 4
                }
            }

            try? await Task.sleep(nanoseconds: 260_000_000)
            await MainActor.run { analysisStep = 5; analysisDone = true }
            try? await Task.sleep(nanoseconds: 520_000_000)
            await MainActor.run {
                analysisVisible = false
                withAnimation(.spring(response:0.32,dampingFraction:0.84)) { tab = 1 }
            }
        }
    }

    private func analysisSheet(_ p: JalaaPalette) -> some View {
        ZStack {
            p.background.ignoresSafeArea()
            RadialGradient(colors:[p.accent.opacity(0.15),.clear],center:.topTrailing,startRadius:0,endRadius:420).ignoresSafeArea()
            VStack(alignment:.leading, spacing:20) {
                Capsule().fill(p.text.opacity(0.22)).frame(width:46,height:5).frame(maxWidth:.infinity)
                HStack {
                    VStack(alignment:.leading,spacing:5){
                        Text(analysisDone ? "لوحتك جاهزة" : "جلاء يفهم المحتوى").font(.title2.bold()).foregroundStyle(p.text)
                        Text(analysisStatus).font(.subheadline).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(p.text.opacity(0.10),lineWidth:5)
                        Circle().trim(from:0,to:CGFloat(analysisStep)/CGFloat(steps.count)).stroke(p.accent,style:StrokeStyle(lineWidth:5,lineCap:.round)).rotationEffect(.degrees(-90))
                        if analysisDone { Image(systemName:"checkmark").font(.headline.bold()).foregroundStyle(p.accent) }
                        else { Text("\(Int(Double(analysisStep)/Double(steps.count)*100))%").font(.caption.bold()).foregroundStyle(p.text) }
                    }.frame(width:62,height:62)
                }
                VStack(spacing:8) {
                    ForEach(steps.indices,id:\.self){i in
                        HStack(spacing:11){
                            Image(systemName: i < analysisStep ? "checkmark.circle.fill" : i == analysisStep ? "circle.dotted" : "circle").foregroundStyle(i < analysisStep ? p.accent : p.muted)
                            Text(steps[i]).foregroundStyle(i <= analysisStep ? p.text : p.muted)
                            Spacer()
                        }.padding(12).background(i == analysisStep && !analysisDone ? p.accent.opacity(0.09) : p.text.opacity(0.028), in: RoundedRectangle(cornerRadius:15,style:.continuous))
                    }
                }
                Spacer()
            }.padding(24)
        }.interactiveDismissDisabled(!analysisDone)
    }

    private func presentError(_ message:String) { errorMessage=message; showError=true }
}
