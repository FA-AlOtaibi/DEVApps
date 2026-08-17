from pathlib import Path
import sys

root = Path(sys.argv[1])

def write(rel, text):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)

def replace(rel, old, new):
    p = root / rel
    s = p.read_text()
    if old not in s:
        raise SystemExit(f'missing pattern in {rel}: {old[:80]!r}')
    p.write_text(s.replace(old, new))

write('Resources/GeoShift.entitlements', '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.developer.networking.networkextension</key><array><string>packet-tunnel-provider</string></array></dict></plist>''')
write('TunnelExtension/GeoShiftTunnel.entitlements', '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.developer.networking.networkextension</key><array><string>packet-tunnel-provider</string></array></dict></plist>''')
write('TunnelExtension/Info.plist', '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>ar</string><key>CFBundleDisplayName</key><string>GeoShift Tunnel</string>
<key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string><key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string><key>CFBundleName</key><string>$(PRODUCT_NAME)</string>
<key>CFBundlePackageType</key><string>XPC!</string><key>CFBundleShortVersionString</key><string>$(MARKETING_VERSION)</string><key>CFBundleVersion</key><string>$(CURRENT_PROJECT_VERSION)</string>
<key>NSExtension</key><dict><key>NSExtensionPointIdentifier</key><string>com.apple.networkextension.packet-tunnel</string><key>NSExtensionPrincipalClass</key><string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string></dict>
</dict></plist>''')

write('TunnelExtension/PacketTunnelProvider.swift', r'''import Foundation
import NetworkExtension
import Darwin

@_silgen_name("geoshift_core_start_with_ca") private func core_start_with_ca(_ certPEM: UnsafePointer<CChar>, _ keyPEM: UnsafePointer<CChar>) -> Int32
@_silgen_name("geoshift_core_stop") private func core_stop() -> Int32
@_silgen_name("geoshift_core_setcoords") private func core_setcoords(_ lat: Double, _ lon: Double, _ enabled: Int32, _ accuracy: Int32, _ motion: Int32)
@_silgen_name("geoshift_core_status_json") private func core_status_json() -> UnsafeMutablePointer<CChar>?
@_silgen_name("geoshift_core_free") private func core_free(_ pointer: UnsafeMutableRawPointer?)

final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let certData = options?["certPEM"] as? NSData,
              let keyData = options?["keyPEM"] as? NSData,
              let cert = String(data: certData as Data, encoding: .utf8),
              let key = String(data: keyData as Data, encoding: .utf8) else {
            completionHandler(NSError(domain: "GeoShiftTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing CA material"]))
            return
        }
        let rc = cert.withCString { c in key.withCString { k in core_start_with_ca(c, k) } }
        guard rc == 0 else {
            completionHandler(NSError(domain: "GeoShiftTunnel", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: "GeoShiftCore failed to start"]))
            return
        }
        let enabled = (options?["enabled"] as? NSNumber)?.boolValue ?? false
        let lat = (options?["lat"] as? NSNumber)?.doubleValue ?? 0
        let lon = (options?["lon"] as? NSNumber)?.doubleValue ?? 0
        let accuracy = (options?["accuracy"] as? NSNumber)?.int32Value ?? 25
        let motion = (options?["motion"] as? NSNumber)?.boolValue ?? false
        core_setcoords(lat, lon, enabled ? 1 : 0, accuracy, motion ? 1 : 0)

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4 = NEIPv4Settings(addresses: ["10.222.0.2"], subnetMasks: ["255.255.255.0"])
        var routes: [NEIPv4Route] = []
        for host in ["gs-loc.apple.com", "gs-loc-cn.apple.com"] {
            for ip in Self.resolveIPv4(host) { routes.append(NEIPv4Route(destinationAddress: ip, subnetMask: "255.255.255.255")) }
        }
        guard !routes.isEmpty else {
            _ = core_stop()
            completionHandler(NSError(domain: "GeoShiftTunnel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not resolve WLOC hosts"]))
            return
        }
        ipv4.includedRoutes = routes
        settings.ipv4Settings = ipv4
        let proxy = NEProxySettings()
        proxy.httpEnabled = true
        proxy.httpServer = NEProxyServer(address: "127.0.0.1", port: 8888)
        proxy.httpsEnabled = true
        proxy.httpsServer = NEProxyServer(address: "127.0.0.1", port: 8888)
        proxy.excludeSimpleHostnames = true
        proxy.exceptionList = ["127.0.0.1", "localhost"]
        settings.proxySettings = proxy
        settings.mtu = 1500
        setTunnelNetworkSettings(settings, completionHandler: completionHandler)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        _ = core_stop(); completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let object = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any], let action = object["action"] as? String else { completionHandler?(nil); return }
        if action == "set" {
            let enabled = object["enabled"] as? Bool ?? false
            core_setcoords(object["lat"] as? Double ?? 0, object["lon"] as? Double ?? 0, enabled ? 1 : 0, Int32(object["accuracy"] as? Int ?? 25), (object["motion"] as? Bool ?? false) ? 1 : 0)
            completionHandler?(try? JSONSerialization.data(withJSONObject: ["success": true]))
        } else if action == "status", let raw = core_status_json() {
            defer { core_free(UnsafeMutableRawPointer(raw)) }
            completionHandler?(Data(String(cString: raw).utf8))
        } else { completionHandler?(nil) }
    }

    private static func resolveIPv4(_ host: String) -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return [] }
        defer { freeaddrinfo(first) }
        var out: [String] = []
        var cur: UnsafeMutablePointer<addrinfo>? = first
        while let info = cur {
            if info.pointee.ai_family == AF_INET, let addr = info.pointee.ai_addr {
                var sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, &sin.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil { out.append(String(cString: buffer)) }
            }
            cur = info.pointee.ai_next
        }
        return Array(Set(out))
    }
}
''')

write('Services/PacketTunnelController.swift', r'''import Foundation
import NetworkExtension

