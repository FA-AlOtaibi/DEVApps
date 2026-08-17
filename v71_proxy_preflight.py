from pathlib import Path
import sys

root = Path(sys.argv[1])

# EmbeddedCoreManager: add an explicit loopback preflight before the user changes Wi-Fi proxy.
p = root / 'Services/EmbeddedCoreManager.swift'
s = p.read_text()
needle = '''    var isRunning: Bool { core_running() != 0 }\n\n    func set(point: GeoPoint?, accuracy: Double, motion: Bool) {'''
repl = '''    var isRunning: Bool { core_running() != 0 }\n\n    func localPreflight() async -> ProviderStatus {\n        do {\n            if !isRunning { try start() }\n            guard isRunning else {\n                return .init(health: .unavailable, detail: "النواة لم تبدأ. لا تعدّل بروكسي Wi‑Fi الآن.", activePoint: nil, accuracy: nil)\n            }\n            var request = URLRequest(url: URL(string: "http://127.0.0.1:8888/status?nonce=\\(UUID().uuidString)")!)\n            request.timeoutInterval = 3\n            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData\n            let config = URLSessionConfiguration.ephemeral\n            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData\n            let session = URLSession(configuration: config)\n            let (data, response) = try await session.data(for: request)\n            guard let http = response as? HTTPURLResponse, http.statusCode == 200,\n                  let body = String(data: data, encoding: .utf8), body.contains("GeoShiftCore") else {\n                return .init(health: .unavailable, detail: "النواة تعمل لكن 127.0.0.1:8888 لا يرد. لا تعدّل بروكسي Wi‑Fi.", activePoint: nil, accuracy: nil)\n            }\n            let runtime = status()\n            return .init(health: runtime.activePoint == nil ? .inactive : .ready, detail: "البروكسي المحلي شغّال فعليًا على 127.0.0.1:8888. الآن يمكنك ضبط بروكسي Wi‑Fi.", activePoint: runtime.activePoint, accuracy: runtime.accuracy)\n        } catch {\n            return .init(health: .unavailable, detail: "فشل اختبار 127.0.0.1:8888: \\(error.localizedDescription). لا تعدّل بروكسي Wi‑Fi.", activePoint: nil, accuracy: nil)\n        }\n    }\n\n    func set(point: GeoPoint?, accuracy: Double, motion: Bool) {'''
if needle not in s:
    raise SystemExit('EmbeddedCoreManager anchor missing')
s = s.replace(needle, repl)
s = s.replace('تم تشغيل البروكسي المحلي على المنفذ 8888 باستخدام CA المحفوظة في Keychain', 'تم تشغيل البروكسي المحلي على 127.0.0.1:8888 باستخدام CA المحفوظة في Keychain')
p.write_text(s)

# AppStore: expose a preflight action and make App Mode restart the core if needed.
p = root / 'App/AppStore.swift'
s = p.read_text()
needle = '''    func checkProvider() async {\n        providerStatus = .init(health: .checking, detail: "جارٍ فحص البيئة…", activePoint: nil, accuracy: nil)\n        providerStatus = await provider.check()\n        isVirtualLocationActive = providerStatus.activePoint != nil\n        logs.add(providerStatus.health == .unavailable ? .error : .info, "Environment", providerStatus.detail)\n    }\n'''
repl = '''    func checkLocalCoreBeforeProxy() async {\n        providerStatus = .init(health: .checking, detail: "جارٍ اختبار البروكسي المحلي قبل تعديل Wi‑Fi…", activePoint: nil, accuracy: nil)\n        providerStatus = await EmbeddedCoreManager.shared.localPreflight()\n        logs.add(providerStatus.health == .unavailable ? .error : .success, "LocalPreflight", providerStatus.detail)\n    }\n\n    func ensureLocalCoreRunning() {\n        guard runtimeMode == .appWiFi else { return }\n        if !EmbeddedCoreManager.shared.isRunning {\n            do { try EmbeddedCoreManager.shared.start() }\n            catch { logs.add(.error, "Core", "تعذر إعادة تشغيل البروكسي المحلي: \\(error.localizedDescription)") }\n        } else {\n            BackgroundKeepAlive.shared.start()\n        }\n    }\n\n    func checkProvider() async {\n        if runtimeMode == .appWiFi { ensureLocalCoreRunning() }\n        providerStatus = .init(health: .checking, detail: "جارٍ فحص البيئة…", activePoint: nil, accuracy: nil)\n        providerStatus = await provider.check()\n        isVirtualLocationActive = providerStatus.activePoint != nil\n        logs.add(providerStatus.health == .unavailable ? .error : .info, "Environment", providerStatus.detail)\n    }\n'''
if needle not in s:
    raise SystemExit('AppStore checkProvider anchor missing')
