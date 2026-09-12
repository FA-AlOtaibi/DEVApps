import SwiftUI

struct StudyBoardView: View {
    @State private var recall = false
    @State private var selected: BoardNodeData? = nil
    @State private var layout = 0
    @State private var showQuiz = false

    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""
    @AppStorage("jalaaBoardNodesJSON") private var boardNodesJSON = ""
    @AppStorage("jalaaSuggestedLayout") private var suggestedLayout = 2

    private let layouts = ["ذكي","خريطة","بطاقات","خط زمني","مقارنة","مسار"]
    private var nodes:[BoardNodeData] {
        let saved = BoardEngine.decode(boardNodesJSON)
        return saved.isEmpty ? BoardEngine.nodes(from:boardSource) : saved
    }
    private var resolvedLayout:Int { layout == 0 ? max(1, min(5, suggestedLayout)) : layout }

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators:false){
            VStack(alignment:.leading,spacing:16){
                if nodes.isEmpty { emptyState(p) }
                else {
                    header(p)
                    compactToolbar(p)
                    board(p)
                    insight(p)
                }
            }.padding(.horizontal,18).padding(.top,16).padding(.bottom,120)
        }
        .sheet(item:$selected){node in NodeSheet(node:node, source:boardSource, theme:theme)}
        .sheet(isPresented:$showQuiz){QuizSheet(nodes:nodes,theme:theme)}
    }

    private func header(_ p:JalaaPalette)->some View{
        VStack(alignment:.leading,spacing:4){
            Text(boardTitle.isEmpty ? "لوحتي" : boardTitle).font(.system(size:30,weight:.bold)).foregroundStyle(p.text).fixedSize(horizontal:false,vertical:true)
            Text("اضغط على أي مفهوم للتفاصيل").font(.subheadline).foregroundStyle(p.muted)
        }
    }

    private func compactToolbar(_ p:JalaaPalette)->some View{
        HStack(spacing:10){
            Menu {
                ForEach(layouts.indices,id:\.self){i in
                    Button(layouts[i]) { withAnimation(.spring(response:0.3,dampingFraction:0.86)){ layout=i } }
                }
            } label: {
                HStack(spacing:7){
                    Image(systemName:"rectangle.3.group")
                    Text(layout == 0 ? "ذكي • \(layouts[resolvedLayout])" : layouts[layout]).lineLimit(1)
                    Image(systemName:"chevron.down").font(.caption2)
                }.font(.subheadline.bold()).foregroundStyle(p.text)
                    .padding(.horizontal,13).padding(.vertical,10)
                    .background(p.text.opacity(0.055),in:Capsule())
            }
            Spacer()
            Button{recall.toggle()} label:{
                Image(systemName: recall ? "eye.slash.fill":"brain.head.profile")
                    .frame(width:40,height:40).foregroundStyle(recall ? p.background:p.text)
                    .background(recall ? p.accent:p.text.opacity(0.055),in:Circle())
            }.buttonStyle(.plain)
            Button{showQuiz=true} label:{
                Image(systemName:"bolt.fill").frame(width:40,height:40).foregroundStyle(p.text)
                    .background(p.text.opacity(0.055),in:Circle())
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder private func board(_ p:JalaaPalette)->some View{
        switch resolvedLayout {
        case 1: networkMap(p)
        case 2: cardsCarousel(p)
        case 3: horizontalTimeline(p)
        case 4: comparison(p)
        case 5: flow(p)
        default: cardsCarousel(p)
        }
    }

    private func networkMap(_ p:JalaaPalette)->some View{
        GeometryReader { geo in
            let count = min(nodes.count,6)
            let center = CGPoint(x:geo.size.width/2,y:geo.size.height/2)
            ZStack {
                RoundedRectangle(cornerRadius:28,style:.continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius:28).stroke(p.text.opacity(0.08)))
                Path { path in
                    for i in 0..<count {
                        let pt = networkPoint(i,count:count,size:geo.size)
                        path.move(to:center); path.addLine(to:pt)
                        if i > 0 {
                            let prev = networkPoint(i-1,count:count,size:geo.size)
                            path.move(to:prev); path.addLine(to:pt)
                        }
                    }
                    if count > 2 {
                        let a = networkPoint(0,count:count,size:geo.size)
                        let b = networkPoint(count-1,count:count,size:geo.size)
                        path.move(to:a); path.addLine(to:b)
                    }
                }.stroke(p.accent.opacity(0.30),style:StrokeStyle(lineWidth:1.3,lineCap:.round,dash:[5,5]))

                Button{selected=nodes[0]} label:{
                    VStack(spacing:5){
                        Image(systemName:"circle.hexagongrid.fill").foregroundStyle(p.accent)
                        Text(recall ? "؟" : (boardTitle.isEmpty ? nodes[0].title : boardTitle)).font(.caption.bold()).multilineTextAlignment(.center).lineLimit(3)
                    }.foregroundStyle(p.text).frame(width:132,height:88)
                        .background(p.accent.opacity(0.13),in:RoundedRectangle(cornerRadius:25,style:.continuous))
                        .overlay(RoundedRectangle(cornerRadius:25).stroke(p.accent.opacity(0.45)))
                }.buttonStyle(.plain).position(center)

                ForEach(Array(nodes.prefix(count).enumerated()),id:\.element.id){index,node in
                    let pt = networkPoint(index,count:count,size:geo.size)
                    Button{selected=node} label:{
                        Text(recall ? "؟" : node.title).font(.caption2.bold()).multilineTextAlignment(.center).lineLimit(3)
                            .foregroundStyle(p.text).frame(width:110,height:58)
                            .background(.thinMaterial,in:RoundedRectangle(cornerRadius:18,style:.continuous))
                            .overlay(RoundedRectangle(cornerRadius:18).stroke(p.text.opacity(0.10)))
                    }.buttonStyle(.plain).position(pt)
                }
            }
        }.frame(height:390)
    }

    private func networkPoint(_ index:Int,count:Int,size:CGSize)->CGPoint{
        guard count > 0 else { return CGPoint(x:size.width/2,y:size.height/2) }
        let angle = (Double(index)/Double(count))*Double.pi*2 - Double.pi/2
        let rx = max(95.0, Double(size.width)*0.34)
        let ry = max(110.0, Double(size.height)*0.34)
        return CGPoint(x:Double(size.width)/2 + cos(angle)*rx, y:Double(size.height)/2 + sin(angle)*ry)
    }

    private func cardsCarousel(_ p:JalaaPalette)->some View{
        ScrollView(.horizontal,showsIndicators:false){
            HStack(spacing:12){
                ForEach(nodes){node in
                    Button{selected=node} label:{
                        VStack(alignment:.leading,spacing:12){
                            Image(systemName:"point.3.connected.trianglepath.dotted").foregroundStyle(p.accent)
                            Text(recall ? "؟" : node.title).font(.title3.bold()).foregroundStyle(p.text).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
                            if !recall { Text(node.detail).font(.subheadline).foregroundStyle(p.muted).lineLimit(5).multilineTextAlignment(.leading) }
                            Spacer(minLength:0)
                            Text("افتح المفهوم").font(.caption.bold()).foregroundStyle(p.accent)
                        }.frame(width:250,height:210,alignment:.topLeading).padding(18)
                            .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:26,style:.continuous))
                            .overlay(RoundedRectangle(cornerRadius:26).stroke(p.text.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal,1)
        }.scrollTargetBehavior(.viewAligned)
    }

    private func horizontalTimeline(_ p:JalaaPalette)->some View{
        ScrollView(.horizontal,showsIndicators:false){
            HStack(spacing:0){
                ForEach(Array(nodes.enumerated()),id:\.element.id){index,node in
                    HStack(spacing:0){
                        Button{selected=node} label:{
                            VStack(alignment:.leading,spacing:10){
                                HStack{Text(String(format:"%02d",index+1)).font(.caption.bold()).foregroundStyle(p.accent);Spacer();Circle().fill(p.accent).frame(width:9,height:9)}
                                Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).lineLimit(3)
                                Text(recall ? "اضغط للكشف" : node.detail).font(.caption).foregroundStyle(p.muted).multilineTextAlignment(.leading).lineLimit(5)
                                Spacer()
                            }.frame(width:235,height:175,alignment:.topLeading).padding(16)
                                .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22,style:.continuous))
                                .overlay(RoundedRectangle(cornerRadius:22).stroke(p.text.opacity(0.08)))
                        }.buttonStyle(.plain)
                        if index < nodes.count-1 { Rectangle().fill(p.accent.opacity(0.35)).frame(width:28,height:2) }
                    }
                }
            }.padding(.horizontal,1)
        }.scrollTargetBehavior(.viewAligned)
    }

    private func comparison(_ p:JalaaPalette)->some View{
        let first=nodes[0]; let second=nodes.count>1 ? nodes[1]:nodes[0]
        return VStack(spacing:12){
            HStack(alignment:.top,spacing:10){compareCard(first,"A",p);compareCard(second,"B",p)}
            if nodes.count > 2 {
                Button{selected=nodes[2]} label:{
                    HStack{Image(systemName:"link").foregroundStyle(p.accent);Text(recall ? "؟" : nodes[2].title).font(.subheadline.bold()).foregroundStyle(p.text);Spacer();Image(systemName:"chevron.left").foregroundStyle(p.muted)}
                        .padding(15).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:18))
                }.buttonStyle(.plain)
            }
        }
    }

    private func compareCard(_ node:BoardNodeData,_ badge:String,_ p:JalaaPalette)->some View{
        Button{selected=node} label:{
            VStack(alignment:.leading,spacing:10){
                Text(badge).font(.caption.bold()).foregroundStyle(p.background).frame(width:28,height:28).background(p.accent,in:Circle())
                Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).lineLimit(4)
                if !recall {Text(node.detail).font(.caption).foregroundStyle(p.muted).multilineTextAlignment(.leading).lineLimit(6)}
                Spacer()
            }.frame(maxWidth:.infinity,minHeight:190,alignment:.topLeading).padding(15).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22))
        }.buttonStyle(.plain)
    }

    private func flow(_ p:JalaaPalette)->some View{
        ScrollView(.horizontal,showsIndicators:false){
            HStack(spacing:8){
                ForEach(Array(nodes.enumerated()),id:\.element.id){index,node in
                    Button{selected=node} label:{
                        VStack(spacing:8){
                            Text("\(index+1)").font(.caption.bold()).foregroundStyle(p.background).frame(width:27,height:27).background(p.accent,in:Circle())
                            Text(recall ? "؟" : node.title).font(.caption.bold()).foregroundStyle(p.text).multilineTextAlignment(.center).lineLimit(4)
                        }.frame(width:128,height:120).background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
                    }.buttonStyle(.plain)
                    if index < nodes.count-1 {Image(systemName:"arrow.left").foregroundStyle(p.accent)}
                }
            }
        }
    }

    private func insight(_ p:JalaaPalette)->some View{
        HStack(alignment:.top,spacing:12){
            Image(systemName:"sparkles").foregroundStyle(p.accent).padding(.top,2)
            VStack(alignment:.leading,spacing:5){
                Text("الخلاصة").font(.headline).foregroundStyle(p.text)
                Text(nodes.first?.detail ?? "").font(.subheadline).foregroundStyle(p.muted).lineLimit(4).fixedSize(horizontal:false,vertical:true)
            }
        }.padding(16).background(p.text.opacity(0.035),in:RoundedRectangle(cornerRadius:20))
    }

    private func emptyState(_ p:JalaaPalette)->some View{
        VStack(spacing:16){
            Image(systemName:"square.stack.3d.up.slash").font(.system(size:38)).foregroundStyle(p.accent)
            Text("لا توجد لوحة بعد").font(.title2.bold()).foregroundStyle(p.text)
            Text("ارجع للرئيسية وارفع PDF أو TXT أو الصق نصًا.").multilineTextAlignment(.center).foregroundStyle(p.muted)
        }.frame(maxWidth:.infinity).padding(.vertical,70)
    }
}

