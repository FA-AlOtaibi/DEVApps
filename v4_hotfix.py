from pathlib import Path
import sys
root = Path(sys.argv[1])

# 1) Proxy: treat requests targeting the device/local proxy itself as control requests.
p = root / 'Core/main.go'
s = p.read_text()
old = '''func isLocalControlRequest(r *http.Request) bool {
\th := strings.ToLower(r.Host)
\tif host, _, err := net.SplitHostPort(h); err == nil {
\t\th = host
\t}
\treturn h == "127.0.0.1" || h == "localhost" || h == "rendoor.cert" || h == "geoshift.local"
}
'''
new = '''func isLocalControlRequest(r *http.Request) bool {
\thost := strings.ToLower(hostOnly(r.Host))
\tif host == "127.0.0.1" || host == "localhost" || host == "rendoor.cert" || host == "geoshift.local" {
\t\treturn true
\t}
\tif requestTargetsProxyPort(r.Host) && isLocalInterfaceHost(host) {
\t\treturn true
\t}
\treturn false
}

func requestTargetsProxyPort(authority string) bool {
\t_, port, err := net.SplitHostPort(authority)
\tif err == nil {
\t\treturn port == "8888"
\t}
\treturn !strings.Contains(authority, ":")
}

func isLocalInterfaceHost(host string) bool {
\tip := net.ParseIP(strings.Trim(host, "[]"))
\tif ip == nil {
\t\treturn false
\t}
\tif ip.IsLoopback() {
\t\treturn true
\t}
\taddrs, err := net.InterfaceAddrs()
\tif err != nil {
\t\treturn false
\t}
\tfor _, addr := range addrs {
\t\tvar candidate net.IP
\t\tswitch v := addr.(type) {
\t\tcase *net.IPNet:
\t\t\tcandidate = v.IP
\t\tcase *net.IPAddr:
\t\t\tcandidate = v.IP
\t\t}
\t\tif candidate != nil && candidate.Equal(ip) {
\t\t\treturn true
\t\t}
\t}
\treturn false
}
'''
if old not in s:
    raise SystemExit('main.go local control anchor not found')
s = s.replace(old, new)

# 2) HTTPS verification must not use Apple's gs-loc host. Apple-owned hosts may
# enforce additional TLS policy/pinning, which makes the health check fail even
# when the manual proxy and CA are configured correctly. Intercept a private
# GeoShift-only authority entirely inside the embedded proxy instead.
old = '''\tif r.Method == http.MethodConnect {
\t\tif isWlocHost(r.Host) {
\t\t\tp.mitmConnect(w, r)
\t\t\treturn
\t\t}
\t\tp.tunnelConnect(w, r)
\t\treturn
\t}
'''
new = '''\tif r.Method == http.MethodConnect {
\t\thost := strings.ToLower(hostOnly(r.Host))
\t\tif isWlocHost(r.Host) || host == "geoshift.verify" {
\t\t\tp.mitmConnect(w, r)
\t\t\treturn
\t\t}
\t\tp.tunnelConnect(w, r)
\t\treturn
\t}
'''
if old not in s:
    raise SystemExit('main.go CONNECT anchor not found')
s = s.replace(old, new)
p.write_text(s)

# 3) Local provider health check uses the private intercepted authority.
p = root / 'Services/LocationProviders.swift'
s = p.read_text()
old = 'URL(string: "https://gs-loc.apple.com/geoshift-verify?nonce=\\(UUID().uuidString)")!'
new = 'URL(string: "https://geoshift.verify/geoshift-verify?nonce=\\(UUID().uuidString)")!'
if old not in s:
    raise SystemExit('LocationProviders verify URL anchor not found')
s = s.replace(old, new)
p.write_text(s)

# 4) Map: panning only changes visible search region; it must NOT move selected/spoofed coordinate.
p = root / 'Features/Map/MapHomeView.swift'
s = p.read_text()
old = '''MapKitView(selection: $store.selection, mapSystem: store.mapSystem, onTap: { c in choose(c) }, onCenterChanged: { c, meters in visibleRegion = .init(center: c, latitudinalMeters: meters, longitudinalMeters: meters); store.selectMapPoint(GeoPoint(c)); reverseGeocode(c) }, cameraTarget: cameraTarget, cameraRevision: cameraRevision).ignoresSafeArea()'''
new = '''MapKitView(selection: $store.selection, mapSystem: store.mapSystem, onTap: { c in choose(c) }, onCenterChanged: { c, meters in visibleRegion = .init(center: c, latitudinalMeters: meters, longitudinalMeters: meters) }, cameraTarget: cameraTarget, cameraRevision: cameraRevision).ignoresSafeArea()'''
if old not in s:
    raise SystemExit('MapHomeView map anchor not found')
s = s.replace(old, new)
s = s.replace('''Text("اضغط على الخريطة أو حرّكها أو ابحث عن مكان لاختيار الموقع.")''', '''Text("اضغط على نقطة في الخريطة أو ابحث عن مكان لاختيار الموقع. تحريك الخريطة وحده لا يغيّر الموقع المحدد.")''')
p.write_text(s)
print('GeoShift v4.2 hotfix applied: local-loop guard + private HTTPS verification + stable map selection')
