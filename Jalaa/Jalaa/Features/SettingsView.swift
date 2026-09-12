import SwiftUI

struct SettingsView: View {
    @AppStorage("jalaaTheme") private var theme = 0

    private let themes:[(String,String)] = [
        ("Graphite","رصين ومحايد"),
        ("Ivory","ورقي ودافئ"),
        ("Midnight","أزرق عميق"),
        ("Sage","هادئ طبيعي"),
        ("Ember","داكن دافئ"),
        ("Paper","فاتح كلاسيكي"),
        ("Violet","تقني أنيق"),
        ("Teal","حديث وبارد")
    ]

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators:false){
            VStack(alignment:.leading,spacing:22){
                Text("المظهر").font(.largeTitle.bold()).foregroundStyle(p.text)
                Text("اختر هوية الواجهة كاملة، وليس لونًا واحدًا فقط.").foregroundStyle(p.muted)
                LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],spacing:12){
                    ForEach(themes.indices,id:\.self){i in
                        let palette = JalaaPalette.value(i)
                        Button{withAnimation(.spring(response:0.35,dampingFraction:0.82)){theme=i}} label:{
                            VStack(alignment:.leading,spacing:13){
                                ZStack(alignment:.bottomTrailing){
                                    RoundedRectangle(cornerRadius:20,style:.continuous).fill(palette.background).frame(height:100)
                                    Circle().fill(palette.accent).frame(width:48,height:48).offset(x:-12,y:-12)
                                    RoundedRectangle(cornerRadius:12).fill(palette.secondary).frame(width:70,height:34).offset(x:-62,y:-16)
                                }
                                Text(themes[i].0).font(.headline).foregroundStyle(p.text)
                                Text(themes[i].1).font(.caption).foregroundStyle(p.muted)
                            }.padding(12)
                                .background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:24,style:.continuous))
                                .overlay(RoundedRectangle(cornerRadius:24).stroke(theme==i ? p.accent : p.text.opacity(0.07),lineWidth:theme==i ? 2:1))
                        }.buttonStyle(.plain)
                    }
                }
                Divider().overlay(p.text.opacity(0.1))
                VStack(spacing:0){
                    setting("لغة الواجهة","العربية",p)
                    setting("تصدير افتراضي","PNG عالي الدقة",p)
                    setting("العلامة المائية","جلاء",p)
                    setting("الحركة","ناعمة",p)
                }
            }.padding(20).padding(.bottom,120)
        }
    }

    private func setting(_ a:String,_ b:String,_ p:JalaaPalette)->some View{
        HStack{Text(a).foregroundStyle(p.text);Spacer();Text(b).foregroundStyle(p.muted);Image(systemName:"chevron.left").foregroundStyle(p.muted)}.padding(.vertical,13)
    }
}