@MainActor
final class PacketTunnelController {
    static let shared = PacketTunnelController()
    private var manager: NETunnelProviderManager?
    private init() {}

    func start(point: GeoPoint?, accuracy: Double, motion: Bool) async throws {
        EmbeddedCoreManager.shared.stop()
        let material = try EmbeddedCoreManager.shared.tunnelCertificateMaterial()
        let m = try await configuredManager()
        guard let session = m.connection as? NETunnelProviderSession else { throw LocationProviderError.unavailable("تعذر الوصول إلى جلسة GeoShift Tunnel.") }
        if session.status == .connected { try await send(point: point, accuracy: accuracy, motion: motion); return }
        var options: [String: NSObject] = ["certPEM": Data(material.certificatePEM.utf8) as NSData, "keyPEM": Data(material.privateKeyPEM.utf8) as NSData, "enabled": NSNumber(value: point != nil), "accuracy": NSNumber(value: Int(accuracy)), "motion": NSNumber(value: motion)]
        if let point { options["lat"] = NSNumber(value: point.latitude); options["lon"] = NSNumber(value: point.longitude) }
        try session.startTunnel(options: options)
        for _ in 0..<40 { if session.status == .connected { return }; try await Task.sleep(nanoseconds: 250_000_000) }
        throw LocationProviderError.unavailable("انتهت مهلة تشغيل GeoShift Tunnel. تأكد أن التوقيع يحتوي صلاحية Network Extensions.")
    }

    func stop() async { guard let m = try? await configuredManager() else { return }; m.connection.stopVPNTunnel() }
    func connectionStatus() async -> NEVPNStatus { guard let m = try? await configuredManager() else { return .invalid }; return m.connection.status }

    func send(point: GeoPoint?, accuracy: Double, motion: Bool) async throws {
        let m = try await configuredManager()
        guard let session = m.connection as? NETunnelProviderSession, session.status == .connected else { throw LocationProviderError.unavailable("GeoShift Tunnel غير متصل.") }
        _ = try await message(session, ["action":"set", "enabled":point != nil, "lat":point?.latitude ?? 0, "lon":point?.longitude ?? 0, "accuracy":Int(accuracy), "motion":motion])
    }

    func status() async -> ProviderStatus {
        do {
            let m = try await configuredManager()
            guard let session = m.connection as? NETunnelProviderSession, session.status == .connected else { return .init(health: .unavailable, detail: "GeoShift Tunnel غير متصل. شغّله من داخل التطبيق ووافق على إضافة إعداد VPN.", activePoint: nil, accuracy: nil) }
            let data = try await message(session, ["action":"status"])
            guard let s = try? JSONDecoder().decode(CoreState.self, from: data) else { return .init(health: .unavailable, detail: "التانل متصل لكن تعذر قراءة حالة النواة.", activePoint: nil, accuracy: nil) }
            return .init(health: s.enabled ? .ready : .inactive, detail: s.enabled ? "GeoShift Tunnel متصل والموقع مفعّل · الطلبات: \(s.requests) · المعدلة: \(s.patched)" : "GeoShift Tunnel متصل وجاهز · الموقع متوقف.", activePoint: s.enabled ? GeoPoint(latitude: s.lat, longitude: s.lon) : nil, accuracy: Double(s.accuracy))
        } catch { return .init(health: .unavailable, detail: "فشل فحص GeoShift Tunnel: \(error.localizedDescription)", activePoint: nil, accuracy: nil) }
    }