struct NodeSheet: View {
    let node:BoardNodeData
    let source:String
    let theme:Int
    @State private var result:String? = nil
    @State private var question = ""
    @State private var loading = false
    @State private var errorText = ""
    @AppStorage("jalaaAIModel") private var aiModel = "gpt-5.6-luna"

    var body:some View{
        let p=JalaaPalette.value(theme)
        ZStack{
            p.background.ignoresSafeArea()
            ScrollView{
                VStack(alignment:.leading,spacing:18){
                    Capsule().fill(p.text.opacity(0.22)).frame(width:44,height:5).frame(maxWidth:.infinity)
                    Text(node.title).font(.system(size:30,weight:.bold)).foregroundStyle(p.text).fixedSize(horizontal:false,vertical:true)
                    Text(node.detail).font(.body).foregroundStyle(p.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)

                    HStack(spacing:8){
                        aiAction("اشرح","text.bubble","explain",p)
                        aiAction("تعمّق","book.closed","deepen",p)
                        aiAction("مثال","lightbulb","example",p)
                    }

                    VStack(alignment:.leading,spacing:10){
                        TextField("اسأل عن هذه النقطة…",text:$question,axis:.vertical)
                            .foregroundStyle(p.text).padding(13).background(p.text.opacity(0.05),in:RoundedRectangle(cornerRadius:15))
                        Button{ask(p)} label:{
                            HStack{if loading{ProgressView().tint(p.background)};Label("اسأل جلاء",systemImage:"sparkles")}.font(.headline).foregroundStyle(p.background).frame(maxWidth:.infinity).padding(.vertical,12).background(p.accent,in:RoundedRectangle(cornerRadius:15))
                        }.disabled(loading || question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    }

                    if !errorText.isEmpty {Text(errorText).font(.caption).foregroundStyle(.red)}
                    if let result {
                        Text(result).foregroundStyle(p.text).lineSpacing(5).fixedSize(horizontal:false,vertical:true)
                            .padding(16).background(p.accent.opacity(0.09),in:RoundedRectangle(cornerRadius:18))
                    }
                }.padding(22).padding(.bottom,30)
            }
        }
    }

    private func aiAction(_ title:String,_ icon:String,_ kind:String,_ p:JalaaPalette)->some View{
        Button{run(kind)} label:{
            VStack(spacing:7){Image(systemName:icon);Text(title).font(.caption.bold())}.foregroundStyle(p.text).frame(maxWidth:.infinity).padding(.vertical,11).background(p.text.opacity(0.05),in:RoundedRectangle(cornerRadius:15))
        }.buttonStyle(.plain).disabled(loading)
    }

    private func run(_ kind:String){
        loading=true; errorText=""
        Task{
            do { let text=try await JalaaAIService.nodeAction(kind,node:node,source:source,model:aiModel); await MainActor.run{result=text;loading=false} }
            catch {
                let fallback = kind == "explain" ? BoardEngine.explain(node) : kind == "deepen" ? BoardEngine.deepen(node,source:source) : BoardEngine.example(node)
                await MainActor.run{result=fallback;errorText="الـAI غير متصل الآن؛ عرضت لك نتيجة محلية بدلًا منه.";loading=false}
            }
        }
    }

    private func ask(_ p:JalaaPalette){
        let q=question.trimmingCharacters(in:.whitespacesAndNewlines); guard !q.isEmpty else{return}
        loading=true;errorText=""
        Task{
            do{let text=try await JalaaAIService.nodeAction("ask",node:node,source:source,question:q,model:aiModel);await MainActor.run{result=text;loading=false}}
            catch{await MainActor.run{result=BoardEngine.answer(question:q,node:node,source:source);errorText="تعذر AI؛ هذه إجابة مستخرجة محليًا من المحتوى.";loading=false}}
        }
    }
}

struct QuizSheet: View {
    let nodes:[BoardNodeData]
    let theme:Int
    @State private var selected:Int?=nil
    var body:some View{
        let p=JalaaPalette.value(theme)
        let options=Array(nodes.prefix(min(4,nodes.count)))
        ZStack{p.background.ignoresSafeArea();VStack(alignment:.leading,spacing:18){
            Capsule().fill(p.text.opacity(0.22)).frame(width:44,height:5).frame(maxWidth:.infinity)
            Text("اختبار سريع").font(.title.bold()).foregroundStyle(p.text)
            Text("أي عنوان يطابق الفكرة التالية؟").foregroundStyle(p.muted)
            Text(nodes.first?.detail ?? "").font(.headline).foregroundStyle(p.text).padding(16).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:18))
            ForEach(options.indices,id:\.self){i in Button{selected=i} label:{HStack{Text(options[i].title).multilineTextAlignment(.leading);Spacer();if selected==i{Image(systemName:i==0 ? "checkmark.circle.fill":"xmark.circle.fill").foregroundStyle(i==0 ? .green:.red)}}.foregroundStyle(p.text).padding(14).background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain)}
            Spacer()
        }.padding(22)}
    }
}
