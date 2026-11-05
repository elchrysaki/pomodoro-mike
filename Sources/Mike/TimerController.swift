import AppKit
import Combine
import Foundation

@MainActor
final class TimerController: ObservableObject {
    @Published private(set) var phase: TimerPhase = .focus
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning = false
    @Published private(set) var completedFocusSessions = 0
    @Published var plan: TimerPlan {
        didSet { persistPlan() }
    }
    @Published var phoneGuardEnabled: Bool {
        didSet { UserDefaults.standard.set(phoneGuardEnabled, forKey: Keys.phoneGuardEnabled) }
    }
    @Published var widgetGlassSettings: WidgetGlassSettings {
        didSet { persistWidgetGlassSettings() }
    }
    @Published var attentionState: AttentionState = .unavailable
    @Published var isDistractionAlertPresented = false
    @Published var isQuickMenuPresented = false

    private var ticker: Timer?
    private var targetDate: Date?
    private var lastStartedDuration: TimeInterval
    private let sound = NSSound(named: "Glass")

    init() {
        let loadedPlan: TimerPlan
        if let data = UserDefaults.standard.data(forKey: Keys.plan),
           let saved = try? JSONDecoder().decode(TimerPlan.self, from: data) {
            loadedPlan = saved
        } else {
            loadedPlan = .default
        }
        let initialDuration = loadedPlan.duration(for: .focus)
        let loadedGlassSettings: WidgetGlassSettings
        if let data = UserDefaults.standard.data(forKey: Keys.widgetGlassSettings),
           let saved = try? JSONDecoder().decode(WidgetGlassSettings.self, from: data) {
            loadedGlassSettings = saved
        } else {
            loadedGlassSettings = .default
        }
        plan = loadedPlan
        widgetGlassSettings = loadedGlassSettings
        phoneGuardEnabled = UserDefaults.standard.bool(forKey: Keys.phoneGuardEnabled)
        remaining = initialDuration
        lastStartedDuration = initialDuration
    }

    var progress: Double {
        guard lastStartedDuration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / lastStartedDuration))
    }

    var formattedTime: String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var sessionLabel: String {
        let total = max(1, plan.sessionsBeforeLongBreak)
        let current = min(total, completedFocusSessions % total + 1)
        return "Session \(current) of \(total)"
    }

    var characterMood: CharacterMood {
        if isDistractionAlertPresented { return .angry }
        if phase.isBreak { return .celebrating }
        if !isRunning { return .peeking }
        return .studying
    }

    func toggleRunning() {
        isRunning ? pause() : start()
    }

    func start() {
        guard remaining > 0 else { restartCurrent() ; return }
        isRunning = true
        targetDate = Date().addingTimeInterval(remaining)
        installTicker()
    }

    func pause() {
        updateRemainingFromTarget()
        isRunning = false
        ticker?.invalidate()
        ticker = nil
        targetDate = nil
    }

    func restartCurrent() {
        pause()
        remaining = plan.duration(for: phase)
        lastStartedDuration = remaining
        start()
    }

    func startCustom(minutes: Int) {
        pause()
        phase = .focus
        remaining = TimeInterval(max(1, minutes) * 60)
        lastStartedDuration = remaining
        start()
    }

    func skip() {
        advance()
    }

    func applyPlanAndReset() {
        pause()
        phase = .focus
        completedFocusSessions = 0
        remaining = plan.duration(for: .focus)
        lastStartedDuration = remaining
    }

    func updateAttention(_ state: AttentionState, phoneHeld: Bool) {
        attentionState = state
        guard phoneGuardEnabled else {
            isDistractionAlertPresented = false
            return
        }
        isDistractionAlertPresented = phoneHeld
    }

    private func installTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(ticker!, forMode: .common)
    }

    private func tick() {
        updateRemainingFromTarget()
        if remaining <= 0 {
            sound?.stop()
            sound?.play()
            advance()
        }
    }

    private func updateRemainingFromTarget() {
        guard let targetDate else { return }
        remaining = max(0, targetDate.timeIntervalSinceNow)
    }

    private func advance() {
        ticker?.invalidate()
        ticker = nil
        targetDate = nil

        let current = TimerSnapshot(
            phase: phase,
            remaining: remaining,
            completedFocusSessions: completedFocusSessions
        )
        guard let next = TimerSequence.next(after: current, plan: plan) else {
            isRunning = false
            remaining = 0
            return
        }
        phase = next.phase
        remaining = next.remaining
        completedFocusSessions = next.completedFocusSessions
        lastStartedDuration = remaining
        isRunning = true
        targetDate = Date().addingTimeInterval(remaining)
        installTicker()
    }

    private func persistPlan() {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: Keys.plan)
        }
    }

    private func persistWidgetGlassSettings() {
        if let data = try? JSONEncoder().encode(widgetGlassSettings) {
            UserDefaults.standard.set(data, forKey: Keys.widgetGlassSettings)
        }
    }

    private enum Keys {
        static let plan = "timerPlan"
        static let phoneGuardEnabled = "phoneGuardEnabled"
        static let widgetGlassSettings = "widgetGlassSettings"
    }
}