    private func configuredManager() async throws -> NETunnelProviderManager {
        if let manager { return manager }
        let all: [NETunnelProviderManager] = try await withCheckedThrowingContinuation { c in NETunnelProviderManager.loadAllFromPreferences { m,e in if let e { c.resume(throwing:e) } else { c.resume(returning:m ?? []) } } }
        let m = all.first ?? NETunnelProviderManager()
        let p = (m.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        p.providerBundleIdentifier = "com.geoshiftlabs.GeoShift.PacketTunnel"; p.serverAddress = "GeoShift Local WLOC Tunnel"
        m.protocolConfiguration = p; m.localizedDescription = "GeoShift"; m.isEnabled = true
        try await withCheckedThrowingContinuation { c in m.saveToPreferences { e in if let e { c.resume(throwing:e) } else { c.resume(returning:()) } } }
        try await withCheckedThrowingContinuation { c in m.loadFromPreferences { e in if let e { c.resume(throwing:e) } else { c.resume(returning:()) } } }
        manager = m; return m
    }

    private func message(_ session: NETunnelProviderSession, _ object: [String:Any]) async throws -> Data {
        let d = try JSONSerialization.data(withJSONObject: object)
        return try await withCheckedThrowingContinuation { c in do { try session.sendProviderMessage(d) { c.resume(returning:$0 ?? Data()) } } catch { c.resume(throwing:error) } }
    }
    private struct CoreState: Decodable { let enabled: Bool; let lat: Double; let lon: Double; let accuracy: Int; let motion: Bool; let requests: UInt64; let patched: UInt64; let running: Bool }
}
''')

# expose CA material to tunnel
p = root/'Services/EmbeddedCoreManager.swift'
s = p.read_text()
if 'func tunnelCertificateMaterial()' not in s:
    s += '''\n\nextension EmbeddedCoreManager {\n    func tunnelCertificateMaterial() throws -> CertificateAuthorityMaterial {\n        if let material = try keychain.load() { return material }\n        guard let raw = core_generate_ca_json() else { throw LocationProviderError.unavailable("تعذر إنشاء شهادة GeoShift المحلية.") }\n        defer { core_free(UnsafeMutableRawPointer(raw)) }\n        let data = Data(String(cString: raw).utf8)\n        guard let material = try? JSONDecoder().decode(CertificateAuthorityMaterial.self, from: data) else { throw LocationProviderError.badPayload }\n        try keychain.save(material); return material\n    }\n}\n'''
    p.write_text(s)

# provider implementation
p = root/'Services/LocationProviders.swift'; s=p.read_text(); i=s.index('final class LocalProxyProvider')
s=s[:i]+'''final class LocalProxyProvider: LocationTestProvider {\n    let name = "GeoShift Tunnel"\n    private let tunnel = PacketTunnelController.shared\n    func check() async -> ProviderStatus { await tunnel.status() }\n    func apply(point: GeoPoint, accuracy: Double, motion: Bool) async throws { if await tunnel.connectionStatus() == .connected { try await tunnel.send(point: point, accuracy: accuracy, motion: motion) } else { try await tunnel.start(point: point, accuracy: accuracy, motion: motion) } }\n    func clear() async throws { if await tunnel.connectionStatus() == .connected { try await tunnel.send(point: nil, accuracy: 25, motion: false) } else { try await tunnel.start(point: nil, accuracy: 25, motion: false) } }\n}\n'''; p.write_text(s)

# AppStore: stop auto local core, tunnel setup method, tunnel motion updates
p=root/'App/AppStore.swift'; s=p.read_text()
start=s.find('        if runtimeMode == .appWiFi {\n            do {')
if start >= 0:
    end=s.find('        }\n    }', start)
    s=s[:start]+'        if runtimeMode == .appWiFi { isVirtualLocationActive = UserDefaults.standard.bool(forKey: Key.active) }\n'+s[end+10:]
s=s.replace('''        if mode == .appWiFi {\n            do { try EmbeddedCoreManager.shared.start() }\n            catch { logs.add(.error, "Core", error.localizedDescription) }\n        } else {\n            EmbeddedCoreManager.shared.stop()\n        }''','''        if mode != .appWiFi { Task { await PacketTunnelController.shared.stop() } }''')
s=s.replace('func setMotion(_ value: Bool) { motionSimulation = value; UserDefaults.standard.set(value, forKey: Key.motion); if runtimeMode == .appWiFi, isVirtualLocationActive { EmbeddedCoreManager.shared.set(point: selection?.wgs84, accuracy: accuracy, motion: value) } }','''func setMotion(_ value: Bool) { motionSimulation = value; UserDefaults.standard.set(value, forKey: Key.motion); if runtimeMode == .appWiFi, isVirtualLocationActive { Task { try? await PacketTunnelController.shared.send(point: selection?.wgs84, accuracy: accuracy, motion: value) } } }''')
needle='    func checkProvider() async {'
if 'func prepareAppTunnel()' not in s:
    s=s.replace(needle,'''    func prepareAppTunnel() async {\n        providerStatus = .init(health: .checking, detail: "جارٍ تهيئة GeoShift Tunnel…", activePoint: nil, accuracy: nil)\n        do { try await PacketTunnelController.shared.start(point: nil, accuracy: accuracy, motion: false); providerStatus = await localProvider.check(); logs.add(.success, "Tunnel", "تم تشغيل GeoShift Tunnel") }\n        catch { providerStatus = .init(health: .unavailable, detail: "تعذر تشغيل GeoShift Tunnel: \\(error.localizedDescription)", activePoint: nil, accuracy: nil); logs.add(.error, "Tunnel", error.localizedDescription) }\n    }\n\n'''+needle)
p.write_text(s)

# map drag must not select
p=root/'Features/Map/MapHomeView.swift'; s=p.read_text(); s=s.replace('visibleRegion = .init(center: c, latitudinalMeters: meters, longitudinalMeters: meters); store.selectMapPoint(GeoPoint(c)); reverseGeocode(c)', 'visibleRegion = .init(center: c, latitudinalMeters: meters, longitudinalMeters: meters)'); s=s.replace('اضغط على الخريطة أو حرّكها أو ابحث عن مكان لاختيار الموقع.', 'اضغط على نقطة بالخريطة أو ابحث عن مكان لاختيار الموقع.'); p.write_text(s)

replace('Models/RuntimeModels.swift', 'case .appWiFi: return "بروكسي يعمل داخل GeoShift · لشبكة Wi‑Fi الحالية"', 'case .appWiFi: return "GeoShift Tunnel داخل iOS · بدون إعداد بروكسي Wi‑Fi يدوي"')

# setup screen
p=root/'Features/Setup/SetupFlowView.swift'; s=p.read_text(); a=s.index('    private var localSetup: some View {'); b=s.index('    private var thirdPartySetup: some View {')
local='''    private var localSetup: some View {\n        List {\n            Section { setupHeader(icon: "shield.lefthalf.filled", title: "وضع التطبيق", text: "يشغّل GeoShift عبر Packet Tunnel داخل iOS. لا تحتاج تضبط بروكسي Wi‑Fi يدويًا ولا تكتب IP أو منفذ.") }\n            Section("1 · تثبيت شهادة CA") {\n                Button("تنزيل شهادة GeoShift") { do { try EmbeddedCoreManager.shared.start(); open("http://127.0.0.1:8888/cert") } catch { store.toast = error.localizedDescription } }\n                Text("بعد تنزيلها: الإعدادات ← عام ← VPN وإدارة الجهاز لتثبيت الشهادة، ثم عام ← حول ← إعدادات الوثوق بالشهادات وفعّل الثقة الكاملة.").font(.caption).foregroundColor(.secondary)\n            }\n            Section("2 · تشغيل GeoShift Tunnel") {\n                Button(checking ? "جارٍ تشغيل التانل…" : "تشغيل GeoShift Tunnel") { Task { checking = true; await store.prepareAppTunnel(); checking = false } }.disabled(checking)\n                Text("قد يظهر طلب من iOS لإضافة إعداد VPN. وافق عليه. لا يوجد إعداد HTTP Proxy يدوي في Wi‑Fi.").font(.caption).foregroundColor(.secondary)\n            }\n            Section("3 · فحص فعلي") { Button(checking ? "جارٍ الفحص…" : "فحص GeoShift Tunnel") { Task { checking = true; await store.checkProvider(); checking = false } }.disabled(checking); StatusRow(status: store.providerStatus) }\n            Section { Button("إنهاء الإعداد") { store.finishSetup() }.frame(maxWidth: .infinity).disabled(store.providerStatus.health != .inactive && store.providerStatus.health != .ready); Button("اختيار وضع آخر", role: .cancel) { store.resetSetup() }.frame(maxWidth: .infinity) }\n        }.listStyle(.insetGrouped)\n    }\n\n'''
p.write_text(s[:a]+local+s[b:])

# settings/diagnostics text
p=root/'Features/Settings/SettingsScreen.swift'; s=p.read_text(); s=s.replace('ValueRow("البروكسي", "منفذ 8888")', 'ValueRow("المسار", "GeoShift Packet Tunnel")').replace('ValueRow("الإصدار", "3.0.0")','ValueRow("الإصدار", "5.0.0")'); p.write_text(s)
p=root/'Features/Settings/DiagnosticsScreen.swift'; s=p.read_text().replace('Version: 3.0.0','Version: 5.0.0'); p.write_text(s)

write('project.yml', '''name: GeoShift\noptions:\n  bundleIdPrefix: com.geoshiftlabs\n  deploymentTarget:\n    iOS: "15.0"\n  createIntermediateGroups: true\nsettings:\n  base:\n    SWIFT_VERSION: "5.9"\n    MARKETING_VERSION: "5.0.0"\n    CURRENT_PROJECT_VERSION: "50"\n    CODE_SIGN_STYLE: Manual\n    CODE_SIGNING_ALLOWED: "NO"\n    CODE_SIGNING_REQUIRED: "NO"\ntargets:\n  GeoShiftTunnel:\n    type: app-extension\n    platform: iOS\n    sources:\n      - path: TunnelExtension\n    settings:\n      base:\n        PRODUCT_BUNDLE_IDENTIFIER: com.geoshiftlabs.GeoShift.PacketTunnel\n        PRODUCT_NAME: GeoShiftTunnel\n        INFOPLIST_FILE: TunnelExtension/Info.plist\n        CODE_SIGN_ENTITLEMENTS: TunnelExtension/GeoShiftTunnel.entitlements\n        SKIP_INSTALL: YES\n        OTHER_LDFLAGS: "$(inherited) -lgeoshiftcore"\n        LIBRARY_SEARCH_PATHS: "$(PROJECT_DIR)/Core/build/$(PLATFORM_NAME)"\n        APPLICATION_EXTENSION_API_ONLY: YES\n  GeoShift:\n    type: application\n    platform: iOS\n    sources:\n      - path: App\n      - path: Models\n      - path: Services\n      - path: Features\n      - path: Utilities\n      - path: Resources\n    settings:\n      base:\n        PRODUCT_BUNDLE_IDENTIFIER: com.geoshiftlabs.GeoShift\n        PRODUCT_NAME: GeoShift\n        INFOPLIST_FILE: Resources/Info.plist\n        CODE_SIGN_ENTITLEMENTS: Resources/GeoShift.entitlements\n        TARGETED_DEVICE_FAMILY: "1"\n        OTHER_LDFLAGS: "$(inherited) -lgeoshiftcore"\n        LIBRARY_SEARCH_PATHS: "$(PROJECT_DIR)/Core/build/$(PLATFORM_NAME)"\n    dependencies:\n      - target: GeoShiftTunnel\n        embed: true\n  GeoShiftTests:\n    type: bundle.unit-test\n    platform: iOS\n    sources:\n      - path: Tests\n    settings:\n      base:\n        OTHER_LDFLAGS: "$(inherited) -lgeoshiftcore"\n        LIBRARY_SEARCH_PATHS: "$(PROJECT_DIR)/Core/build/$(PLATFORM_NAME)"\n    dependencies:\n      - target: GeoShift\nschemes:\n  GeoShift:\n    build:\n      targets:\n        GeoShift: all\n        GeoShiftTunnel: all\n    run:\n      config: Debug\n    test:\n      config: Debug\n      targets:\n        - GeoShiftTests\n    archive:\n      config: Release\n''')

print('v5 tunnel patch applied')
