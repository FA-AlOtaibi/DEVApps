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
    @State private var errorMessage = ""
    @State private var showError = false

    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""
    @AppStorage("jalaaMotionEnabled") private var motionEnabled = true

    private let steps = ["قراءة المحتوى","استخراج المفاهيم","ربط العلاقات","اختيار التخطيط","بناء اللوحة"]

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header(p)
                hero(p)
                sourceGrid(p)
                recentSection(p)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 130)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf,.plainText,.text,.audio]) { result in
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
            Circle().fill(.ultraThinMaterial).frame(width: 44,height: 44).overlay(Image(systemName:"person.crop.circle.fill").font(.title2).foregroundStyle(p.text))
        }
    }

    private func hero(_ p: JalaaPalette) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.thinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 34).stroke(p.text.opacity(0.10)))
                .frame(height: 228)
            Circle().fill(p.accent.opacity(0.18)).frame(width: 145,height: 145).blur(radius: 4).offset(x: 215,y:-62)
            Circle().stroke(p.text.opacity(0.12), lineWidth: 1).frame(width: 92,height: 92).offset(x: 265,y:18).scaleEffect(pulse ? 1.12 : 0.92).opacity(pulse ? 0.28 : 0.75)
            VStack(alignment: .leading, spacing: 10) {
                Text("ابدأ من أي محتوى").font(.title.bold()).foregroundStyle(p.text)
                Text("ارفع PDF أو ملفًا نصيًا، أو الصق نصك. جلاء يبني اللوحة من المحتوى الذي أدخلته أنت فقط.")
                    .font(.body).foregroundStyle(p.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                Button { showingImporter = true } label: {
                    Label("إنشاء لوحة", systemImage: "plus")
                        .font(.headline).foregroundStyle(p.background).padding(.horizontal,18).padding(.vertical,12)
                        .background(p.accent, in: Capsule())
                }.padding(.top,6)
            }.padding(24)
        }
        .onAppear {
            guard motionEnabled else { pulse = false; return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)){ pulse.toggle() }
        }
    }

    private func sourceGrid(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مصدر جديد").font(.headline).foregroundStyle(p.text)
            HStack(spacing: 12) {
                sourceCard("doc.fill","ملف", p) { showingImporter = true }
                sourceCard("text.alignright","نص", p) { showingTextEntry = true }
                sourceCard("waveform","صوت", p) { presentError("رفع الصوت موجود في الواجهة، لكن التفريغ الصوتي الفعلي يحتاج خدمة Speech/AI ولم أربطه بعد. لن أنشئ لك محتوى وهميًا بدلًا منه.") }
            }
        }
    }

    private func sourceCard(_ icon:String,_ title:String,_ p:JalaaPalette, action:@escaping()->Void)->some View {
        Button(action: action) {
            VStack(spacing:10){ Image(systemName: icon).font(.title2); Text(title).font(.subheadline.bold()) }
                .foregroundStyle(p.text).frame(maxWidth:.infinity).frame(height:95)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius:22,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:22).stroke(p.text.opacity(0.09)))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func recentSection(_ p: JalaaPalette) -> some View {
        VStack(alignment:.leading,spacing:12){
            HStack{Text("آخر اللوحات").font(.headline).foregroundStyle(p.text);Spacer()}
            if boardSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing:12){
                    Image(systemName:"square.stack.3d.up.slash").font(.title2).foregroundStyle(p.accent)
                    VStack(alignment:.leading,spacing:4){Text("لا توجد لوحات بعد").font(.headline).foregroundStyle(p.text);Text("أول لوحة تنشئها ستظهر هنا تلقائيًا.").font(.caption).foregroundStyle(p.muted)}
                    Spacer()
                }.padding(18).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:20,style:.continuous))
            } else {
                Button { tab = 1 } label: {
                    HStack(spacing:14){
                        ZStack{Circle().fill(p.text.opacity(0.05)).frame(width:52,height:52);Circle().stroke(p.accent,lineWidth:3).frame(width:52,height:52);Image(systemName:"circle.hexagongrid.fill").foregroundStyle(p.text)}
                        VStack(alignment:.leading,spacing:4){Text(boardTitle.isEmpty ? "لوحتي" : boardTitle).font(.subheadline.bold()).foregroundStyle(p.text).lineLimit(2);Text("لوحة محفوظة على الجهاز").font(.caption).foregroundStyle(p.muted)}
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
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(p.text)
                        .padding(12)
                        .background(p.text.opacity(0.05),in:RoundedRectangle(cornerRadius:20))
                        .overlay(RoundedRectangle(cornerRadius:20).stroke(p.text.opacity(0.08)))
                    Button {
                        let text = pastedText.trimmingCharacters(in:.whitespacesAndNewlines)
                        guard text.count >= 12 else { presentError("اكتب نصًا أطول قليلًا حتى يستطيع جلاء بناء لوحة مفيدة."); return }
                        boardSource = text
                        boardTitle = BoardEngine.suggestedTitle(from:text)
                        showingTextEntry = false
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.25){ startAnalysis() }
                    } label: {
                        Text("حلّل النص").font(.headline).foregroundStyle(p.background).frame(maxWidth:.infinity).padding(.vertical,14).background(p.accent,in:RoundedRectangle(cornerRadius:18))
                    }
                }.padding(20)
            }
            .navigationTitle("ألصق النص")
            .toolbar { ToolbarItem(placement:.topBarLeading){Button("إلغاء"){showingTextEntry=false}.foregroundStyle(p.accent)} }
        }
    }

    private func importFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        var text = ""
        if ext == "pdf" {
            text = PDFDocument(url:url)?.string ?? ""
        } else if ["txt","md","rtf"].contains(ext) {
            text = (try? String(contentsOf:url,encoding:.utf8)) ?? ""
        } else {
            presentError("هذا النوع لا أستطيع استخراج نصه محليًا الآن. استخدم PDF أو TXT، أو الصق النص مباشرة.")
            return
        }
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
        analysisVisible = true
        Task {
            for index in steps.indices {
                try? await Task.sleep(nanoseconds: 420_000_000)
                await MainActor.run { withAnimation(.easeInOut(duration: 0.25)) { analysisStep = index + 1 } }
            }
            await MainActor.run { withAnimation(.spring(response:0.35,dampingFraction:0.8)) { analysisDone = true } }
            try? await Task.sleep(nanoseconds: 650_000_000)
            await MainActor.run {
                analysisVisible = false
                withAnimation(.spring(response:0.35,dampingFraction:0.84)) { tab = 1 }
            }
        }
    }

    private func analysisSheet(_ p: JalaaPalette) -> some View {
        ZStack {
            p.background.ignoresSafeArea()
            RadialGradient(colors:[p.accent.opacity(0.18),.clear],center:.topTrailing,startRadius:0,endRadius:420).ignoresSafeArea()
            VStack(alignment:.leading, spacing:22) {
                Capsule().fill(p.text.opacity(0.22)).frame(width:46,height:5).frame(maxWidth:.infinity)
                HStack {
                    VStack(alignment:.leading,spacing:4){
                        Text(analysisDone ? "تم تجهيز لوحتك" : "جلاء يبني اللوحة الآن").font(.title2.bold()).foregroundStyle(p.text)
                        Text(analysisDone ? "سيتم فتحها تلقائيًا" : "نحلل المحتوى الذي أدخلته الآن").foregroundStyle(p.muted)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(p.text.opacity(0.10),lineWidth:5)
                        Circle().trim(from:0,to:CGFloat(analysisStep)/CGFloat(steps.count)).stroke(p.accent,style:StrokeStyle(lineWidth:5,lineCap:.round)).rotationEffect(.degrees(-90))
                        if analysisDone { Image(systemName:"checkmark").font(.headline.bold()).foregroundStyle(p.accent) }
                        else { Text("\(Int(Double(analysisStep)/Double(steps.count)*100))%").font(.caption.bold()).foregroundStyle(p.text) }
                    }.frame(width:64,height:64)
                }
                VStack(spacing:10) {
                    ForEach(steps.indices,id:\.self){i in
                        HStack(spacing:12){
                            Image(systemName: i < analysisStep ? "checkmark.circle.fill" : i == analysisStep ? "circle.dotted" : "circle").foregroundStyle(i < analysisStep ? p.accent : p.muted)
                            Text(steps[i]).foregroundStyle(i <= analysisStep ? p.text : p.muted)
                            Spacer()
                        }.padding(14).background(i == analysisStep && !analysisDone ? p.accent.opacity(0.10) : p.text.opacity(0.035), in: RoundedRectangle(cornerRadius:16,style:.continuous))
                    }
                }
                if analysisDone {
                    Label("جاهزة — جاري فتح لوحتك",systemImage:"arrow.left.circle.fill")
                        .font(.headline).foregroundStyle(p.background).frame(maxWidth:.infinity).padding(.vertical,14).background(p.accent,in:RoundedRectangle(cornerRadius:18))
                }
                Spacer()
            }.padding(24)
        }.interactiveDismissDisabled(!analysisDone)
    }

    private func presentError(_ message:String) { errorMessage=message; showError=true }
}
