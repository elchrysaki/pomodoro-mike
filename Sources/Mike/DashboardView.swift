import SwiftUI

struct DashboardView: View {
    @ObservedObject var controller: TimerController
    @ObservedObject var camera: CameraAttentionMonitor

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), .gray.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    HStack(alignment: .top, spacing: 22) {
                        liveTimer
                        cycleSettings
                    }
                    cameraGuard
                    GlassTuningView(controller: controller)
                    animationGallery
                }
                .padding(28)
            }
        }
        .frame(minWidth: 780, minHeight: 690)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mike").font(.largeTitle.weight(.semibold))
                Text("A tiny accountability buddy that lives on your Mac.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(
                text: controller.isRunning ? "Timer running" : "Ready",
                color: controller.isRunning ? .green : .secondary
            )
        }
    }

    private var liveTimer: some View {
        VStack(spacing: 14) {
            CharacterView(mood: controller.characterMood)
                .frame(height: 190)
            Text(controller.phase.rawValue.uppercased())
                .font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(.secondary)
            Text(controller.formattedTime)
                .font(.system(size: 52, weight: .medium, design: .rounded).monospacedDigit())
            ProgressView(value: controller.progress)
                .tint(controller.characterMood == .angry ? .red : .primary)
            HStack {
                Button(controller.isRunning ? "Pause" : "Start") { controller.toggleRunning() }
                    .buttonStyle(.borderedProminent)
                Button("Restart") { controller.restartCurrent() }
                    .buttonStyle(.bordered)
                Button("Skip") { controller.skip() }
                    .buttonStyle(.borderless)
            }
            Text(controller.sessionLabel).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var cycleSettings: some View {
        VStack(alignment: .leading, spacing: 17) {
            Label("Cycle", systemImage: "arrow.triangle.2.circlepath")
                .font(.title3.weight(.semibold))

            durationRow("Focus", value: $controller.plan.focusMinutes, range: 1...180)
            durationRow("Short break", value: $controller.plan.shortBreakMinutes, range: 1...60)
            durationRow("Long break", value: $controller.plan.longBreakMinutes, range: 1...90)

            HStack {
                Text("Sessions")
                Spacer()
                Stepper("\(controller.plan.sessionsBeforeLongBreak)", value: $controller.plan.sessionsBeforeLongBreak, in: 1...12)
                    .monospacedDigit()
            }

            Toggle("Repeat continuously", isOn: $controller.plan.repeatContinuously)

            Divider()
            Text("Example: \(controller.plan.sessionsBeforeLongBreak) × \(controller.plan.focusMinutes) min, with \(controller.plan.shortBreakMinutes) min breaks and a \(controller.plan.longBreakMinutes) min long break.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Apply & reset cycle") { controller.applyPlanAndReset() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: 300)
        .glassCard()
    }

    private var cameraGuard: some View {
        HStack(spacing: 18) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 34))
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 5) {
                Text("Phone guard (beta)").font(.headline)
                Text("Uses Apple Vision on-device. A hand-near-face posture held for 3 seconds triggers the red reminder. Frames are never saved or uploaded.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    StatusPill(
                        text: controller.attentionState.rawValue,
                        color: controller.attentionState == .distracted ? .orange : .green
                    )
                    Text(camera.authorizationText).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { controller.phoneGuardEnabled },
                set: { enabled in
                    controller.phoneGuardEnabled = enabled
                    enabled ? camera.start(for: controller) : camera.stop()
                }
            ))
            .labelsHidden()
        }
        .glassCard(cornerRadius: 20, padding: 18)
    }

    private var animationGallery: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Character states").font(.title3.weight(.semibold))
            HStack(spacing: 14) {
                galleryItem(.studying, "Studying")
                galleryItem(.peeking, "Checking in")
                galleryItem(.celebrating, "Bravo!")
                galleryItem(.angry, "Phone down")
            }
        }
        .glassCard()
    }

    private func galleryItem(_ mood: CharacterMood, _ label: String) -> some View {
        VStack(spacing: 4) {
            CharacterView(mood: mood, compact: true).frame(height: 112)
            Text(label).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    private func durationRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper("\(value.wrappedValue) min", value: value, in: range, step: 1)
                .monospacedDigit()
        }
    }
}

struct DistractionOverlayView: View {
    @ObservedObject var controller: TimerController
    @ObservedObject var camera: CameraAttentionMonitor

    var body: some View {
        VStack(spacing: 12) {
            CharacterView(mood: .angry)
            Text("Phone down.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
            Text("Your focus session is still waiting for you.")
                .foregroundStyle(.secondary)
            Text("This closes automatically when the phone-like posture is gone.")
                .font(.caption).foregroundStyle(.tertiary)
            Button("Pause phone guard") {
                controller.phoneGuardEnabled = false
                camera.stop()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(34)
        .frame(width: 440, height: 430)
        .background(.ultraThinMaterial)
    }
}
