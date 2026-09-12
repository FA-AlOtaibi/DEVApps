import SwiftUI

struct SettingsView: View {
    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaWatermarkEnabled") private var watermarkEnabled = true
    @AppStorage("jalaaMotionEnabled") private var motionEnabled = true
    @AppStorage("jalaaExportFormat") private var exportFormat = "PNG عالي الدقة"
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""
    @AppStorage("jalaaBoardNodesJSON") private var boardNodesJSON = ""
    @AppStorage("jalaaAIModel") private var aiModel = "gpt-5.6-luna"

    @State private var apiKey = ""
    @State private var aiMessage = ""
    @State private var testingAI = false
    @State private var showAdvanced = false
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

                ScrollView(.horizontal,showsIndicators:false){
                    HStack(spacing:10){
                        ForEach(themes.indices,id:\.self){i in
                            let palette=JalaaPalette.value(i)
                            Button{withAnimation(.spring(response:0.32,dampingFraction:0.84)){theme=i}} label:{
                                VStack(alignment:.leading,spacing:9){
                                    ZStack(alignment:.bottomTrailing){
                                        RoundedRectangle(cornerRadius:18).fill(palette.background).frame(width:128,height:78)
                                        Circle().fill(palette.accent).frame(width:34,height:34).offset(x:-10,y:-10)
                                    }
                                    Text(themes[i].0).font(.subheadline.bold()).foregroundStyle(p.text)
                                }.padding(10).background(p.text.opacity(0.035),in:RoundedRectangle(cornerRadius:20))
                                    .overlay(RoundedRectangle(cornerRadius:20).stroke(theme==i ? p.accent:p.text.opacity(0.06),lineWidth:theme==i ? 2:1))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                aiSection(p)

                DisclosureGroup(isExpanded:$showAdvanced){
                    VStack(spacing:0){
                        Menu {
                            Button("PNG عالي الدقة"){exportFormat="PNG عالي الدقة"}
                            Button("PDF"){exportFormat="PDF"}
                            Button("JPEG"){exportFormat="JPEG"}
                        } label:{settingsRow("تصدير افتراضي",exportFormat,"square.and.arrow.up",p)}
                        Toggle(isOn:$watermarkEnabled){Label("العلامة المائية",systemImage:"signature").foregroundStyle(p.text)}.tint(p.accent).padding(.vertical,12)
                        Toggle(isOn:$motionEnabled){Label("الحركة الناعمة",systemImage:"waveform.path").foregroundStyle(p.text)}.tint(p.accent).padding(.vertical,12)
                    }
                } label:{Text("خيارات إضافية").font(.headline).foregroundStyle(p.text)}
                .tint(p.accent)

                if !boardSource.isEmpty {
                    Button(role:.destructive){confirmDelete=true} label:{
                        Label("حذف اللوحة الحالية",systemImage:"trash").frame(maxWidth:.infinity).padding(.vertical,13)
                            .background(Color.red.opacity(0.10),in:RoundedRectangle(cornerRadius:16))
                    }
                }
            }.padding(20).padding(.bottom,120)
        }
        .onAppear{apiKey=JalaaKeychain.load()}
        .alert("حذف اللوحة؟",isPresented:$confirmDelete){
            Button("حذف",role:.destructive){boardSource="";boardTitle="";boardNodesJSON=""}
            Button("إلغاء",role:.cancel){}
        } message:{Text("سيتم حذف المحتوى المحلي الحالي.")}
    }

    private func aiSection(_ p:JalaaPalette)->some View{
        VStack(alignment:.leading,spacing:13){
            HStack{Image(systemName:"sparkles").foregroundStyle(p.accent);Text("ذكاء جلاء").font(.headline).foregroundStyle(p.text);Spacer();Text(JalaaKeychain.load().isEmpty ? "غير مربوط":"مربوط").font(.caption.bold()).foregroundStyle(JalaaKeychain.load().isEmpty ? p.muted:p.accent)}
            SecureField("OpenAI API Key",text:$apiKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled().foregroundStyle(p.text)
                .padding(13).background(p.text.opacity(0.05),in:RoundedRectangle(cornerRadius:15))
            HStack(spacing:9){
                Button{
                    let clean=apiKey.trimmingCharacters(in:.whitespacesAndNewlines)
                    if clean.isEmpty{JalaaKeychain.clear();aiMessage="تم فصل المفتاح"}else{JalaaKeychain.save(clean);aiMessage="تم حفظ المفتاح بأمان على هذا الجهاز"}
                } label:{Text("حفظ").font(.subheadline.bold()).foregroundStyle(p.background).padding(.horizontal,17).padding(.vertical,10).background(p.accent,in:Capsule())}
                Button{testAI()} label:{HStack(spacing:6){if testingAI{ProgressView().tint(p.text)};Text("اختبار الاتصال").font(.subheadline.bold())}.foregroundStyle(p.text).padding(.horizontal,15).padding(.vertical,10).background(p.text.opacity(0.055),in:Capsule())}.disabled(testingAI)
                Spacer()
            }
            Menu{
                Button("GPT-5.6 Luna — أوفر"){aiModel="gpt-5.6-luna"}
                Button("GPT-5.6 Terra — أقوى"){aiModel="gpt-5.6-terra"}
                Button("GPT-5.6 Sol — الأعلى"){aiModel="gpt-5.6-sol"}
            } label:{settingsRow("النموذج",modelName,"cpu",p)}
            if !aiMessage.isEmpty{Text(aiMessage).font(.caption).foregroundStyle(aiMessage.contains("نجح") || aiMessage.contains("حفظ") ? p.accent:p.muted).fixedSize(horizontal:false,vertical:true)}
            Text("المفتاح يُحفظ في Keychain على جهازك ولا يُكتب داخل التطبيق أو المستودع.").font(.caption2).foregroundStyle(p.muted)
        }.padding(16).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(p.text.opacity(0.07)))
    }

    private var modelName:String{
        switch aiModel{case "gpt-5.6-sol":return "GPT-5.6 Sol";case "gpt-5.6-terra":return "GPT-5.6 Terra";default:return "GPT-5.6 Luna"}
    }

    private func testAI(){
        let clean=apiKey.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !clean.isEmpty else{aiMessage="أدخل المفتاح أولاً";return}
        JalaaKeychain.save(clean);testingAI=true;aiMessage=""
        Task{
            do{_ = try await JalaaAIService.test(model:aiModel);await MainActor.run{aiMessage="نجح الاتصال — جلاء AI جاهز";testingAI=false}}
            catch{await MainActor.run{aiMessage=error.localizedDescription;testingAI=false}}
        }
    }

    private func settingsRow(_ title:String,_ value:String,_ icon:String,_ p:JalaaPalette)->some View{
        HStack(spacing:12){Image(systemName:icon).frame(width:24).foregroundStyle(p.accent);Text(title).foregroundStyle(p.text);Spacer();Text(value).foregroundStyle(p.muted);Image(systemName:"chevron.left").foregroundStyle(p.muted)}.padding(.vertical,12).contentShape(Rectangle())
    }
}
