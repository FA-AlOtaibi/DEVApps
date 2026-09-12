import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Binding var tab: Int
    @State private var showingImporter = false
    @State private var pastedText = ""
    @State private var pulse = false
    @State private var analysisVisible = false
    @State private var analysisStep = 0
    @State private var analysisDone = false
    @AppStorage("jalaaTheme") private var theme = 0

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
            if case .success = result { startAnalysis() }
        }
        .sheet(isPresented: $analysisVisible) { analysisSheet(p) }
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
                Text("ارفع ملفًا أو نصًا أو محاضرة. جلاء يستخرج البنية الأنسب ثم يفتح اللوحة تلقائيًا عند اكتمالها.")
                    .font(.body).foregroundStyle(p.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                Button { showingImporter = true } label: {
                    Label("إنشاء لوحة", systemImage: "plus")
                        .font(.headline).foregroundStyle(p.background).padding(.horizontal,18).padding(.vertical,12)
                        .background(p.accent, in: Capsule())
                }.padding(.top,6)
            }.padding(24)
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)){ pulse.toggle() } }
    }

    private func sourceGrid(_ p: JalaaPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مصدر جديد").font(.headline).foregroundStyle(p.text)
            HStack(spacing: 12) {
                sourceCard("doc.fill","ملف", p) { showingImporter = true }
                sourceCard("text.alignright","نص", p) { startAnalysis() }
                sourceCard("waveform","صوت", p) { showingImporter = true }
            }
        }
    }

    private func sourceCard(_ icon:String,_ title:String,_ p:JalaaPalette, action:@escaping()->Void)->some View {
        Button(action: action) {
            VStack(spacing:10){ Image(systemName: icon).font(.title2); Text(title).font(.subheadline.bold()) }
                .foregroundStyle(p.text).frame(maxWidth:.infinity).frame(height:95)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius:22,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:22).stroke(p.text.opacity(0.09)))
        }
    }

    private func recentSection(_ p: JalaaPalette) -> some View {
        VStack(alignment:.leading,spacing:12){
            HStack{Text("آخر اللوحات").font(.headline).foregroundStyle(p.text);Spacer();Text("عرض الكل").font(.caption).foregroundStyle(p.muted)}
            VStack(spacing:10){
                recent("أساسيات الذكاء الاصطناعي","خريطة علاقات","قبل 12 دقيقة",0.82,p)
                recent("مبادئ الاقتصاد الجزئي","مقارنة","أمس",0.61,p)
            }
        }
    }

    private func recent(_ title:String,_ kind:String,_ time:String,_ progress:Double,_ p:JalaaPalette)->some View{
        HStack(spacing:14){
            ZStack{Circle().fill(p.text.opacity(0.05)).frame(width:52,height:52);Circle().trim(from:0,to:progress).stroke(p.accent,style:StrokeStyle(lineWidth:3,lineCap:.round)).rotationEffect(.degrees(-90)).frame(width:52,height:52);Image(systemName:"circle.hexagongrid.fill").foregroundStyle(p.text)}
            VStack(alignment:.leading,spacing:4){Text(title).font(.subheadline.bold()).foregroundStyle(p.text).lineLimit(2);Text("\(kind) • \(time)").font(.caption).foregroundStyle(p.muted)}
            Spacer();Image(systemName:"chevron.left").foregroundStyle(p.muted)
        }.padding(14).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:20,style:.continuous))
    }

    private func startAnalysis() {
        analysisStep = 0
        analysisDone = false
        analysisVisible = true
        Task {
            for index in steps.indices {
                try? await Task.sleep(nanoseconds: 520_000_000)
                await MainActor.run { withAnimation(.easeInOut(duration: 0.25)) { analysisStep = index + 1 } }
            }
            await MainActor.run {
                withAnimation(.spring(response:0.35,dampingFraction:0.8)) { analysisDone = true }
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
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
                        Text(analysisDone ? "تم تجهيز لوحتك" : "جلاء يبني اللوحة الآن")
                            .font(.title2.bold()).foregroundStyle(p.text)
                        Text(analysisDone ? "سيتم فتحها تلقائيًا" : "لن تحتاج للخروج أو التحقق يدويًا")
                            .foregroundStyle(p.muted)
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
                            Image(systemName: i < analysisStep ? "checkmark.circle.fill" : i == analysisStep ? "circle.dotted" : "circle")
                                .foregroundStyle(i < analysisStep ? p.accent : p.muted)
                            Text(steps[i]).foregroundStyle(i <= analysisStep ? p.text : p.muted)
                            Spacer()
                        }
                        .padding(14)
                        .background(i == analysisStep && !analysisDone ? p.accent.opacity(0.10) : p.text.opacity(0.035), in: RoundedRectangle(cornerRadius:16,style:.continuous))
                    }
                }
                if analysisDone {
                    Label("جاهزة — جاري فتح لوحتك",systemImage:"arrow.left.circle.fill")
                        .font(.headline).foregroundStyle(p.background).frame(maxWidth:.infinity).padding(.vertical,14).background(p.accent,in:RoundedRectangle(cornerRadius:18))
                        .transition(.move(edge:.bottom).combined(with:.opacity))
                }
                Spacer()
            }.padding(24)
        }
        .interactiveDismissDisabled(!analysisDone)
    }
}
