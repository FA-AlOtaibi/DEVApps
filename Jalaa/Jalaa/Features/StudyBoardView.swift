import SwiftUI

struct StudyBoardView: View {
    @State private var recall = false
    @State private var selected: KnowledgeNode? = nil
    private let nodes = [
        KnowledgeNode(title:"التعلّم الآلي", detail:"أنظمة تتعلم الأنماط من البيانات", x:-105,y:-90),
        KnowledgeNode(title:"معالجة اللغة", detail:"فهم اللغة البشرية وتحليلها", x:105,y:-70),
        KnowledgeNode(title:"الرؤية الحاسوبية", detail:"استخراج المعنى من الصور والفيديو", x:-95,y:85),
        KnowledgeNode(title:"الاستدلال", detail:"اتخاذ قرارات من الأدلة والعلاقات", x:110,y:95)
    ]
    var body: some View {
        ScrollView(showsIndicators:false){
            VStack(alignment:.leading,spacing:18){
                HStack{VStack(alignment:.leading){Text("لوحتي").font(.largeTitle.bold());Text("الذكاء الاصطناعي — نظرة مترابطة").foregroundStyle(.white.opacity(0.55))};Spacer();Button{recall.toggle()}{Image(systemName: recall ? "eye.slash.fill":"eye.fill").padding(12).background(.thinMaterial,in:Circle())}}
                board
                HStack(spacing:10){chip("Recall", "brain.head.profile", recall);chip("Quiz","bolt.fill",false);chip("تخصيص","slider.horizontal.3",false)}
                insight
            }.padding(.horizontal,20).padding(.top,18).padding(.bottom,130)
        }
        .sheet(item:$selected){node in NodeSheet(node:node)}
    }
    private var board: some View {
        ZStack {
            RoundedRectangle(cornerRadius:32,style:.continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius:32).stroke(Color.white.opacity(0.12))).frame(height:440)
            ForEach(nodes){ node in
                Path{p in p.move(to:CGPoint(x:190,y:220));p.addLine(to:CGPoint(x:190+node.x*0.65,y:220+node.y*0.65))}.stroke(Color.white.opacity(0.14),style:StrokeStyle(lineWidth:1,dash:[4,6]))
            }
            Button { selected = KnowledgeNode(title:"المفهوم المركزي", detail:"تقنيات تبني أنظمة قادرة على التعلّم والاستدلال", x:0,y:0) } label:{
                VStack(spacing:8){Text("الذكاء").font(.title2.black());Text("الاصطناعي").font(.headline);Text("المفهوم المركزي").font(.caption2).foregroundStyle(.white.opacity(0.5))}
                .frame(width:145,height:145).background(.thinMaterial,in:Circle()).overlay(Circle().stroke(Color(red:0.88,green:0.82,blue:0.68).opacity(0.45),lineWidth:1.5))
            }.buttonStyle(.plain)
            ForEach(nodes){node in
                Button { selected = node } label:{
                    Text(recall ? "؟" : node.title).font(.caption.bold()).multilineTextAlignment(.center).frame(width:98,height:70)
                        .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:20,style:.continuous)).overlay(RoundedRectangle(cornerRadius:20).stroke(Color.white.opacity(0.1)))
                }.buttonStyle(.plain).offset(x:node.x,y:node.y)
            }
        }
    }
    private func chip(_ title:String,_ icon:String,_ active:Bool)->some View{HStack(spacing:7){Image(systemName:icon);Text(title).font(.caption.bold())}.padding(.horizontal,12).padding(.vertical,9).background(active ? Color(red:0.88,green:0.82,blue:0.68) : Color.white.opacity(0.06),in:Capsule()).foregroundStyle(active ? .black:.white)}
    private var insight: some View {VStack(alignment:.leading,spacing:8){Text("ما الذي يجب أن تتذكره؟").font(.headline);Text("بدل حفظ التعريفات منفصلة، ركّز على العلاقة بين البيانات، النماذج، الاستدلال، ثم التطبيق.").foregroundStyle(.white.opacity(0.68)).lineSpacing(4)}.padding(18).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:22))}
}

struct KnowledgeNode: Identifiable { let id=UUID(); let title:String; let detail:String; let x:CGFloat; let y:CGFloat }
struct NodeSheet: View { let node:KnowledgeNode; @Environment(\.dismiss) var dismiss
    var body:some View{ZStack{Color(red:0.05,green:0.055,blue:0.065).ignoresSafeArea();VStack(alignment:.leading,spacing:20){Capsule().fill(Color.white.opacity(0.25)).frame(width:44,height:5).frame(maxWidth:.infinity);Text(node.title).font(.largeTitle.black());Text(node.detail).font(.title3).foregroundStyle(.white.opacity(0.7));Divider().overlay(Color.white.opacity(0.1));ForEach([("اشرح","play.circle.fill"),("تعمّق","book.closed.fill"),("مثال","square.on.square"),("اسأل جلاء","sparkles")],id:\.0){i in HStack{Image(systemName:i.1).frame(width:30);Text(i.0).font(.headline);Spacer();Image(systemName:"chevron.left").foregroundStyle(.white.opacity(0.35))}.padding(.vertical,8)};Spacer()}.padding(24)}}}
