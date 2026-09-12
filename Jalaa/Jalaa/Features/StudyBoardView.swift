import SwiftUI

struct StudyBoardView: View {
    @State private var recall = false
    @State private var selected: BoardNodeData? = nil
    @State private var layout = 0
    @State private var showQuiz = false
    @State private var showCustomize = false

    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""

    private let layouts = ["ذكي","خريطة","بطاقات","خط زمني","مقارنة","مسار"]
    private var nodes:[BoardNodeData] { BoardEngine.nodes(from:boardSource) }

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators:false){
            VStack(alignment:.leading,spacing:18){
                if nodes.isEmpty { emptyState(p) }
                else {
                    header(p)
                    layoutPicker(p)
                    board(p)
                    actionRow(p)
                    insight(p)
                }
            }.padding(.horizontal,20).padding(.top,18).padding(.bottom,130)
        }
        .sheet(item:$selected){node in NodeSheet(node:node, source:boardSource, theme:theme)}
        .sheet(isPresented:$showQuiz){QuizSheet(nodes:nodes,theme:theme)}
        .sheet(isPresented:$showCustomize){CustomizeSheet(layout:$layout,theme:theme,layouts:layouts)}
    }

    private func header(_ p:JalaaPalette)->some View{
        HStack(alignment:.top){
            VStack(alignment:.leading,spacing:5){
                Text("لوحتي").font(.largeTitle.bold()).foregroundStyle(p.text)
                Text(boardTitle.isEmpty ? "لوحة من محتواك" : boardTitle).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
            }
            Spacer()
            Button(action:{recall.toggle()}){
                Image(systemName:recall ? "eye.slash.fill":"eye.fill").padding(12).background(.thinMaterial,in:Circle()).foregroundStyle(p.text)
            }
        }
    }

    private func actionRow(_ p:JalaaPalette)->some View{
        HStack(spacing:10){
            Button{recall.toggle()} label:{chip("Recall","brain.head.profile",recall,p)}.buttonStyle(.plain)
            Button{showQuiz=true} label:{chip("Quiz","bolt.fill",false,p)}.buttonStyle(.plain)
            Button{showCustomize=true} label:{chip("تخصيص","slider.horizontal.3",false,p)}.buttonStyle(.plain)
        }
    }

    private func layoutPicker(_ p:JalaaPalette)->some View{
        VStack(alignment:.leading,spacing:10){
            HStack{Text("استخراج التخطيط").font(.headline).foregroundStyle(p.text);Spacer();Label("Smart Layout",systemImage:"point.3.connected.trianglepath.dotted").font(.caption).foregroundStyle(p.accent)}
            ScrollView(.horizontal,showsIndicators:false){
                HStack(spacing:8){
                    ForEach(layouts.indices,id:\.self){i in
                        Button{withAnimation(.spring(response:0.32,dampingFraction:0.82)){layout=i}} label:{
                            Text(layouts[i]).font(.caption.bold()).padding(.horizontal,14).padding(.vertical,9)
                                .background(layout == i ? p.accent : p.text.opacity(0.055),in:Capsule())
                                .foregroundStyle(layout == i ? p.background : p.text)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private func board(_ p:JalaaPalette)->some View{
        switch layout {
        case 1: mindMap(p)
        case 2: cardsGrid(p)
        case 3: timeline(p)
        case 4: comparison(p)
        case 5: flow(p)
        default: smartBoard(p)
        }
    }

    private func smartBoard(_ p:JalaaPalette)->some View{
        VStack(spacing:14){
            Button{selected=nodes[0]} label:{
                VStack(spacing:7){
                    Text(recall ? "؟" : (boardTitle.isEmpty ? nodes[0].title : boardTitle)).font(.title2.bold()).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
                    Text(recall ? "اختبر ذاكرتك" : "الفكرة المحورية").font(.caption).foregroundStyle(p.muted)
                }.foregroundStyle(p.text).frame(maxWidth:.infinity).padding(.vertical,28)
                    .background(p.accent.opacity(0.12),in:RoundedRectangle(cornerRadius:28,style:.continuous))
                    .overlay(RoundedRectangle(cornerRadius:28).stroke(p.accent.opacity(0.36)))
            }.buttonStyle(.plain)
            LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],spacing:12){
                ForEach(nodes.dropFirst()){node in knowledgeCard(node,p,minHeight:154)}
            }
        }.padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:30).stroke(p.text.opacity(0.09)))
    }

    private func mindMap(_ p:JalaaPalette)->some View{
        VStack(spacing:14){
            Circle().fill(p.accent.opacity(0.13)).frame(width:170,height:170).overlay(
                VStack(spacing:7){Image(systemName:"circle.hexagongrid.fill").foregroundStyle(p.accent);Text(recall ? "؟" : (boardTitle.isEmpty ? "الموضوع" : boardTitle)).font(.headline).multilineTextAlignment(.center).lineLimit(3);Text("الفكرة المركزية").font(.caption).foregroundStyle(p.muted)}.foregroundStyle(p.text).padding(18)
            )
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12){ForEach(nodes){node in knowledgeCard(node,p,minHeight:142)}}
        }.frame(maxWidth:.infinity).padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func cardsGrid(_ p:JalaaPalette)->some View{
        LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],spacing:12){ForEach(nodes){node in knowledgeCard(node,p,minHeight:176)}}
            .padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func timeline(_ p:JalaaPalette)->some View{
        VStack(spacing:0){
            ForEach(Array(nodes.enumerated()),id:\.element.id){index,node in
                Button{selected=node} label:{
                    HStack(alignment:.top,spacing:14){
                        VStack(spacing:0){Circle().fill(p.accent).frame(width:12,height:12);if index < nodes.count-1 {Rectangle().fill(p.accent.opacity(0.28)).frame(width:2,height:92)}}
                        VStack(alignment:.leading,spacing:6){
                            Text(String(format:"%02d",index+1)).font(.caption.bold()).foregroundStyle(p.accent)
                            Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
                            Text(recall ? "اضغط للكشف" : node.detail).font(.subheadline).foregroundStyle(p.muted).multilineTextAlignment(.leading).lineLimit(3).fixedSize(horizontal:false,vertical:true)
                        }
                        Spacer()
                    }.padding(.vertical,8)
                }.buttonStyle(.plain)
            }
        }.padding(18).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func comparison(_ p:JalaaPalette)->some View{
        let first = nodes[0]
        let second = nodes.count > 1 ? nodes[1] : nodes[0]
        return VStack(spacing:12){
            Text("مقارنة بين نقطتين من المحتوى").font(.title3.bold()).foregroundStyle(p.text).frame(maxWidth:.infinity,alignment:.leading)
            HStack(alignment:.top,spacing:12){compareColumn(first,icon:"1.circle.fill",p:p);compareColumn(second,icon:"2.circle.fill",p:p)}
            if nodes.count > 2 { knowledgeCard(nodes[2],p,minHeight:128) }
        }.padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func flow(_ p:JalaaPalette)->some View{
        VStack(spacing:8){
            ForEach(Array(nodes.enumerated()),id:\.element.id){index,node in
                knowledgeCard(node,p,minHeight:112)
                if index < nodes.count-1 {Image(systemName:"arrow.down").foregroundStyle(p.accent).font(.headline)}
            }
        }.padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30))
    }

    private func knowledgeCard(_ node:BoardNodeData,_ p:JalaaPalette,minHeight:CGFloat)->some View{
        Button{selected=node} label:{
            VStack(alignment:.leading,spacing:10){
                Image(systemName:"point.3.filled.connected.trianglepath.dotted").foregroundStyle(p.accent)
                Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
                if !recall {Text(node.detail).font(.caption).foregroundStyle(p.muted).multilineTextAlignment(.leading).lineLimit(5).fixedSize(horizontal:false,vertical:true)}
                Spacer(minLength:0)
            }.frame(maxWidth:.infinity,minHeight:minHeight,alignment:.topLeading).padding(16)
                .background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:22,style:.continuous))
                .overlay(RoundedRectangle(cornerRadius:22).stroke(p.text.opacity(0.07)))
        }.buttonStyle(.plain)
    }

    private func compareColumn(_ node:BoardNodeData,icon:String,p:JalaaPalette)->some View{
        Button{selected=node} label:{
            VStack(alignment:.leading,spacing:10){
                Image(systemName:icon).foregroundStyle(p.accent)
                Text(recall ? "؟" : node.title).font(.headline).foregroundStyle(p.text).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
                Text(recall ? "اضغط للكشف" : node.detail).font(.caption).foregroundStyle(p.muted).multilineTextAlignment(.leading).lineLimit(6).fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:0)
            }.frame(maxWidth:.infinity,minHeight:215,alignment:.topLeading).padding(16).background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:22))
        }.buttonStyle(.plain)
    }

    private func chip(_ title:String,_ icon:String,_ active:Bool,_ p:JalaaPalette)->some View{
        HStack(spacing:7){Image(systemName:icon);Text(title).font(.caption.bold()).lineLimit(1)}.padding(.horizontal,11).padding(.vertical,9)
            .background(active ? p.accent : p.text.opacity(0.055),in:Capsule()).foregroundStyle(active ? p.background:p.text)
    }

    private func insight(_ p:JalaaPalette)->some View{
        VStack(alignment:.leading,spacing:8){
            Text("من محتواك").font(.headline).foregroundStyle(p.text)
            Text(nodes.first?.detail ?? "").foregroundStyle(p.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
        }.padding(18).background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:22))
    }

    private func emptyState(_ p:JalaaPalette)->some View{
        VStack(spacing:16){
            Image(systemName:"square.stack.3d.up.slash").font(.system(size:38)).foregroundStyle(p.accent)
            Text("لا توجد لوحة بعد").font(.title2.bold()).foregroundStyle(p.text)
            Text("ارجع للرئيسية وارفع PDF أو TXT أو الصق نصًا. لن نعرض محتوى تجريبيًا هنا.").multilineTextAlignment(.center).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity).padding(.vertical,70).padding(.horizontal,24)
    }
}

