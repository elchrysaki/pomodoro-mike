import AppKit
import SwiftUI

struct FloatingWidgetView: View {
    @ObservedObject var controller: TimerController
    let openQuickMenu: () -> Void
    let finishMovingWidget: () -> Void
    let closeApp: () -> Void
    @State private var isPointerInteracting = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                CharacterView(mood: controller.characterMood, compact: true)
                    .frame(height: 125)

                Text(controller.phase.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)

                Text(controller.formattedTime)
                    .font(.system(size: 29, weight: .medium, design: .rounded).monospacedDigit())

                ProgressView(value: controller.progress)
                    .progressViewStyle(.linear)
                    .tint(controller.characterMood == .angry ? .red : .primary)
                    .frame(width: 118)
            }
            .frame(width: 176, height: 216)
            .modifier(FloatingWidgetGlass(
                settings: controller.widgetGlassSettings,
                isInteracting: isPointerInteracting || controller.isQuickMenuPresented
            ))

            // Safari-style AppKit interaction container: the background owns
            // window dragging while a native child control owns the X hit area.
            NativeWidgetDragSurface(
                openQuickMenu: openQuickMenu,
                finishMovingWidget: finishMovingWidget,
                interactionChanged: { isPointerInteracting = $0 }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Keep the draggable region physically below the close control.
            // This mirrors a native tab: moving and closing never share a hit
            // target, so a drag cannot steal the X's mouse-down.
            .padding(.top, 52)
            .zIndex(10)
            .help("Click for timer controls. Drag anywhere outside the X to move.")

            if controller.isQuickMenuPresented {
                NativeCloseButton(action: closeApp)
                    .frame(width: 44, height: 44)
                    .offset(x: -5, y: 5)
                    .zIndex(20)
            }
        }
        .padding(18)
    }
}

private struct NativeWidgetDragSurface: NSViewRepresentable {
    let openQuickMenu: () -> Void
    let finishMovingWidget: () -> Void
    let interactionChanged: (Bool) -> Void

    func makeNSView(context: Context) -> NativeWidgetDragView {
        let view = NativeWidgetDragView(frame: .zero)
        view.openQuickMenu = openQuickMenu
        view.finishMovingWidget = finishMovingWidget
        view.interactionChanged = interactionChanged
        return view
    }

    func updateNSView(_ nsView: NativeWidgetDragView, context: Context) {
        nsView.openQuickMenu = openQuickMenu
        nsView.finishMovingWidget = finishMovingWidget
        nsView.interactionChanged = interactionChanged
    }
}

private struct NativeCloseButton: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> ImmediateCloseButton {
        let button = ImmediateCloseButton(frame: .zero)
        button.closeAction = action
        return button
    }

    func updateNSView(_ nsView: ImmediateCloseButton, context: Context) {
        nsView.closeAction = action
    }
}

private final class ImmediateCloseButton: NSButton {
    var closeAction: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let symbol = NSImage(
            systemSymbolName: "xmark",
            accessibilityDescription: "Quit Mike"
        )?.withSymbolConfiguration(NSImage.SymbolConfiguration(
            pointSize: 12,
            weight: .bold
        ))
        symbol?.isTemplate = true
        image = symbol
        imagePosition = .imageOnly
        isBordered = false
        focusRingType = .none
        contentTintColor = NSColor.labelColor.withAlphaComponent(0.78)
        toolTip = "Quit Mike and stop the timer"
        setAccessibilityLabel("Quit Mike")
        target = self
        action = #selector(closeImmediately)
        sendAction(on: .leftMouseDown)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func closeImmediately() {
        closeAction?()
    }
}

private final class NativeWidgetDragView: NSView {
    var openQuickMenu: (() -> Void)?
    var finishMovingWidget: (() -> Void)?
    var interactionChanged: ((Bool) -> Void)?
    private var mouseDownPoint: NSPoint?
    private var windowOriginAtMouseDown: NSPoint?
    private var didDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        mouseDownPoint = window.convertPoint(toScreen: event.locationInWindow)
        windowOriginAtMouseDown = window.frame.origin
        didDrag = false
        interactionChanged?(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let mouseDownPoint,
              let windowOriginAtMouseDown else { return }

        let pointer = window.convertPoint(toScreen: event.locationInWindow)
        let deltaX = pointer.x - mouseDownPoint.x
        let deltaY = pointer.y - mouseDownPoint.y
        guard didDrag || hypot(deltaX, deltaY) >= 3 else { return }

        didDrag = true
        // AppKit screen coordinates and NSWindow origins both use a bottom-left
        // origin, so the pointer delta maps directly without SwiftUI conversion.
        window.setFrameOrigin(NSPoint(
            x: windowOriginAtMouseDown.x + deltaX,
            y: windowOriginAtMouseDown.y + deltaY
        ))
    }

