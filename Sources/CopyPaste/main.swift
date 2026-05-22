import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
// Cast through ObjC runtime to bypass Swift concurrency actor-isolation
(app as AnyObject).setValue(delegate, forKey: "delegate")
app.setActivationPolicy(.accessory)
app.run()
