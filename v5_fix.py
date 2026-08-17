from pathlib import Path
import sys
p = Path(sys.argv[1]) / 'Services/PacketTunnelController.swift'
s = p.read_text()
s = s.replace('try await withCheckedThrowingContinuation { c in m.saveToPreferences { e in if let e { c.resume(throwing:e) } else { c.resume(returning:()) } } }', 'try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in m.saveToPreferences { e in if let e { c.resume(throwing:e) } else { c.resume(returning:()) } } }')
s = s.replace('try await withCheckedThrowingContinuation { c in m.loadFromPreferences { e in if let e { c.resume(throwing:e) } else { c.resume(returning:()) } } }', 'try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in m.loadFromPreferences { e in if let e { c.resume(throwing:e) } else { c.resume(returning:()) } } }')
p.write_text(s)
print('v5 continuation fix applied')
