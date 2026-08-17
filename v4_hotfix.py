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
\t// When iOS is configured to use the iPhone's own Wi-Fi address as the
\t// manual proxy, opening the proxy/status address itself must terminate
\t// locally. Forwarding it would recursively dial :8888 through this server
\t// until the process exhausts sockets/file descriptors.
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
\t// A bare local host is also a local control request when reached directly.
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
    raise SystemExit('main.go anchor not found')
s = s.replace(old, new)
p.write_text(s)

# 2) Map: panning only changes visible search region; it must NOT move selected/spoofed coordinate.
p = root / 'Features/Map/MapHomeView.swift'
s = p.read_text()
old = '''MapKitView(selection: $store.selection, mapSystem: store.mapSystem, onTap: { c in choose(c) }, onCenterChanged: { c, meters in visibleRegion = .init(center: c, latitudinalMeters: meters, longitudinalMeters: meters); store.selectMapPoint(GeoPoint(c)); reverseGeocode(c) }, cameraTarget: cameraTarget, cameraRevision: cameraRevision).ignoresSafeArea()'''
new = '''MapKitView(selection: $store.selection, mapSystem: store.mapSystem, onTap: { c in choose(c) }, onCenterChanged: { c, meters in visibleRegion = .init(center: c, latitudinalMeters: meters, longitudinalMeters: meters) }, cameraTarget: cameraTarget, cameraRevision: cameraRevision).ignoresSafeArea()'''
if old not in s:
    raise SystemExit('MapHomeView map anchor not found')
s = s.replace(old, new)
s = s.replace('''Text("اضغط على الخريطة أو حرّكها أو ابحث عن مكان لاختيار الموقع.")''', '''Text("اضغط على نقطة في الخريطة أو ابحث عن مكان لاختيار الموقع. تحريك الخريطة وحده لا يغيّر الموقع المحدد.")''')
p.write_text(s)
print('GeoShift v4 hotfix applied: local proxy loop guard + stable map selection')
