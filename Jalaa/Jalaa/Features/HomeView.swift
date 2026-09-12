import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var showingImporter = false
    @State private var pastedText = ""
    @State private var pulse = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                hero
                sourceGrid
                recentSection
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 130)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf,.plainText,.text,.audio]) { _ in }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("جلاء").font(.system(size: 34, weight: .black, design: .rounded))
                Text("حوّل التعقيد إلى وضوح").font(.subheadline).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Circle().fill(.ultraThinMaterial).frame(width: 44,height: 44).overlay(Image(systemName:"person.crop.circle.fill").font(.title2))
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.thinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.white.opacity(0.12)))
                .frame(height: 225)
            Circle().fill(Color(red:0.88,green:0.82,blue:0.68).opacity(0.24)).frame(width: 140,height: 140).blur(radius: 2).offset(x: 210,y:-60)
            Circle().stroke(Color.white.opacity(0.16), lineWidth: 1).frame(width: 90,height: 90).offset(x: 260,y:20).scaleEffect(pulse ? 1.12 : 0.92).opacity(pulse ? 0.35 : 0.8)
            VStack(alignment: .leading, spacing: 10) {
                Text("ابدأ من أي شيء").font(.title.bold())
                Text("ملف، محاضرة، أو نص طويل. جلاء يعيد بناء المعرفة كلوحة يمكنك فهمها واسترجاعها.")
                    .font(.body).foregroundStyle(.white.opacity(0.7)).lineSpacing(4)
                Button { showingImporter = true } label: {
                    Label("إنشاء لوحة", systemImage: "plus")
                        .font(.headline).foregroundStyle(.black).padding(.horizontal,18).padding(.vertical,12)
                        .background(Color(red:0.88,green:0.82,blue:0.68), in: Capsule())
                }.padding(.top,6)
            }.padding(24)
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)){ pulse.toggle() } }
    }

    private var sourceGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مصدر جديد").font(.headline)
            HStack(spacing: 12) {
                sourceCard("doc.fill","ملف") { showingImporter = true }
                sourceCard("text.alignright","نص") { pastedText = " " }
                sourceCard("waveform","صوت") { showingImporter = true }
            }
        }
    }
    private func sourceCard(_ icon:String,_ title:String, action:@escaping()->Void)->some View {
        Button(action: action) {
            VStack(spacing:10){ Image(systemName: icon).font(.title2); Text(title).font(.subheadline.bold()) }
                .foregroundStyle(.white).frame(maxWidth:.infinity).frame(height:95)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius:22,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:22).stroke(Color.white.opacity(0.1)))
        }
    }
    private var recentSection: some View {
        VStack(alignment:.leading,spacing:12){
            HStack{Text("آخر اللوحات").font(.headline);Spacer();Text("عرض الكل").font(.caption).foregroundStyle(.white.opacity(0.5))}
            VStack(spacing:10){
                recent("أساسيات الذكاء الاصطناعي","خريطة علاقات","قبل 12 دقيقة",0.82)
                recent("مبادئ الاقتصاد الجزئي","مقارنة","أمس",0.61)
            }
        }
    }
    private func recent(_ title:String,_ kind:String,_ time:String,_ progress:Double)->some View{
        HStack(spacing:14){
            ZStack{Circle().fill(Color.white.opacity(0.06)).frame(width:52,height:52);Circle().trim(from:0,to:progress).stroke(Color(red:0.88,green:0.82,blue:0.68),style:StrokeStyle(lineWidth:3,lineCap:.round)).rotationEffect(.degrees(-90)).frame(width:52,height:52);Image(systemName:"circle.hexagongrid.fill")}
            VStack(alignment:.leading,spacing:4){Text(title).font(.subheadline.bold());Text("\(kind) • \(time)").font(.caption).foregroundStyle(.white.opacity(0.48))}
            Spacer();Image(systemName:"chevron.left").foregroundStyle(.white.opacity(0.4))
        }.padding(14).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:20,style:.continuous))
    }
}
