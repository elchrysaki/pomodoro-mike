import AppKit
import SwiftUI

@main
struct MikeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = TimerController()
    private let camera = CameraAttentionMonitor()
    private var windows: AppWindows?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let windows = AppWindows(controller: controller, camera: camera)
        self.windows = windows
        windows.start()

        if controller.phoneGuardEnabled {
            camera.start(for: controller)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        windows?.showFloatingWidget()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        camera.stop()
    }
}
