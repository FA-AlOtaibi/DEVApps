from pathlib import Path
import sys

root = Path(sys.argv[1])

# Force entitlement-free external WLOC mode.
p = root / 'App/AppStore.swift'
s = p.read_text()
needle = '        runtimeMode = Persistence.shared.load(RuntimeMode.self, key: Key.mode)\n        setupCompleted = UserDefaults.standard.bool(forKey: Key.setup)\n'
repl = '        runtimeMode = Persistence.shared.load(RuntimeMode.self, key: Key.mode)\n        if runtimeMode != .thirdParty {\n            runtimeMode = .thirdParty\n            Persistence.shared.save(RuntimeMode.thirdParty, key: Key.mode)\n            UserDefaults.standard.set(false, forKey: Key.setup)\n        }\n        setupCompleted = UserDefaults.standard.bool(forKey: Key.setup)\n'
if needle not in s:
    raise SystemExit('AppStore init pattern missing')
s = s.replace(needle, repl)
start = '''        if runtimeMode == .appWiFi {
            do {
                try EmbeddedCoreManager.shared.start()
                if UserDefaults.standard.bool(forKey: Key.active), let saved = selection?.wgs84 {
                    EmbeddedCoreManager.shared.set(point: saved, accuracy: accuracy, motion: motionSimulation)
                    isVirtualLocationActive = true
                }
                let s = EmbeddedCoreManager.shared.status()
                if let active = s.activePoint { selection = .init(wgs84: active); isVirtualLocationActive = true }
            } catch { logs.add(.error, "Core", error.localizedDescription) }
        }
'''
s = s.replace(start, '')
p.write_text(s)

p = root / 'Models/RuntimeModels.swift'
s = p.read_text()
s = s.replace('case thirdParty = "بروكسي خارجي"', 'case thirdParty = "Shadowrocket WLOC"')
s = s.replace('case .thirdParty: return "Shadowrocket / Surge / Quantumult X / Loon / Stash / Egern"', 'case .thirdParty: return "اختيار الموقع من GeoShift والتنفيذ عبر Shadowrocket"')
p.write_text(s)

(root / 'Features/Setup/SetupFlowView.swift').write_text(r'''import SwiftUI
import UIKit

struct SetupFlowView: View {
    @EnvironmentObject private var store: AppStore
    @State private var checking = false
    private let moduleURL = "https://raw.githubusercontent.com/Yu9191/wloc/refs/heads/main/modules/wloc.module"

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "location.viewfinder").font(.system(size: 46)).foregroundColor(.blue)
                        Text("GeoShift + Shadowrocket").font(.title2.bold())
                        Text("اختَر الموقع من GeoShift، وShadowrocket يعترض Apple WLOC ويحفظ الإحداثيات المختارة.")
                            .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                Section("1 · إضافة وحدة WLOC") {
                    Button { UIPasteboard.general.string = moduleURL; store.toast = "تم نسخ رابط وحدة WLOC" } label: { Label("نسخ رابط الوحدة", systemImage: "doc.on.doc") }
                    Button { if let u = URL(string: moduleURL) { UIApplication.shared.open(u) } } label: { Label("فتح رابط الوحدة", systemImage: "safari") }
                    Text("في Shadowrocket: التكوين/الوحدات → + → إضافة من URL، ثم الصق الرابط وفَعّل الوحدة.").font(.caption).foregroundColor(.secondary)
                }
                Section("2 · HTTPS / MITM") {
                    Text("داخل Shadowrocket فعّل HTTPS Decryption/MITM للوحدة وثبّت شهادة Shadowrocket ثم فعّل الثقة الكاملة لها من إعدادات iOS. يجب أن تشمل gs-loc.apple.com و gs-loc-cn.apple.com.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("3 · تشغيل Shadowrocket") {
                    Button { if let u = URL(string: "shadowrocket://") { UIApplication.shared.open(u) } } label: { Label("فتح Shadowrocket", systemImage: "paperplane.fill") }
                    Text("شغّل زر الاتصال في Shadowrocket وتأكد أن علامة VPN ظاهرة. لا تضبط HTTP Proxy يدويًا في Wi‑Fi.").font(.caption).foregroundColor(.secondary)
                }
                Section("4 · فحص الربط") {
                    Button(checking ? "جارٍ الفحص…" : "فحص وحدة WLOC") { Task { checking = true; await store.checkProvider(); checking = false } }.disabled(checking)
                    StatusRow(status: store.providerStatus)
                    Text("إذا ظهر جاهز، GeoShift يقدر يحفظ الإحداثيات داخل Shadowrocket مباشرة.").font(.caption).foregroundColor(.secondary)
                }
                Section {
                    Button("إنهاء الإعداد والذهاب للخريطة") { store.finishSetup() }.frame(maxWidth: .infinity).disabled(store.providerStatus.health == .unavailable || store.providerStatus.health == .checking)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("الإعداد")
            .environment(\.layoutDirection, .rightToLeft)
        }.navigationViewStyle(.stack)
        .onAppear {
            if store.runtimeMode != .thirdParty { store.selectMode(.thirdParty) }
            if store.thirdPartyClient != .shadowrocket { store.setClient(.shadowrocket) }
        }
    }
}

struct StatusRow: View {
    let status: ProviderStatus
    var body: some View { HStack(alignment: .top, spacing: 10) { Image(systemName: icon).foregroundColor(color); VStack(alignment: .leading, spacing: 3) { Text(label).font(.subheadline.bold()); Text(status.detail).font(.caption).foregroundColor(.secondary) } } }
    private var icon: String { switch status.health { case .ready: return "checkmark.circle.fill"; case .inactive: return "checkmark.circle.fill"; case .unavailable: return "xmark.octagon.fill"; case .checking: return "clock.fill" } }
    private var color: Color { switch status.health { case .ready: return .green; case .inactive: return .green; case .unavailable: return .red; case .checking: return .blue } }
    private var label: String { switch status.health { case .ready: return "جاهز · الموقع مفعّل"; case .inactive: return "جاهز · الموقع متوقف"; case .unavailable: return "غير جاهز"; case .checking: return "جارٍ الفحص" } }
}

struct ValueRow: View {
    let title: String; let value: String
    init(_ title: String, _ value: String) { self.title = title; self.value = value }
    var body: some View { HStack { Text(title); Spacer(); Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing) } }
}
''')

p = root / 'project.yml'
s = p.read_text().replace('MARKETING_VERSION: 3.0.0', 'MARKETING_VERSION: 6.0.0').replace('CURRENT_PROJECT_VERSION: 30', 'CURRENT_PROJECT_VERSION: 60')
p.write_text(s)
print('GeoShift v6 Shadowrocket WLOC patch applied')