s = s.replace(needle, repl)
p.write_text(s)

# AppRootView: when app returns active or transitions away for Settings, make sure core/keepalive is alive.
p = root / 'App/AppRootView.swift'
s = p.read_text()
s = s.replace('import SwiftUI\n', 'import SwiftUI\n\n')
s = s.replace('''struct AppRootView: View {\n    @EnvironmentObject private var store: AppStore\n    @State private var splash = true\n''', '''struct AppRootView: View {\n    @EnvironmentObject private var store: AppStore\n    @Environment(\\.scenePhase) private var scenePhase\n    @State private var splash = true\n''')
needle = '''        .task {\n            try? await Task.sleep(nanoseconds: 500_000_000)\n            withAnimation(.easeOut(duration: 0.22)) { splash = false }\n            if store.setupCompleted { await store.checkProvider() }\n        }\n'''
repl = '''        .task {\n            store.ensureLocalCoreRunning()\n            try? await Task.sleep(nanoseconds: 500_000_000)\n            withAnimation(.easeOut(duration: 0.22)) { splash = false }\n            if store.setupCompleted { await store.checkProvider() }\n        }\n        .onChange(of: scenePhase) { phase in\n            if phase == .active || phase == .inactive || phase == .background {\n                store.ensureLocalCoreRunning()\n            }\n        }\n'''
if needle not in s:
    raise SystemExit('AppRootView task anchor missing')
s = s.replace(needle, repl)
p.write_text(s)

# Setup UI: force local preflight before telling the user to enable system proxy.
p = root / 'Features/Setup/SetupFlowView.swift'
s = p.read_text()
s = s.replace('''            Section("1 · تشغيل النواة") {\n                HStack { Label("المنفذ", systemImage: "server.rack"); Spacer(); Text("8888").foregroundColor(.secondary).monospacedDigit() }\n                Button("فتح صفحة حالة البروكسي") { open("http://127.0.0.1:8888/") }\n            }''', '''            Section("1 · اختبار البروكسي قبل تعديل Wi‑Fi") {\n                ValueRow("الخادم", "127.0.0.1")\n                ValueRow("المنفذ", "8888")\n                Button(checking ? "جارٍ اختبار البروكسي المحلي…" : "اختبار 127.0.0.1:8888 الآن") {\n                    Task { checking = true; await store.checkLocalCoreBeforeProxy(); checking = false }\n                }.disabled(checking)\n                StatusRow(status: store.providerStatus)\n                Button("فتح صفحة حالة البروكسي") { open("http://127.0.0.1:8888/") }\n                Text("لا تنتقل لإعدادات Wi‑Fi ولا تشغّل البروكسي اليدوي إلا بعد أن يظهر أن البروكسي المحلي شغّال فعليًا.")\n                    .font(.caption).foregroundColor(.orange)\n            }''')
s = s.replace('''            Section("3 · ضبط بروكسي Wi‑Fi") {\n                Text("من إعدادات Wi‑Fi افتح الشبكة الحالية ← تكوين البروكسي ← يدوي. الخادم هو عنوان IP الخاص بالآيفون على الشبكة، والمنفذ 8888.")\n                    .font(.caption).foregroundColor(.secondary)\n            }''', '''            Section("3 · ضبط بروكسي Wi‑Fi") {\n                Text("بعد نجاح اختبار الخطوة 1 فقط: إعدادات Wi‑Fi ← الشبكة الحالية ← تكوين البروكسي ← يدوي.")\n                    .font(.caption).foregroundColor(.secondary)\n                ValueRow("Server", "127.0.0.1")\n                ValueRow("Port", "8888")\n                Text("إذا انقطع الإنترنت فورًا: أعد Configure Proxy إلى Off، ثم ارجع للتطبيق وشغّل اختبار الخطوة 1. لا تترك البروكسي اليدوي مفعّلًا إذا فشل الاختبار.")\n                    .font(.caption).foregroundColor(.orange)\n            }''')
p.write_text(s)

# Version.
p = root / 'project.yml'
s = p.read_text()
for old in ['MARKETING_VERSION: "3.0.0"', 'MARKETING_VERSION: "7.0.0"', 'MARKETING_VERSION: 3.0.0', 'MARKETING_VERSION: 7.0.0']:
    s = s.replace(old, 'MARKETING_VERSION: "7.1.0"')
for old in ['CURRENT_PROJECT_VERSION: "30"', 'CURRENT_PROJECT_VERSION: "70"', 'CURRENT_PROJECT_VERSION: 30', 'CURRENT_PROJECT_VERSION: 70']:
    s = s.replace(old, 'CURRENT_PROJECT_VERSION: "71"')
p.write_text(s)

print('GeoShift v7.1 proxy preflight patch applied')