struct NodeSheet: View {
    let node:BoardNodeData
    let source:String
    let theme:Int
    @State private var action:String? = nil
    @State private var question = ""
    @State private var answer = ""

    var body:some View{
        let p=JalaaPalette.value(theme)
        ZStack{
            p.background.ignoresSafeArea()
            ScrollView{
                VStack(alignment:.leading,spacing:20){
                    Capsule().fill(p.text.opacity(0.25)).frame(width:44,height:5).frame(maxWidth:.infinity)
                    Text(node.title).font(.system(size:34,weight:.black)).foregroundStyle(p.text).fixedSize(horizontal:false,vertical:true)
                    Text(node.detail).font(.title3).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                    Divider().overlay(p.text.opacity(0.1))

                    actionButton("اشرح","play.circle.fill",p){action=BoardEngine.explain(node)}
                    actionButton("تعمّق","book.closed.fill",p){action=BoardEngine.deepen(node,source:source)}
                    actionButton("مثال","square.on.square",p){action=BoardEngine.example(node)}

                    VStack(alignment:.leading,spacing:10){
                        Text("اسأل جلاء عن هذه النقطة").font(.headline).foregroundStyle(p.text)
                        TextField("اكتب سؤالك…",text:$question,axis:.vertical)
                            .textFieldStyle(.plain).foregroundStyle(p.text).padding(14)
                            .background(p.text.opacity(0.055),in:RoundedRectangle(cornerRadius:16))
                        Button{
                            let q=question.trimmingCharacters(in:.whitespacesAndNewlines)
                            guard !q.isEmpty else{return}
                            answer=BoardEngine.answer(question:q,node:node,source:source)
                            action="إجابة من نفس المحتوى:\n\(answer)"
                        } label:{
                            Label("اسأل جلاء",systemImage:"sparkles").font(.headline).foregroundStyle(p.background).frame(maxWidth:.infinity).padding(.vertical,12).background(p.accent,in:RoundedRectangle(cornerRadius:16))
                        }
                    }.padding(.top,4)

                    if let action {
                        Text(action).foregroundStyle(p.text).lineSpacing(5).fixedSize(horizontal:false,vertical:true)
                            .padding(18).background(p.accent.opacity(0.10),in:RoundedRectangle(cornerRadius:20))
                            .transition(.opacity.combined(with:.move(edge:.bottom)))
                    }
                }.padding(24).padding(.bottom,30)
            }
        }
    }

