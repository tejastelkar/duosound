import AppKit

// Wire up the delegate BEFORE NSApplicationMain boots the run loop.
// AppDelegate is not @MainActor so this init is safe here.
let _delegate = AppDelegate()
NSApplication.shared.delegate = _delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
