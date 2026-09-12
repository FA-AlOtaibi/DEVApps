import SwiftUI
import UniformTypeIdentifiers
import PDFKit

@main struct JalaaApp: App {
    @StateObject var store = Store()
    var body: some Scene { WindowGroup { Root().environmentObject(store).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(store.theme.scheme) } }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case graphite="جرافيت", ivory="عاجي", midnight="منتصف الليل", stone="حجري"
    var id:String{rawValue}
    var scheme:ColorScheme? { self == .ivory ? .light : .dark }
    var bg:Color { switch self { case .ivory:return Color(red:0.95,green:0.94,blue:0.91); case .midnight:return Color(red:0.025,green:0.033,blue:0.055); case .stone:return Color(red:0.10,green:0.10,blue:0.10); default:return Color(red:0.045,green:0.047,blue:0.052) } }
    var accent:Color { switch self { case .ivory:return Color(red:0.12,green:0.25,blue:0.23); case .midnight:return Color(red:0.34,green:0.60,blue:0.88); case .stone:return Color(red:0.72,green:0.70,blue:0.64); default:return Color(red:0.56,green:0.72,blue:0.66) } }
    var ink:Color { self == .ivory ? .black.opacity(0.9) : .white.opacity(0.94) }
}

struct Node:Identifiable,Hashable { let id=UUID(); let title:String; let detail:String; let icon:String }
struct Board:Identifiable { let id=UUID(); let title:String; let nodes:[Node] }

@MainActor final class Store: ObservableObject {
    @Published var theme:AppTheme = .graphite
    @Published var current:Board?
    @Published var boards:[Board]=[]
    @Published var busy=false
    func analyze(_ source:String) async {
        let t=source.replacingOccurrences(of:"\n",with:" ").trimmingCharacters(in:.whitespacesAndNewlines)
        guard !t.isEmpty else{return}
        busy=true; try? await Task.sleep(for:.milliseconds(700))
        let raw=t.components(separatedBy:CharacterSet(charactersIn:".،؛!?" )).map{$0.trimmingCharacters(in:.whitespaces)}.filter{$0.count>18}
        let src=raw.isEmpty ? [t] : Array(raw.prefix(6)); let icons=["scope","point.3.connected.trianglepath.dotted","square.stack.3d.up","waveform.path.ecg","circle.grid.cross","arrow.triangle.branch"]
        let nodes=src.enumerated().map{ i,s in Node(title:s.split(separator:" ").prefix(5).joined(separator:" "),detail:s,icon:icons[i%icons.count]) }
        let title=t.split(separator:" ").prefix(5).joined(separator:" ")
        let b=Board(title:title,nodes:nodes); current=b; boards.insert(b,at:0); busy=false
    }
}

extension View { func glass(_ r:CGFloat=22)->some View { self.background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:r,style:.continuous)).overlay(RoundedRectangle(cornerRadius:r,style:.continuous).stroke(.white.opacity(0.10),lineWidth:0.7)).shadow(color:.black.opacity(0.18),radius:22,y:10) } }

struct Root:View {
    @State var tab=0
    var body:some View { TabView(selection:$tab){ Home().tag(0).tabItem{Label("الرئيسية",systemImage:"rectangle.grid.1x2")}; Library().tag(1).tabItem{Label("مكتبتي",systemImage:"square.stack.3d.up")}; Appearance().tag(2).tabItem{Label("المظهر",systemImage:"circle.lefthalf.filled")} }.tint(.primary) }
}

struct Ambient:View { let color:Color; @State var move=false; var body:some View { GeometryReader{g in ZStack{ Circle().fill(color.opacity(0.09)).frame(width:270).blur(radius:45).offset(x:move ? -110:140,y:move ? 80:-150); Circle().stroke(color.opacity(0.13),lineWidth:1).frame(width:130).offset(x:move ? 120:70,y:move ? -190:-100) }.frame(width:g.size.width,height:g.size.height).animation(.easeInOut(duration:10).repeatForever(autoreverses:true),value:move).onAppear{move=true} }.allowsHitTesting(false) } }

struct Mark:View { var body:some View { Canvas{c,s in var p=Path(); p.move(to:CGPoint(x:s.width*0.76,y:s.height*0.18)); p.addCurve(to:CGPoint(x:s.width*0.22,y:s.height*0.74),control1:CGPoint(x:s.width*0.84,y:s.height*0.55),control2:CGPoint(x:s.width*0.54,y:s.height*0.79)); p.addCurve(to:CGPoint(x:s.width*0.72,y:s.height*0.72),control1:CGPoint(x:s.width*0.16,y:s.height*0.96),control2:CGPoint(x:s.width*0.62,y:s.height*0.91)); c.stroke(p,with:.color(.primary),lineWidth:3.2); c.fill(Path(ellipseIn:CGRect(x:s.width*0.67,y:s.height*0.27,width:5,height:5)),with:.color(.primary)) } } }

