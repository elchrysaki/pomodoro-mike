import SwiftUI

struct GlassTuningView: View {
    @ObservedObject var controller: TimerController
    @State private var draft: WidgetGlassSettings
    @State private var confirmationText = "Preview only"

    init(controller: TimerController) {
        self.controller = controller
        _draft = State(initialValue: controller.widgetGlassSettings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Glass Tuner", systemImage: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                    Text("Experiment here first. The floating widget changes only when you apply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: confirmationText, color: confirmationText == "Applied" ? .green : .orange)
            }

            HStack(alignment: .top, spacing: 22) {
                preview
                controls
            }

            HStack {
                Button("Revert preview") {
                    draft = controller.widgetGlassSettings
                    confirmationText = "Preview only"
                }
                .buttonStyle(.bordered)

                Button("Reset preview") {
                    draft = .default
                    confirmationText = "Preview only"
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Apply to widget") {
                    controller.widgetGlassSettings = draft
                    confirmationText = "Applied"
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .glassCard()
        .onChange(of: draft) { _, _ in
            confirmationText = draft == controller.widgetGlassSettings ? "Applied" : "Preview only"
        }
    }

    private var preview: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.75), .cyan.opacity(0.45), .orange.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.pink.opacity(0.72))
                .frame(width: 150)
                .offset(x: 115, y: -90)
            Circle()
                .fill(.blue.opacity(0.7))
                .frame(width: 125)
                .offset(x: -120, y: 100)

            VStack(spacing: 2) {
                CharacterView(mood: .studying, compact: true)
                    .frame(height: 125)
                Text("FOCUS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Text("45:00")
                    .font(.system(size: 29, weight: .medium, design: .rounded).monospacedDigit())
                ProgressView(value: 0.32)
                    .progressViewStyle(.linear)
                    .tint(.primary)
                    .frame(width: 118)
            }
            .frame(width: 176, height: 216)
            .modifier(FloatingWidgetGlass(settings: draft))
        }
        .frame(width: 335, height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 0.8)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 13) {
            Picker("Variant", selection: $draft.variant) {
                ForEach(WidgetGlassVariant.allCases, id: \.self) { variant in
                    Text(variant.rawValue).tag(variant)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Darken while clicking or dragging", isOn: $draft.isInteractive)

            slider("Corner radius", value: $draft.cornerRadius, range: 16...52, suffix: " pt")
            slider("Inner padding", value: $draft.padding, range: 4...20, suffix: " pt")
            slider("Tint strength", value: $draft.tintOpacity, range: 0...0.45, suffix: "%", percentage: true)
            slider("Tint hue", value: $draft.tintHue, range: 0...1, suffix: "°", degrees: true)
                .disabled(draft.tintOpacity < 0.01)
            slider("Tint saturation", value: $draft.tintSaturation, range: 0...1, suffix: "%", percentage: true)
                .disabled(draft.tintOpacity < 0.01)
            slider("Readability backing", value: $draft.backingOpacity, range: 0...0.35, suffix: "%", percentage: true)
            slider("Shadow strength", value: $draft.shadowOpacity, range: 0...0.4, suffix: "%", percentage: true)
            slider("Shadow radius", value: $draft.shadowRadius, range: 0...32, suffix: " pt")
        }
        .frame(maxWidth: .infinity)
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String,
        percentage: Bool = false,
        degrees: Bool = false
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(displayValue(value.wrappedValue, suffix: suffix, percentage: percentage, degrees: degrees))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func displayValue(
        _ value: Double,
        suffix: String,
        percentage: Bool,
        degrees: Bool
    ) -> String {
        if percentage { return "\(Int((value * 100).rounded()))\(suffix)" }
        if degrees { return "\(Int((value * 360).rounded()))\(suffix)" }
        return "\(Int(value.rounded()))\(suffix)"
    }
}
