import Foundation

let remap = #"{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000002a}]}"#
let clear = #"{"UserKeyMapping":[]}"#

func hidutil(_ json: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    p.arguments = ["property", "--set", json]
    try? p.run()
    p.waitUntilExit()
}

let nc = DistributedNotificationCenter.default()
for name in ["com.apple.screenIsUnlocked", "com.apple.sessionDidBecomeActive"] {
    nc.addObserver(forName: .init(name), object: nil, queue: .main) { _ in hidutil(remap) }
}
for name in ["com.apple.screenIsLocked", "com.apple.sessionDidResignActive"] {
    nc.addObserver(forName: .init(name), object: nil, queue: .main) { _ in hidutil(clear) }
}

hidutil(remap)
RunLoop.current.run()