struct Home:View {
    @EnvironmentObject var s:Store; @State var text=""; @State var importFile=false; @State var compose=false
    var body:some View { NavigationStack{ ZStack{ s.theme.bg.ignoresSafeArea(); Ambient(color:s.theme.accent); ScrollView(showsIndicators:false){ VStack(alignment:.leading,spacing:26){ HStack{ Mark().frame(width:44,height:44); VStack(alignment:.leading,spacing:0){Text("جلاء").font(.title2.bold());Text("وضوح، لا ضجيج").font(.caption).foregroundStyle(.secondary)};Spacer();Image(systemName:"person.crop.circle").font(.title2) }
                VStack(alignment:.leading,spacing:18){ Text("حوّل المادة\nإلى مشهد تفهمه.").font(.system(size:39,weight:.bold,design:.rounded)).tracking(-1); Text("نقرأ المحتوى، نلتقط العلاقات، ثم نبني لوحة معرفية تستكشفها بدل أن تمر عليها مرورًا.").foregroundStyle(.secondary).lineSpacing(5); HStack(spacing:10){ Chip("PDF / ملف","doc"){importFile=true}; Chip("لصق نص","text.alignright"){compose=true} } }.padding(22).glass(30)
                if let b=s.current { NavigationLink{ BoardView(board:b) } label:{ VStack(alignment:.leading,spacing:12){ HStack{Text("آخر لوحة").font(.caption.bold()).foregroundStyle(s.theme.accent);Spacer();Image(systemName:"arrow.up.left")};Text(b.title).font(.title3.bold()).lineLimit(2); HStack{ForEach(b.nodes.prefix(3)){n in Text(n.title).font(.caption2).lineLimit(1).padding(.horizontal,8).frame(height:27).background(.thinMaterial,in:Capsule())}} }.padding(18).glass() }.buttonStyle(.plain) }
                HStack(spacing:12){ Metric("\(s.boards.count)","لوحة");Metric("0%","إتقان");Metric("—","مراجعة") }
            }.padding(.horizontal,20).padding(.top,12).padding(.bottom,100) } }.foregroundStyle(s.theme.ink).toolbar(.hidden,for:.navigationBar).sheet(isPresented:$compose){Composer(text:$text)}.fileImporter(isPresented:$importFile,allowedContentTypes:[.pdf,.plainText,.text]){r in load(r)} }.overlay(alignment:.bottom){ Button{compose=true}label:{Label(s.busy ? "جاري بناء اللوحة":"إنشاء لوحة",systemImage:s.busy ? "hourglass":"plus").fontWeight(.semibold).padding(.horizontal,22).frame(height:54)}.buttonStyle(.plain).glass(28).padding(.bottom,12)} }
    func load(_ r:Result<URL,Error>){ guard case .success(let u)=r else{return}; let ok=u.startAccessingSecurityScopedResource(); defer{if ok{u.stopAccessingSecurityScopedResource()}}; var x=""; if u.pathExtension.lowercased()=="pdf",let d=PDFDocument(url:u){x=(0..<d.pageCount).compactMap{d.page(at:$0)?.string}.joined(separator:"\n")}else{x=(try?String(contentsOf:u)) ?? ""}; Task{await s.analyze(x)} }
}