    override func mouseUp(with event: NSEvent) {
        let pointerDistance: CGFloat
        if let mouseDownPoint, let window {
            let pointer = window.convertPoint(toScreen: event.locationInWindow)
            pointerDistance = hypot(
                pointer.x - mouseDownPoint.x,
                pointer.y - mouseDownPoint.y
            )
        } else {
            pointerDistance = 0
        }

        // Some input paths coalesce intermediate mouseDragged events. The
        // release location is the final authority: movement never opens info.
        if didDrag || pointerDistance >= 3 {
            finishMovingWidget?()
        } else {
            openQuickMenu?()
        }
        interactionChanged?(false)
        mouseDownPoint = nil
        windowOriginAtMouseDown = nil
        didDrag = false
    }
}

struct FloatingWidgetGlass: ViewModifier {
    let settings: WidgetGlassSettings
    var isInteracting = false

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: CGFloat(settings.cornerRadius),
            style: .continuous
        )
        let interactionActive = settings.isInteractive && isInteracting
        // A full-strength black backing turns clear glass into a flat gray
        // card. Keep the tuner value as a subtle density contribution instead,
        // then reserve the noticeable darkening for active interaction.
        let idleBackingOpacity = settings.backingOpacity * 0.24
        let resolvedBackingOpacity = min(
            0.22,
            idleBackingOpacity + (interactionActive ? 0.07 : 0)
        )

        if #available(macOS 26.0, *) {
            let baseGlass: Glass = settings.variant == .clear ? .clear : .regular
            let tintLayer: Color = settings.tintOpacity > 0.001
                ? Color(
                    hue: settings.tintHue,
                    saturation: settings.tintSaturation,
                    brightness: 0.92,
                    opacity: settings.tintOpacity
                )
                : .clear

            content
                // Rebuild the glass surface when settings are applied. This
                // prevents the non-key floating panel from retaining a cached
                // idle appearance until its next pointer interaction.
                .id(settings)
                .padding(CGFloat(settings.padding))
                .environment(\.appearsActive, true)
                .glassEffect(
                    // Interaction is handled explicitly from AppKit mouse
                    // down/up events so idle glass remains the saved design.
                    baseGlass.interactive(false),
                    in: shape
                )
                // Native glass tints are desaturated when a floating panel is
                // not key. Keep the selected tint behind the glass so it stays
                // visible in the true idle state as well as while interacting.
                .background(tintLayer, in: shape)
                .background(.black.opacity(resolvedBackingOpacity), in: shape)
                .shadow(
                    color: .black.opacity(settings.shadowOpacity),
                    radius: settings.shadowRadius,
                    y: settings.shadowRadius * 0.35
                )
                .animation(.easeOut(duration: 0.14), value: interactionActive)
        } else {
            content
                .id(settings)
                .padding(CGFloat(settings.padding))
                .background(.ultraThinMaterial, in: shape)
                .background(.black.opacity(resolvedBackingOpacity), in: shape)
                .overlay {
                    shape.strokeBorder(.white.opacity(0.42), lineWidth: 0.8)
                }
                .animation(.easeOut(duration: 0.14), value: interactionActive)
        }
    }
}

struct QuickMenuView: View {
    @ObservedObject var controller: TimerController
    let openDashboard: () -> Void
    @State private var customMinutes = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.phase.rawValue).font(.headline)
                    Text(controller.sessionLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(controller.formattedTime)
                    .font(.title2.monospacedDigit().weight(.medium))
            }

            HStack(spacing: 10) {
                Button(controller.isRunning ? "Pause" : "Start") {
                    controller.toggleRunning()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Repeat") { controller.restartCurrent() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button("Skip") { controller.skip() }
                    .buttonStyle(.borderless)
            }

            Divider()

            HStack {
                Text("New focus")
                Spacer()
                Stepper("\(customMinutes) min", value: $customMinutes, in: 1...180, step: 5)
                    .labelsHidden()
                Text("\(customMinutes) min")
                    .frame(width: 48, alignment: .trailing)
                    .monospacedDigit()
            }

            Button("Start custom timer") { controller.startCustom(minutes: customMinutes) }
                .frame(maxWidth: .infinity)

            Divider()

            Button {
                openDashboard()
            } label: {
                Label("Open dashboard", systemImage: "rectangle.3.group")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 300)
    }
}
