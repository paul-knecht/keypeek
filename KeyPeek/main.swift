import AppKit

// This is where the app starts.
// We create the app, give it our AppDelegate (the object that reacts to
// app events like "finished launching"), and start the event loop.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
