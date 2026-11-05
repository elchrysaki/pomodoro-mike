import Foundation

enum TimerPhase: String, Codable, CaseIterable, Sendable {
    case focus = "Focus"
    case shortBreak = "Short break"
    case longBreak = "Long break"

    var isBreak: Bool { self != .focus }
}

enum CharacterMood: String, CaseIterable, Sendable {
    case studying
    case peeking
    case celebrating
    case angry
}

enum AttentionState: String, Sendable {
    case unavailable = "Camera off"
    case focused = "Looking at screen"
    case reading = "Reading"
    case distracted = "Phone-like posture"
}

enum WidgetGlassVariant: String, Codable, CaseIterable, Sendable, Hashable {
    case clear = "Clear"
    case regular = "Regular"
}

struct WidgetGlassSettings: Codable, Equatable, Sendable, Hashable {
    var variant: WidgetGlassVariant = .clear
    var tintHue: Double = 0.58
    var tintSaturation: Double = 0.55
    var tintOpacity: Double = 0
    var backingOpacity: Double = 0
    var cornerRadius: Double = 30
    var padding: Double = 8
    var shadowOpacity: Double = 0
    var shadowRadius: Double = 18
    var isInteractive = true

    static let `default` = WidgetGlassSettings()
}

struct TimerPlan: Codable, Equatable, Sendable {
    var focusMinutes: Int = 45
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var sessionsBeforeLongBreak: Int = 4
    var repeatContinuously: Bool = true

    static let `default` = TimerPlan()

    func duration(for phase: TimerPhase) -> TimeInterval {
        let minutes: Int
        switch phase {
        case .focus: minutes = focusMinutes
        case .shortBreak: minutes = shortBreakMinutes
        case .longBreak: minutes = longBreakMinutes
        }
        return TimeInterval(max(1, minutes) * 60)
    }
}

struct TimerSnapshot: Equatable, Sendable {
    var phase: TimerPhase
    var remaining: TimeInterval
    var completedFocusSessions: Int
}

enum TimerSequence {
    static func next(
        after snapshot: TimerSnapshot,
        plan: TimerPlan
    ) -> TimerSnapshot? {
        switch snapshot.phase {
        case .focus:
            let completed = snapshot.completedFocusSessions + 1
            let isLongBreak = completed % max(1, plan.sessionsBeforeLongBreak) == 0
            let nextPhase: TimerPhase = isLongBreak ? .longBreak : .shortBreak
            return TimerSnapshot(
                phase: nextPhase,
                remaining: plan.duration(for: nextPhase),
                completedFocusSessions: completed
            )
        case .shortBreak, .longBreak:
            if !plan.repeatContinuously,
               snapshot.completedFocusSessions >= max(1, plan.sessionsBeforeLongBreak) {
                return nil
            }
            return TimerSnapshot(
                phase: .focus,
                remaining: plan.duration(for: .focus),
                completedFocusSessions: snapshot.completedFocusSessions
            )
        }
    }
}
