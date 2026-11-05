import AppKit
import Combine
import SwiftUI

@MainActor
final class AppWindows: NSObject, NSPopoverDelegate {
    private let controller: TimerController
    private let camera: CameraAttentionMonitor
    private var floatingPanel: FloatingPanel?
    private var dashboardWindow: NSWindow?
    private var alertPanel: NSPanel?
    private var popover: NSPopover?
    private var popoverMouseMonitor: Any?
    private var outsideClickMonitor: Any?
    private var workspaceActivationObserver: Any?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(controller: TimerController, camera: CameraAttentionMonitor) {
        self.controller = controller
        self.camera = camera
        super.init()
    }

    func start() {
        createFloatingPanel()
        createStatusItem()
        observeAlerts()
    }

    func showDashboard() {
        popover?.close()
        if dashboardWindow == nil { createDashboardWindow() }
        guard let dashboardWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func showDashboardFromMenu() { showDashboard() }

    @objc private func showWidget() {
        showFloatingWidget()
    }

    func showFloatingWidget() {
        floatingPanel?.orderFrontRegardless()
    }

    @objc private func toggleTimer() {
        controller.toggleRunning()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func createFloatingPanel() {
        let size = NSSize(width: 228, height: 268)
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setFrameAutosaveName("MikeFloatingWidget")

        let root = FloatingWidgetView(
            controller: controller,
            openQuickMenu: { [weak self] in self?.showQuickMenu() },
            finishMovingWidget: { [weak self] in
                self?.finishMovingFloatingWidget()
            },
            closeApp: { NSApp.terminate(nil) }
        )
        let host = NSHostingView(rootView: root)
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = host

        if !panel.setFrameUsingName("MikeFloatingWidget") {
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            panel.setFrameOrigin(NSPoint(
                x: screenFrame.maxX - size.width - 28,
                y: screenFrame.maxY - size.height - 28
            ))
        }
        panel.orderFrontRegardless()
        floatingPanel = panel
    }

    private func finishMovingFloatingWidget() {
        floatingPanel?.saveFrame(usingName: "MikeFloatingWidget")
    }

    private func createDashboardWindow() {
        let root = DashboardView(controller: controller, camera: camera)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Mike"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.setFrameAutosaveName("MikeDashboard")
        dashboardWindow = window
    }

    private func showQuickMenu() {
        guard let contentView = floatingPanel?.contentView else { return }
        if popover?.isShown == true {
            popover?.close()
            return
        }
        let menu = NSPopover()
        menu.delegate = self
        // A transient popover consumes the first outside mouse-down before the
        // floating panel can deliver it to its X button. Keep dismissal under
        // our control so the X remains a real, reliable native control.
        menu.behavior = .applicationDefined
        menu.animates = true
        menu.contentSize = NSSize(width: 300, height: 330)
        menu.contentViewController = NSHostingController(
            rootView: QuickMenuView(controller: controller) { [weak self] in
                self?.popover?.close()
                self?.showDashboard()
            }
        )
        popover = menu
        installPopoverMouseMonitor()
        menu.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minX)
    }

    func popoverWillShow(_ notification: Notification) {
        controller.isQuickMenuPresented = true
    }

    func popoverWillClose(_ notification: Notification) {
        controller.isQuickMenuPresented = false
    }

    func popoverDidClose(_ notification: Notification) {
        removePopoverMouseMonitor()
        if let closedPopover = notification.object as? NSPopover,
           popover === closedPopover {
            popover = nil
        }
    }

    private func installPopoverMouseMonitor() {
        removePopoverMouseMonitor()
        popoverMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self,
                  self.popover?.isShown == true,
                  let panel = self.floatingPanel else { return event }

            // Preserve interaction inside the menu itself. Clicking elsewhere
            // in Mike closes the menu just like a native transient popover.
            guard event.window === panel else {
                if event.window !== self.popover?.contentViewController?.view.window {
                    self.popover?.close()
                }
                return event
            }

            // Intercept only the visible X region on mouse-down, matching
            // Safari's immediate native close behavior.
            let contentSize = panel.contentView?.bounds.size ?? panel.frame.size
            let closeRect = NSRect(
                x: contentSize.width - 64,
                y: contentSize.height - 64,
                width: 64,
                height: 64
            )
            guard closeRect.contains(event.locationInWindow) else { return event }
            NSApp.terminate(nil)
            return nil
        }

        // Global monitors observe real clicks in other apps. This restores the
        // familiar transient-popover dismissal without stealing the panel's X.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.popover?.isShown == true else { return }
                self?.popover?.close()
            }
        }

        // Also dismiss on Command-Tab or programmatic app activation, where
        // no outside mouse event exists.
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication,
                  application.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor in
                guard self?.popover?.isShown == true else { return }
                self?.popover?.close()
            }
        }
    }

    private func removePopoverMouseMonitor() {
        if let popoverMouseMonitor {
            NSEvent.removeMonitor(popoverMouseMonitor)
            self.popoverMouseMonitor = nil
        }
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
            self.workspaceActivationObserver = nil
        }
    }

    private func observeAlerts() {
        controller.$isDistractionAlertPresented
            .removeDuplicates()
            .sink { [weak self] shouldShow in
                if shouldShow { self?.showDistractionAlert() }
                else { self?.hideDistractionAlert() }
            }
            .store(in: &cancellables)
    }

    private func showDistractionAlert() {
        if alertPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 430),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(
                rootView: DistractionOverlayView(controller: controller, camera: camera)
            )
            panel.center()
            alertPanel = panel
        }
        alertPanel?.center()
        alertPanel?.orderFrontRegardless()
    }

    private func hideDistractionAlert() {
        alertPanel?.orderOut(nil)
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Mike")

        let menu = NSMenu()
        let timerItem = NSMenuItem(title: "Start or pause timer", action: #selector(toggleTimer), keyEquivalent: " ")
        timerItem.target = self
        menu.addItem(timerItem)
        menu.addItem(.separator())

        let dashboardItem = NSMenuItem(title: "Open dashboard", action: #selector(showDashboardFromMenu), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let widgetItem = NSMenuItem(title: "Show floating buddy", action: #selector(showWidget), keyEquivalent: "w")
        widgetItem.target = self
        menu.addItem(widgetItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mike", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
