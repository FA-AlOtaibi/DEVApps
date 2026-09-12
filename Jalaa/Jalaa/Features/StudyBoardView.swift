import SwiftUI

struct StudyBoardView: View {
    @State private var recall = false
    @State private var selected: KnowledgeNode? = nil
    @State private var layout = 0
    @AppStorage("jalaaTheme") private var theme = 0

    private let layouts = ["ذكي","خريطة","بطاقات","خط زمني","مقارنة","مسار"]
    private let nodes = [
        KnowledgeNode(title:"المفهوم الأساسي", detail:"التضخم هو ارتفاع مستمر في المستوى العام للأسعار، وليس مجرد ارتفاع سعر منتج واحد."),
        KnowledgeNode(title:"تضخم الطلب", detail:"يحدث عندما يرتفع الطلب الكلي أسرع من قدرة الاقتصاد على زيادة الإنتاج."),
        KnowledgeNode(title:"تضخم التكاليف", detail:"ينشأ عندما ترتفع تكاليف الإنتاج مثل الطاقة والأجور والمواد الخام."),
        KnowledgeNode(title:"الأثر على القوة الشرائية", detail:"مع ارتفاع الأسعار تقل كمية السلع والخدمات التي يمكن للوحدة النقدية شراؤها."),
        KnowledgeNode(title:"أدوات المواجهة", detail:"قد تستخدم البنوك المركزية أسعار الفائدة والسيولة للحد من ضغوط الأسعار."),
        KnowledgeNode(title:"القياس", detail:"يُقاس عادةً بمؤشرات مثل الرقم القياسي لأسعار المستهلك مع مقارنة التغير عبر الزمن.")
    ]

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators:false){
            VStack(alignment:.leading,spacing:18){
                HStack(alignment:.top){
                    VStack(alignment:.leading,spacing:5){
                        Text("لوحتي").font(.largeTitle.bold()).foregroundStyle(p.text)
                        Text("التضخم الاقتصادي — ملخص مترابط").foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                    }
                    Spacer()
                    Button(action: { recall.toggle() }) {
                        Image(systemName: recall ? "eye.slash.fill" : "eye.fill")
                            .padding(12)
                            .background(.thinMaterial, in: Circle())
                            .foregroundStyle(p.text)
                    }
                }
                layoutPicker(p)
                board(p)
                HStack(spacing:10){chip("Recall", "brain.head.profile", recall,p);chip("Quiz","bolt.fill",false,p);chip("تخصيص","slider.horizontal.3",false,p)}
                insight(p)
            }.padding(.horizontal,20).padding(.top,18).padding(.bottom,130)
        }
        .sheet(item:$selected){node in NodeSheet(node:node, theme:theme)}
    }

    private func layoutPicker(_ p:JalaaPalette) -> some View {
        VStack(alignment:.leading,spacing:10){
            HStack{Text("استخراج التخطيط").font(.headline).foregroundStyle(p.text);Spacer();Label("Smart Layout",systemImage:"point.3.connected.trianglepath.dotted").font(.caption).foregroundStyle(p.accent)}
            ScrollView(.horizontal,showsIndicators:false){
                HStack(spacing:8){
                    ForEach(layouts.indices,id:\.self){i in
                        Button{withAnimation(.spring(response:0.32,dampingFraction:0.82)){layout=i}} label:{
                            Text(layouts[i]).font(.caption.bold()).padding(.horizontal,14).padding(.vertical,9)
                                .background(layout == i ? p.accent : p.text.opacity(0.055),in:Capsule())
                                .foregroundStyle(layout == i ? p.background : p.text)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func board(_ p:JalaaPalette) -> some View {
        switch layout {
        case 1: mindMap(p)
        case 2: cardsGrid(p)
        case 3: timeline(p)
        case 4: comparison(p)
        case 5: flow(p)
        default: smartBoard(p)
        }
    }

    private func smartBoard(_ p:JalaaPalette) -> some View {
        VStack(spacing:14){
            Button{selected=nodes[0]} label:{
                VStack(spacing:7){Text(recall ? "؟" : "التضخم الاقتصادي").font(.title2.bold());Text(recall ? "اختبر ذاكرتك" : "الفكرة المحورية").font(.caption).foregroundStyle(p.muted)}
                    .foregroundStyle(p.text).frame(maxWidth:.infinity).padding(.vertical,28)
                    .background(p.accent.opacity(0.12),in:RoundedRectangle(cornerRadius:28,style:.continuous))
                    .overlay(RoundedRectangle(cornerRadius:28).stroke(p.accent.opacity(0.36)))
            }.buttonStyle(.plain)
            LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],spacing:12){
                ForEach(nodes.dropFirst()){ node in knowledgeCard(node,p,minHeight:154) }
            }
        }
        .padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30,style:.continuous))
        .overlay(RoundedRectangle(cornerRadius:30).stroke(p.text.opacity(0.09)))
    }

    private func mindMap(_ p:JalaaPalette) -> some View {
        VStack(spacing:14){
            Circle().fill(p.accent.opacity(0.13)).frame(width:170,height:170).overlay(
                VStack(spacing:7){Image(systemName:"circle.hexagongrid.fill").foregroundStyle(p.accent);Text(recall ? "؟" : "التضخم").font(.title.bold());Text("الفكرة المركزية").font(.caption).foregroundStyle(p.muted)}.foregroundStyle(p.text)
            )
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12){ForEach(nodes){node in knowledgeCard(node,p,minHeight:142)}}
        }.frame(maxWidth:.infinity).padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func cardsGrid(_ p:JalaaPalette) -> some View {
        LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],spacing:12){
            ForEach(nodes){node in knowledgeCard(node,p,minHeight:176)}
        }.padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func timeline(_ p:JalaaPalette) -> some View {
        VStack(spacing:0){
            ForEach(Array(nodes.enumerated()),id:\.element.id){index,node in
                Button{selected=node} label:{
                    HStack(alignment:.top,spacing:14){
                        VStack(spacing:0){Circle().fill(p.accent).frame(width:12,height:12);if index < nodes.count-1 {Rectangle().fill(p.accent.opacity(0.28)).frame(width:2,height:92)}}
                        VStack(alignment:.leading,spacing:6){Text("0\(index+1)").font(.caption.bold()).foregroundStyle(p.accent);Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true);Text(recall ? "اضغط للكشف" : node.detail).font(.subheadline).foregroundStyle(p.muted).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)}
                        Spacer()
                    }.padding(.vertical,8)
                }.buttonStyle(.plain)
            }
        }.padding(18).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func comparison(_ p:JalaaPalette) -> some View {
        VStack(spacing:12){
            Text("تضخم الطلب × تضخم التكاليف").font(.title3.bold()).foregroundStyle(p.text).frame(maxWidth:.infinity,alignment:.leading)
            HStack(alignment:.top,spacing:12){
                compareColumn(nodes[1], icon:"arrow.up.right.circle.fill",p:p)
                compareColumn(nodes[2], icon:"shippingbox.fill",p:p)
            }
            knowledgeCard(nodes[3],p,minHeight:128)
        }.padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func flow(_ p:JalaaPalette) -> some View {
        VStack(spacing:8){
            ForEach(Array(nodes.enumerated()),id:\.element.id){index,node in
                knowledgeCard(node,p,minHeight:112)
                if index < nodes.count-1 {Image(systemName:"arrow.down").foregroundStyle(p.accent).font(.headline)}
            }
        }.padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func knowledgeCard(_ node:KnowledgeNode,_ p:JalaaPalette,minHeight:CGFloat)->some View{
        Button{selected=node} label:{
            VStack(alignment:.leading,spacing:10){
                Image(systemName:"point.3.filled.connected.trianglepath.dotted").foregroundStyle(p.accent)
                Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
                if !recall {Text(node.detail).font(.caption).foregroundStyle(p.muted).multilineTextAlignment(.leading).lineLimit(4).fixedSize(horizontal:false,vertical:true)}
                Spacer(minLength:0)
            }.frame(maxWidth:.infinity,minHeight:minHeight,alignment:.topLeading).padding(16)
                .background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:22,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:22).stroke(p.text.opacity(0.07)))
        }.buttonStyle(.plain)
    }

    private func compareColumn(_ node:KnowledgeNode,icon:String,p:JalaaPalette)->some View{
        Button{selected=node} label:{VStack(alignment:.leading,spacing:10){Image(systemName:icon).foregroundStyle(p.accent);Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true);Text(recall ? "اضغط للكشف" : node.detail).font(.caption).foregroundStyle(p.muted).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true);Spacer(minLength:0)}.frame(maxWidth:.infinity,minHeight:215,alignment:.topLeading).padding(16).background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:22))}.buttonStyle(.plain)
    }

    private func chip(_ title:String,_ icon:String,_ active:Bool,_ p:JalaaPalette)->some View{HStack(spacing:7){Image(systemName:icon);Text(title).font(.caption.bold()).lineLimit(1)}.padding(.horizontal,11).padding(.vertical,9).background(active ? p.accent : p.text.opacity(0.055),in:Capsule()).foregroundStyle(active ? p.background:p.text)}

    private func insight(_ p:JalaaPalette) -> some View {VStack(alignment:.leading,spacing:8){Text("ما الذي يجب أن تتذكره؟").font(.headline).foregroundStyle(p.text);Text("التضخم ليس رقمًا منفصلًا؛ افهم مصدره أولًا: طلب زائد، تكاليف أعلى، ثم راقب أثره على القوة الشرائية والسياسة النقدية.").foregroundStyle(p.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)}.padding(18).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:22))}
}

struct KnowledgeNode: Identifiable { let id=UUID(); let title:String; let detail:String }

struct NodeSheet: View {
    let node:KnowledgeNode
    let theme:Int
    @Environment(\.dismiss) var dismiss
    var body:some View{
        let p=JalaaPalette.value(theme)
        ZStack{
            p.background.ignoresSafeArea()
            VStack(alignment:.leading,spacing:20){
                Capsule().fill(p.text.opacity(0.25)).frame(width:44,height:5).frame(maxWidth:.infinity)
                Text(node.title).font(.system(size:34,weight:.black)).foregroundStyle(p.text).fixedSize(horizontal:false,vertical:true)
                Text(node.detail).font(.title3).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                Divider().overlay(p.text.opacity(0.1))
                ForEach([("اشرح","play.circle.fill"),("تعمّق","book.closed.fill"),("مثال","square.on.square"),("اسأل جلاء","sparkles")],id:\.0){i in
                    HStack{Image(systemName:i.1).frame(width:30).foregroundStyle(p.accent);Text(i.0).font(.headline).foregroundStyle(p.text);Spacer();Image(systemName:"chevron.left").foregroundStyle(p.muted)}.padding(.vertical,8)
                }
                Spacer()
            }.padding(24)
        }
    }
}
