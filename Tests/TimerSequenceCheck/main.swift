import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
}

let plan = TimerPlan.default

let firstBreak = TimerSequence.next(
    after: TimerSnapshot(phase: .focus, remaining: 0, completedFocusSessions: 0),
    plan: plan
)
check(firstBreak?.phase == .shortBreak, "first focus should lead to a short break")
check(firstBreak?.remaining == 300, "short break should use the configured five minutes")

let fourthBreak = TimerSequence.next(
    after: TimerSnapshot(phase: .focus, remaining: 0, completedFocusSessions: 3),
    plan: plan
)
check(fourthBreak?.phase == .longBreak, "fourth focus should lead to a long break")
check(fourthBreak?.remaining == 900, "long break should use the configured fifteen minutes")

var finitePlan = plan
finitePlan.repeatContinuously = false
let stopped = TimerSequence.next(
    after: TimerSnapshot(phase: .longBreak, remaining: 0, completedFocusSessions: 4),
    plan: finitePlan
)
check(stopped == nil, "finite cycle should stop after its long break")

let repeated = TimerSequence.next(
    after: TimerSnapshot(phase: .longBreak, remaining: 0, completedFocusSessions: 4),
    plan: plan
)
check(repeated?.phase == .focus, "continuous cycle should return to focus")
check(repeated?.remaining == 2_700, "repeated focus should use the configured duration")

print("Timer sequence checks passed")
