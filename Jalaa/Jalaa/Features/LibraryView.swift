import SwiftUI

struct LibraryView: View {
    @AppStorage("jalaaTheme") private var theme = 0
    @AppStorage("jalaaBoardSource") private var boardSource = ""
    @AppStorage("jalaaBoardTitle") private var boardTitle = ""

    var body: some View {
        let p = JalaaPalette.value(theme)
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:18) {
                Text("المكتبة").font(.largeTitle.bold()).foregroundStyle(p.text)
                Text("لن يظهر هنا إلا المحتوى الذي أنشأته أنت.").foregroundStyle(p.muted)

                if boardSource.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                    VStack(spacing:14) {
                        Image(systemName:"books.vertical.fill").font(.system(size:34)).foregroundStyle(p.accent)
                        Text("مكتبتك فارغة").font(.title3.bold()).foregroundStyle(p.text)
                        Text("أنشئ أول لوحة من الرئيسية وستُحفظ هنا تلقائيًا على الجهاز.")
                            .multilineTextAlignment(.center).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                    }
                    .frame(maxWidth:.infinity).padding(.vertical,42).padding(.horizontal,20)
                    .background(p.text.opacity(0.04),in:RoundedRectangle(cornerRadius:28,style:.continuous))
                    .overlay(RoundedRectangle(cornerRadius:28).stroke(p.text.opacity(0.07)))
                } else {
                    HStack(spacing:14) {
                        RoundedRectangle(cornerRadius:16).fill(p.accent.opacity(0.13)).frame(width:58,height:58)
                            .overlay(Image(systemName:"square.grid.2x2.fill").foregroundStyle(p.accent))
                        VStack(alignment:.leading,spacing:4) {
                            Text(boardTitle.isEmpty ? "لوحتي" : boardTitle).font(.headline).foregroundStyle(p.text).lineLimit(2)
                            Text("محفوظة على الجهاز • \(BoardEngine.nodes(from:boardSource).count) نقاط").font(.caption).foregroundStyle(p.muted)
                        }
                        Spacer()
                    }
                    .padding(14).background(p.text.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
                }
            }.padding(20).padding(.bottom,120)
        }
    }
}