    private func actionButton(_ title:String,_ icon:String,_ p:JalaaPalette,action:@escaping()->Void)->some View{
        Button(action:action){
            HStack{Image(systemName:icon).frame(width:30).foregroundStyle(p.accent);Text(title).font(.headline).foregroundStyle(p.text);Spacer();Image(systemName:"chevron.left").foregroundStyle(p.muted)}.padding(.vertical,10).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct QuizSheet: View {
    let nodes:[BoardNodeData]
    let theme:Int
    @State private var selected:Int? = nil

    var body:some View{
        let p=JalaaPalette.value(theme)
        let options=Array(nodes.prefix(min(4,nodes.count)))
        ZStack{
            p.background.ignoresSafeArea()
            VStack(alignment:.leading,spacing:20){
                Capsule().fill(p.text.opacity(0.22)).frame(width:44,height:5).frame(maxWidth:.infinity)
                Text("اختبار سريع").font(.largeTitle.bold()).foregroundStyle(p.text)
                if let first=nodes.first {
                    Text("أي عنوان يطابق هذه الفكرة؟").font(.headline).foregroundStyle(p.text)
                    Text(first.detail).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                    ForEach(Array(options.enumerated()),id:\.offset){index,item in
                        Button{selected=index} label:{
                            HStack{Text(item.title).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true);Spacer();if selected==index{Image(systemName:index==0 ? "checkmark.circle.fill":"xmark.circle.fill")}}
                                .foregroundStyle(selected==index ? (index==0 ? p.accent : Color.red) : p.text)
                                .padding(15).background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:16))
                        }.buttonStyle(.plain)
                    }
                    if let selected {Text(selected==0 ? "صحيح ✓" : "ليست هذه. جرّب ربط العبارة بعنوانها الأساسي.").font(.headline).foregroundStyle(selected==0 ? p.accent : .red)}
                }
                Spacer()
            }.padding(24)
        }.presentationDetents([.large])
    }
}

struct CustomizeSheet: View {
    @Binding var layout:Int
    let theme:Int
    let layouts:[String]

    var body:some View{
        let p=JalaaPalette.value(theme)
        ZStack{
            p.background.ignoresSafeArea()
            VStack(alignment:.leading,spacing:18){
                Capsule().fill(p.text.opacity(0.22)).frame(width:44,height:5).frame(maxWidth:.infinity)
                Text("تخصيص اللوحة").font(.title2.bold()).foregroundStyle(p.text)
                Text("اختر طريقة عرض المحتوى فورًا.").foregroundStyle(p.muted)
                ForEach(layouts.indices,id:\.self){i in
                    Button{layout=i} label:{
                        HStack{Image(systemName:layout==i ? "checkmark.circle.fill":"circle").foregroundStyle(layout==i ? p.accent:p.muted);Text(layouts[i]).font(.headline).foregroundStyle(p.text);Spacer()}.padding(.vertical,10)
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(24)
        }.presentationDetents([.medium,.large])
    }
}
