from pathlib import Path
import sys
root=Path(sys.argv[1])
for rel in ['Services/BackgroundKeepAlive.swift','Services/CertificateTrustVerifier.swift']:
    p=root/rel
    p.write_text(p.read_text().replace('\\n','\n'))
print('GeoShift parity v3 text files normalized')
