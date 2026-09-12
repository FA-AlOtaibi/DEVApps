import SwiftUI

struct SettingsView: View {
    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaWatermarkEnabled") private var watermarkEnabled = true
    @AppStorage("jalaaMotionEnabled") private var motionEnabled = true
    @AppStorage("jalaaExportFormat") private var exportFormat = "PNG عالي الدقة"
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""

    @State private var showLanguage = false
    @State private var showWatermark = false
    @State private var showMotion = false
    @State private var confirmDelete = false

    private let themes:[(String,String)] = [
        ("Graphite","رصين ومحايد"),("Ivory","ورقي ودافئ"),("Midnight","أزرق عميق"),("Sage","هادئ طبيعي"),
        ("Ember","داكن دافئ"),("Paper","فاتح كلاسيكي"),("Violet","تقني أنيق"),("Teal","حديث وبارد")
    ]

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators:false){
            VStack(alignment:.leading,spacing:22){
                Text("المظهر").font(.largeTitle.bold()).foregroundStyle(p.text)
                Text("كل تغيير هنا يُحفظ ويُطبق على التطبيق.").foregroundStyle(p.muted)

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
                    settingsButton("لغة الواجهة","العربية","globe",p){showLanguage=true}

                    Menu {
                        Button("PNG عالي الدقة"){exportFormat="PNG عالي الدقة"}
                        Button("PDF"){exportFormat="PDF"}
                        Button("JPEG"){exportFormat="JPEG"}
                    } label: {
                        settingsRow("تصدير افتراضي",exportFormat,"square.and.arrow.up",p)
                    }

                    settingsButton("العلامة المائية",watermarkEnabled ? "مفعّلة" : "متوقفة","signature",p){showWatermark=true}
                    settingsButton("الحركة",motionEnabled ? "ناعمة" : "متوقفة","waveform.path",p){showMotion=true}
                }

                if !boardSource.isEmpty {
                    Button(role:.destructive){confirmDelete=true} label:{
                        Label("حذف لوحتي المحفوظة",systemImage:"trash").frame(maxWidth:.infinity).padding(.vertical,13)
                            .background(Color.red.opacity(0.10),in:RoundedRectangle(cornerRadius:16))
                    }
                }
            }.padding(20).padding(.bottom,120)
        }
        .sheet(isPresented:$showLanguage){ optionSheet(title:"لغة الواجهة",p:p){
            HStack{Image(systemName:"checkmark.circle.fill").foregroundStyle(p.accent);VStack(alignment:.leading){Text("العربية").font(.headline);Text("اللغة الحالية").font(.caption).foregroundStyle(p.muted)};Spacer()}.foregroundStyle(p.text)
            Divider().overlay(p.text.opacity(0.1))
            HStack{Image(systemName:"circle").foregroundStyle(p.muted);VStack(alignment:.leading){Text("English").font(.headline);Text("ستتوفر عند إضافة ترجمة كاملة — لن أفعّل خيارًا شكليًا فقط.").font(.caption).foregroundStyle(p.muted)};Spacer()}.foregroundStyle(p.muted)
        }}
        .sheet(isPresented:$showWatermark){ optionSheet(title:"العلامة المائية",p:p){
            Toggle("إضافة توقيع جلاء عند التصدير",isOn:$watermarkEnabled).tint(p.accent).foregroundStyle(p.text)
            Text("يُحفظ الاختيار على الجهاز ويُستخدم عند إضافة التصدير النهائي.").font(.caption).foregroundStyle(p.muted)
        }}
        .sheet(isPresented:$showMotion){ optionSheet(title:"الحركة",p:p){
            Toggle("تفعيل الحركات الناعمة",isOn:$motionEnabled).tint(p.accent).foregroundStyle(p.text)
            Text("إيقافها يوقف الحركات الزخرفية المتكررة ويجعل الواجهة أكثر ثباتًا.").font(.caption).foregroundStyle(p.muted)
        }}
        .alert("حذف اللوحة؟",isPresented:$confirmDelete){
            Button("حذف",role:.destructive){boardSource="";boardTitle=""}
            Button("إلغاء",role:.cancel){}
        } message:{Text("سيتم حذف المحتوى المحلي الحالي من الرئيسية والمكتبة.")}
    }

    private func settingsButton(_ title:String,_ value:String,_ icon:String,_ p:JalaaPalette,action:@escaping()->Void)->some View{
        Button(action:action){settingsRow(title,value,icon,p)}.buttonStyle(.plain)
    }

    private func settingsRow(_ title:String,_ value:String,_ icon:String,_ p:JalaaPalette)->some View{
        HStack(spacing:12){
            Image(systemName:icon).frame(width:26).foregroundStyle(p.accent)
            Text(title).foregroundStyle(p.text)
            Spacer()
            Text(value).foregroundStyle(p.muted)
            Image(systemName:"chevron.left").foregroundStyle(p.muted)
        }.padding(.vertical,14).contentShape(Rectangle())
    }

    private func optionSheet<Content:View>(title:String,p:JalaaPalette,@ViewBuilder content:()->Content)->some View{
        ZStack{
            p.background.ignoresSafeArea()
            VStack(alignment:.leading,spacing:20){
                Capsule().fill(p.text.opacity(0.22)).frame(width:44,height:5).frame(maxWidth:.infinity)
                Text(title).font(.title2.bold()).foregroundStyle(p.text)
                content()
                Spacer()
            }.padding(24)
        }.presentationDetents([.medium])
    }
}