struct Chip:View { let t:String,i:String,a:()->Void; init(_ t:String,_ i:String,_ a:@escaping()->Void){self.t=t;self.i=i;self.a=a}; var body:some View{Button(action:a){Label(t,systemImage:i).font(.subheadline.bold()).padding(.horizontal,14).frame(height:42)}.buttonStyle(.plain).background(.thinMaterial,in:Capsule()).overlay(Capsule().stroke(.white.opacity(0.08)))} }
struct Metric:View { let v:String,l:String; init(_ v:String,_ l:String){self.v=v;self.l=l}; var body:some View{VStack(alignment:.leading,spacing:4){Text(v).font(.title2.bold());Text(l).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(14).glass(18)} }

struct Composer:View { @EnvironmentObject var s:Store; @Environment(\.dismiss)var dismiss; @Binding var text:String; var body:some View{NavigationStack{ZStack{s.theme.bg.ignoresSafeArea();VStack(spacing:14){TextEditor(text:$text).scrollContentBackground(.hidden).padding().glass();Button("ابنِ اللوحة"){let v=text;dismiss();Task{await s.analyze(v)}}.buttonStyle(.borderedProminent).disabled(text.count<20)}.padding()}.foregroundStyle(s.theme.ink).navigationTitle("مادة جديدة").navigationBarTitleDisplayMode(.inline)}} }

struct BoardView:View { @EnvironmentObject var s:Store; let board:Board; @State var selected:Node?; @State var recall=false; var body:some View{ZStack{s.theme.bg.ignoresSafeArea();Ambient(color:s.theme.accent);ScrollView{VStack(alignment:.leading,spacing:18){Text(board.title).font(.system(size:34,weight:.bold,design:.rounded));HStack{Toggle("Recall",isOn:$recall).toggleStyle(.button);Spacer();Label("Smart Layout",systemImage:"point.3.connected.trianglepath.dotted").font(.caption).foregroundStyle(s.theme.accent)}; VStack(spacing:14){ZStack{Circle().fill(s.theme.accent.opacity(0.15)).frame(width:145,height:145).overlay(Circle().stroke(s.theme.accent.opacity(0.3)));Text(recall ? "؟":board.title).font(.headline).multilineTextAlignment(.center).padding().lineLimit(3)};LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12){ForEach(board.nodes){n in Button{withAnimation(.snappy){selected=n}}label:{VStack(alignment:.leading,spacing:9){Image(systemName:n.icon).foregroundStyle(s.theme.accent);Text(recall ? "اكشف المفهوم":n.title).font(.subheadline.bold()).lineLimit(3);Spacer()}.frame(maxWidth:.infinity,minHeight:110,alignment:.topLeading).padding(14)}.buttonStyle(.plain).glass(20)}}}.padding(16).background(.black.opacity(0.07),in:RoundedRectangle(cornerRadius:32));if let n=selected{VStack(alignment:.leading,spacing:12){HStack{Image(systemName:n.icon);Text(n.title).font(.headline);Spacer();Button{selected=nil}label:{Image(systemName:"xmark")}};Text(n.detail).font(.callout).foregroundStyle(.secondary).lineSpacing(4);HStack{Pill("اشرح","text.bubble");Pill("تعمّق","arrow.down.right.and.arrow.up.left");Pill("اختبرني","questionmark.circle")}}.padding(18).glass()};Quiz(nodes:board.nodes)}.padding(20).padding(.bottom,70)}}.foregroundStyle(s.theme.ink).navigationBarTitleDisplayMode(.inline)} }
struct Pill:View{let t:String,i:String;init(_ t:String,_ i:String){self.t=t;self.i=i};var body:some View{Label(t,systemImage:i).font(.caption).padding(.horizontal,9).frame(height:33).background(.thinMaterial,in:Capsule())}}
struct Quiz:View{let nodes:[Node];@State var show=false;var body:some View{VStack(alignment:.leading,spacing:10){Text("اختبار سريع").font(.headline);Text(nodes.first.map{"ما الفكرة الأساسية في: \($0.title)؟"} ?? "لا يوجد محتوى");if show,let n=nodes.first{Text(n.detail).font(.caption).foregroundStyle(.secondary)};Button(show ? "إخفاء الإجابة":"كشف الإجابة"){withAnimation{show.toggle()}}.font(.caption.bold())}.padding(18).glass()} }

struct Library:View{@EnvironmentObject var s:Store;var body:some View{NavigationStack{ZStack{s.theme.bg.ignoresSafeArea();ScrollView{LazyVStack(spacing:12){ForEach(s.boards){b in NavigationLink{BoardView(board:b)}label:{VStack(alignment:.leading){Text(b.title).font(.headline);Text("\(b.nodes.count) مفاهيم").font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(18).glass()}.buttonStyle(.plain)}}.padding()}}.foregroundStyle(s.theme.ink).navigationTitle("مكتبتي")}}}
struct Appearance:View{@EnvironmentObject var s:Store;var body:some View{NavigationStack{ZStack{s.theme.bg.ignoresSafeArea();VStack(alignment:.leading,spacing:16){Text("هوية الواجهة").font(.title.bold());Text("بدون gradients صاخبة أو شكل AI نمطي.").foregroundStyle(.secondary);ForEach(AppTheme.allCases){t in Button{withAnimation(.smooth){s.theme=t}}label:{HStack{Circle().fill(t.accent).frame(width:24,height:24);Text(t.rawValue);Spacer();if s.theme==t{Image(systemName:"checkmark")}}.padding(16).glass(20)}.buttonStyle(.plain)};Spacer()}.padding()}.foregroundStyle(s.theme.ink)}}}
