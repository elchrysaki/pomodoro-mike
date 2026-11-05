import SwiftUI

struct CharacterView: View {
    let mood: CharacterMood
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var cycleStart = Date()

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion
                    ? 1.0 / 8.0
                    : (compact ? 1.0 / 18.0 : 1.0 / 24.0),
                paused: reduceMotion && mood != .celebrating
            )
        ) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let elapsed = reduceMotion && mood != .celebrating
                    ? stablePoseTime(for: mood)
                    : max(0, timeline.date.timeIntervalSince(cycleStart))
                draw(mood, elapsed: elapsed, in: size, context: &context)
            }
        }
        .frame(width: compact ? 124 : 210, height: compact ? 118 : 190)
        .onAppear { cycleStart = Date() }
        .onChange(of: mood) { _, _ in cycleStart = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var ink: Color { colorScheme == .dark ? .white : .black }
    private var alertInk: Color { .red }
    private var lineWidth: CGFloat {
        if mood == .studying || mood == .celebrating {
            return compact ? 2.2 : 3.1
        }
        return compact ? 3 : 4
    }

    // MARK: - State renderer

    private func draw(
        _ mood: CharacterMood,
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        switch mood {
        case .studying:
            drawStudying(elapsed: elapsed, in: size, context: &context)
        case .peeking:
            drawPeeking(elapsed: elapsed, in: size, context: &context)
        case .celebrating:
            drawCelebrating(elapsed: elapsed, in: size, context: &context)
        case .angry:
            drawAngry(elapsed: elapsed, in: size, context: &context)
        }
    }

    // The approved coffee and phone stories remain unchanged. Microsleep is a
    // separate 18-second story whose first and last frames use their neutral
    // pose, so it can occasionally join the studying sequence without a cut.
    private func drawStudying(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let coffeeDuration = 18.0
        let phoneDuration = 23.0
        let microsleepDuration = 18.0
        let sequenceTime = elapsed.truncatingRemainder(
            dividingBy: coffeeDuration + phoneDuration + microsleepDuration
        )
        if sequenceTime < coffeeDuration {
            drawCoffeeStudy(elapsed: sequenceTime, in: size, context: &context)
        } else if sequenceTime < coffeeDuration + phoneDuration {
            drawPhoneStudy(
                elapsed: sequenceTime - coffeeDuration,
                in: size,
                context: &context
            )
        } else {
            drawMicrosleepStudy(
                elapsed: sequenceTime - coffeeDuration - phoneDuration,
                in: size,
                context: &context
            )
        }
    }

    // Coffee routine: three continuous six-second clips. The master skeleton,
    // head circle, chair, desk, and laptop remain fixed throughout the loop.
    private func drawCoffeeStudy(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let loopDuration = 18.0
        let t = elapsed.truncatingRemainder(dividingBy: loopDuration)

        // Clip 1 types only from 2-4 s; Clip 3 types only from 14-16 s.
        let typingAmount = max(
            eventWindow(t, start: 2.0, end: 4.0, attack: 0.18, release: 0.18),
            eventWindow(t, start: 14.0, end: 16.0, attack: 0.18, release: 0.18)
        )
        let typing = CGFloat(sin(t * .pi * 3.0)) * typingAmount

        // Clip 2: reach 6-8 s, raise/hold 8-10 s, replace 10-12 s.
        let armAtMug = easedProgress(t, start: 6.0, duration: 1.8)
            * (1 - easedProgress(t, start: 11.25, duration: 2.5))
        func liftAmount(at time: TimeInterval) -> CGFloat {
            easedProgress(time, start: 8.0, duration: 1.15)
                * (1 - easedProgress(time, start: 10.0, duration: 1.25))
        }
        let mugLift = liftAmount(at: t)
        let previousTime = t >= 0.05 ? t - 0.05 : t + loopDuration - 0.05
        let mugVelocity = max(
            CGFloat(-1.5),
            min(CGFloat(1.5), (mugLift - liftAmount(at: previousTime)) / 0.05)
        )
        let headAdjustment = eventWindow(
            t,
            start: 12.0,
            end: 14.2,
            attack: 1.2,
            release: 0.8
        )

        drawStudyChair(&context, in: size)
        strokeLine(&context, from: point(0.50, 0.60, in: size), to: point(0.96, 0.60, in: size))
        strokeLine(&context, from: point(0.80, 0.60, in: size), to: point(0.80, 0.96, in: size))
        drawStudyLaptop(&context, in: size)

        let headRadius = size.width * 0.10
        let headCenter = point(
            0.40 + headAdjustment * 0.006,
            0.19 - headAdjustment * 0.004,
            in: size
        )
        let neck = CGPoint(x: headCenter.x, y: headCenter.y + headRadius * 0.92)
        let shoulder = point(0.35, 0.32, in: size)
        let hip = point(0.20, 0.69, in: size)

        drawStudyHead(
            &context,
            center: headCenter,
            radius: headRadius,
            gaze: mugLift > 0.05 ? 0.45 : 0.22
        )
        strokeLine(&context, from: neck, to: shoulder)
        strokeCurve(
            &context,
            from: shoulder,
            control: point(0.27, 0.49, in: size),
            to: hip
        )

        let restMugCenter = point(0.71, 0.545, in: size)
        let raisedMugCenter = point(0.56, 0.32, in: size)
        let mugCenter = interpolate(
            from: restMugCenter,
            to: raisedMugCenter,
            amount: mugLift
        )
        let mugAngle = CGFloat(-12.0 * .pi / 180.0) * mugLift
        let handleOffsetX = -size.width * 0.062
        let mugHandle = CGPoint(
            x: mugCenter.x + cos(mugAngle) * handleOffsetX,
            y: mugCenter.y + sin(mugAngle) * handleOffsetX
        )

        let keyboardHand = point(0.60, 0.545 + typing * 0.016, in: size)
        let nearHand = interpolate(from: keyboardHand, to: mugHandle, amount: armAtMug)
        let nearElbow = armElbow(
            shoulder: shoulder,
            hand: nearHand,
            upperLength: size.width * 0.18,
            lowerLength: size.width * 0.18
        )
        strokeLine(&context, from: shoulder, to: nearElbow)
        strokeLine(&context, from: nearElbow, to: nearHand)

        let farShoulder = point(0.36, 0.34, in: size)
        let farHand = point(0.67, 0.53 - typing * 0.014, in: size)
        let farElbow = armElbow(
            shoulder: farShoulder,
            hand: farHand,
            upperLength: size.width * 0.19,
            lowerLength: size.width * 0.19
        )
        strokeLine(&context, from: farShoulder, to: farElbow)
        strokeLine(&context, from: farElbow, to: farHand)

        let leftKnee = point(0.43, 0.72, in: size)
        let rightKnee = point(0.53, 0.65, in: size)
        strokeLine(&context, from: hip, to: leftKnee)
        strokeLine(&context, from: leftKnee, to: point(0.47, 0.94, in: size))
        strokeLine(&context, from: point(0.47, 0.94, in: size), to: point(0.53, 0.94, in: size))
        strokeLine(&context, from: hip, to: rightKnee)
        strokeLine(&context, from: rightKnee, to: point(0.62, 0.92, in: size))
        strokeLine(&context, from: point(0.62, 0.92, in: size), to: point(0.70, 0.92, in: size))

        drawCoffeeMug(
            &context,
            center: mugCenter,
            lean: mugLift,
            liftVelocity: mugVelocity,
            steamPhase: t,
            in: size
        )
        // The phone remains flat in front of the mug throughout Coffee so the
        // shared neutral frame matches the following Phone story exactly.
        drawPhone(
            &context,
            center: point(0.60, 0.575, in: size),
            angle: -CGFloat.pi / 2,
            in: size
        )
    }

    // Phone routine: Mike collects the tabletop phone, scrolls with his free
    // hand while reclining against the chair, then settles into the exact
    // neutral study pose again. Every transition uses eased progress so the
    // fixed-length limbs remain connected without frame-to-frame jumps.
    private func drawPhoneStudy(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let loopDuration = 23.0
        let t = elapsed.truncatingRemainder(dividingBy: loopDuration)

        // Study at the beginning and end so the 23-second loop closes cleanly.
        let typingAmount = max(
            eventWindow(t, start: 0.0, end: 2.0, attack: 0.18, release: 0.18),
            eventWindow(t, start: 20.4, end: 22.35, attack: 0.18, release: 0.18)
        )
        let typing = CGFloat(sin(t * .pi * 3.0)) * typingAmount

        let notification = eventWindow(t, start: 2.0, end: 3.4, attack: 0.08, release: 0.16)
        let vibration = eventWindow(t, start: 2.0, end: 3.7, attack: 0.08, release: 0.12)
        let downwardTilt = eventWindow(t, start: 3.0, end: 4.55, attack: 0.45, release: 0.45)

        // 4-6.65 s: reach, tilt and fully lift the phone. Only after it clears
        // the table does Mike recline. 7-12 s: five full seconds of two-handed
        // scrolling. 12-16 s: four more seconds reclined. The
        // torso begins moving forward as the phone lowers, keeping both arm
        // spans natural before the neutral typing pose resumes.
        let phoneArmEngaged = easedProgress(t, start: 3.85, duration: 1.45)
            * (1 - easedProgress(t, start: 18.4, duration: 1.6))
        let phoneLift = easedProgress(t, start: 5.25, duration: 1.4)
            * (1 - easedProgress(t, start: 16.0, duration: 2.0))
        let freeArmEngaged = easedProgress(t, start: 6.65, duration: 0.9)
            * (1 - easedProgress(t, start: 15.7, duration: 1.4))
        // Weight begins transferring into the chair after the phone clears the
        // table. The head follows the shoulders by a fraction of a second,
        // creating a soft secondary motion instead of one rigid translation.
        let recline = easedProgress(t, start: 6.65, duration: 1.15)
            * (1 - easedProgress(t, start: 15.95, duration: 2.25))
        let headRecline = easedProgress(t, start: 6.80, duration: 1.20)
            * (1 - easedProgress(t, start: 16.05, duration: 2.1))
        let checkingPhone = eventWindow(t, start: 6.45, end: 18.0, attack: 0.25, release: 0.75)
        let scrolling = eventWindow(t, start: 7.0, end: 16.0, attack: 0.3, release: 0.35)
        // Feed symbols wait until the 6.65-7.8 s recline is fully complete.
        let feedSymbols = eventWindow(t, start: 7.90, end: 16.0, attack: 0.35, release: 0.35)
        // Roughly one complete finger cycle every 2.7 seconds. The slower
        // cadence reads as deliberate reading rather than rapid tapping.
        let scrollWave = CGFloat(sin((t - 7.0) * .pi * 0.75)) * scrolling
        let readingNod = smoothPulse(t, start: 12.6, duration: 1.7)

        // Trace the icon's curved chair, short desktop, single table leg,
        // and angled laptop rather than introducing a different desk scene.
        drawStudyChair(&context, in: size)
        strokeLine(&context, from: point(0.50, 0.60, in: size), to: point(0.96, 0.60, in: size))
        strokeLine(&context, from: point(0.80, 0.60, in: size), to: point(0.80, 0.96, in: size))
        drawStudyLaptop(&context, in: size)

        let hip = point(0.20, 0.69, in: size)
        let headRadius = size.width * 0.10

        // Rigid-body recline: preserve the original shoulder-to-hip length and
        // rotate it until the back is parallel to the chair. This prevents the
        // torso from shrinking when Mike settles into the backrest.
        let baseShoulder = point(0.35, 0.32, in: size)
        // Aim a few points in front of the visible chair edge. The torso stays
        // parallel to the backrest without drawing through or hiding it.
        let supportedBackPoint = point(0.15, 0.42, in: size)
        let torsoDX = baseShoulder.x - hip.x
        let torsoDY = baseShoulder.y - hip.y
        let torsoLength = sqrt(torsoDX * torsoDX + torsoDY * torsoDY)
        let baseTorsoAngle = atan2(torsoDY, torsoDX)
        let chairTorsoAngle = atan2(
            supportedBackPoint.y - hip.y,
            supportedBackPoint.x - hip.x
        )
        let torsoAngle = baseTorsoAngle + (chairTorsoAngle - baseTorsoAngle) * recline
        let shoulder = CGPoint(
            x: hip.x + cos(torsoAngle) * torsoLength,
            y: hip.y + sin(torsoAngle) * torsoLength
        )

        // The neck has one constant length. Its angle changes slightly toward
        // the phone, but its anchor always travels with the rotating torso.
        let neutralHeadCenter = point(0.40, 0.19, in: size)
        let neutralNeckAnchor = CGPoint(
            x: neutralHeadCenter.x,
            y: neutralHeadCenter.y + headRadius * 0.92
        )
        let neutralNeckDX = neutralNeckAnchor.x - baseShoulder.x
        let neutralNeckDY = neutralNeckAnchor.y - baseShoulder.y
        let neckLength = sqrt(neutralNeckDX * neutralNeckDX + neutralNeckDY * neutralNeckDY)
        let neutralNeckAngle = atan2(neutralNeckDY, neutralNeckDX)
        let neckAngle = neutralNeckAngle
            + headRecline * 0.06
            + downwardTilt * 0.035
            + readingNod * 0.025
        let neck = CGPoint(
            x: shoulder.x + cos(neckAngle) * neckLength,
            y: shoulder.y + sin(neckAngle) * neckLength
        )
        let headCenter = CGPoint(
            x: neck.x,
            y: neck.y - headRadius * 0.92
        )

        drawStudyHead(
            &context,
            center: headCenter,
            radius: headRadius,
            gaze: checkingPhone > 0.05 ? 0.62 : 0.22,
            gazeY: checkingPhone * (0.18 + scrollWave * 0.15)
        )
        strokeLine(&context, from: neck, to: shoulder)
        let torsoMidpoint = interpolate(from: shoulder, to: hip, amount: 0.5)
        strokeCurve(
            &context,
            from: shoulder,
            control: offset(
                torsoMidpoint,
                x: -size.width * 0.005 * (1 - recline),
                y: -size.height * 0.015 * (1 - recline)
            ),
            to: hip
        )

        let mugCenter = point(0.71, 0.545, in: size)
        let tablePhoneCenter = point(0.60, 0.575, in: size)
        let raisedPhoneCenter = point(
            0.54 - recline * 0.16,
            0.32 - recline * 0.03,
            in: size
        )
        let vibrationWave = CGFloat(sin(t * .pi * 12.0)) * vibration
        let phoneShake = vibrationWave * size.width * 0.014
        let phoneWobble = vibrationWave * 0.10
        var phoneCenter = interpolate(
            from: tablePhoneCenter,
            to: raisedPhoneCenter,
            amount: phoneLift
        )
        phoneCenter.x += phoneShake * (1 - phoneLift)
        let phoneAngle = -CGFloat.pi / 2
            + phoneLift * (CGFloat.pi / 2 - 0.10)
            + phoneWobble * (1 - phoneLift)
        let gripOffsetX = -size.width * 0.027
        let gripOffsetY = size.height * 0.025
        let phoneGrip = CGPoint(
            x: phoneCenter.x
                + cos(phoneAngle) * gripOffsetX
                - sin(phoneAngle) * gripOffsetY,
            y: phoneCenter.y
                + sin(phoneAngle) * gripOffsetX
                + cos(phoneAngle) * gripOffsetY
        )

        // The arm endpoint follows the phone; no hand, palm, or fingers appear.
        let keyboardHand = point(0.60, 0.545 + typing * 0.016, in: size)
        let nearHand = interpolate(from: keyboardHand, to: phoneGrip, amount: phoneArmEngaged)
        let nearElbow = armElbow(
            shoulder: shoulder,
            hand: nearHand,
            upperLength: size.width * 0.18,
            lowerLength: size.width * 0.18
        )
        strokeLine(&context, from: shoulder, to: nearElbow)
        strokeLine(&context, from: nearElbow, to: nearHand)

        // The opposite arm leaves the keyboard and its endpoint travels up and
        // down the phone face. This is the readable scrolling gesture; the
        // phone itself remains steady in the holding arm.
        let farShoulder = offset(
            shoulder,
            x: size.width * 0.010,
            y: size.height * 0.020
        )
        let farKeyboardHand = point(0.67, 0.53 - typing * 0.014, in: size)
        let scrollTouch = CGPoint(
            x: phoneCenter.x + size.width * 0.018,
            y: phoneCenter.y - size.height * 0.020 + scrollWave * size.height * 0.020
        )
        let farHand = interpolate(
            from: farKeyboardHand,
            to: scrollTouch,
            amount: freeArmEngaged
        )
        let farElbow = armElbow(
            shoulder: farShoulder,
            hand: farHand,
            upperLength: size.width * 0.19,
            lowerLength: size.width * 0.19
        )
        strokeLine(&context, from: farShoulder, to: farElbow)
        strokeLine(&context, from: farElbow, to: farHand)

        // Seated legs remain planted beneath the desk.
        let leftKnee = point(0.43, 0.72, in: size)
        let rightKnee = point(0.53, 0.65, in: size)
        strokeLine(&context, from: hip, to: leftKnee)
        strokeLine(&context, from: leftKnee, to: point(0.47, 0.94, in: size))
        strokeLine(&context, from: point(0.47, 0.94, in: size), to: point(0.53, 0.94, in: size))
        strokeLine(&context, from: hip, to: rightKnee)
        strokeLine(&context, from: rightKnee, to: point(0.62, 0.92, in: size))
        strokeLine(&context, from: point(0.62, 0.92, in: size), to: point(0.70, 0.92, in: size))

        // The phone sits nearer Mike than the mug, so the mug is painted first
        // and the flat phone remains visually distinct in the foreground.
        drawCoffeeMug(
            &context,
            center: mugCenter,
            lean: 0,
            liftVelocity: 0,
            steamPhase: t,
            in: size
        )
        if notification > 0.01 {
            drawPhoneNotification(
                &context,
                center: tablePhoneCenter,
                amount: notification * (0.82 + abs(vibrationWave) * 0.18),
                in: size
            )
        }
        drawPhone(&context, center: phoneCenter, angle: phoneAngle, in: size)
        if feedSymbols > 0.01 {
            drawPhoneFeedSymbols(
                &context,
                origin: phoneCenter,
                elapsed: t - 7.90,
                amount: feedSymbols,
                in: size
            )
        }
    }

    // Microsleep: three continuous six-second clips. Mike grows tired, rests
    // his head on the line endpoint of one arm, sleeps for four quiet seconds,
    // then calmly recovers. The mug remains completely still in this story.
    private func drawMicrosleepStudy(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let loopDuration = 18.0
        let t = elapsed.truncatingRemainder(dividingBy: loopDuration)

        // Clip 1 (0-6 s): type, pause, then ease into the supported-head pose.
        // Clip 3 (16-17 s): a few quiet keystrokes after Mike straightens.
        let typingAmount = max(
            eventWindow(t, start: 0.0, end: 2.0, attack: 0.18, release: 0.22),
            eventWindow(t, start: 16.0, end: 17.0, attack: 0.18, release: 0.22)
        )
        let typing = CGFloat(sin(t * .pi * 3.0)) * typingAmount

        let slouch = easedProgress(t, start: 2.0, duration: 2.0)
            * (1 - easedProgress(t, start: 13.4, duration: 2.1))
        let headSupport = easedProgress(t, start: 4.0, duration: 2.0)
            * (1 - easedProgress(t, start: 13.4, duration: 2.1))

        // Clip 2 (6-12 s): two seconds of progressive eye closure lead into
        // a stable four-second sleep. The Zs fade in and drift slowly while the
        // head stays supported, then disappear as the eyes reopen at 12 s.
        let drowsiness = easedProgress(t, start: 6.0, duration: 2.0)
            * (1 - easedProgress(t, start: 12.0, duration: 1.0))
        let eyeClosure = easedProgress(t, start: 6.8, duration: 1.2)
            * (1 - easedProgress(t, start: 12.0, duration: 0.7))
        let sleeping = eventWindow(
            t,
            start: 8.0,
            end: 12.0,
            attack: 0.45,
            release: 0.55
        )
        let wakeLift = smoothPulse(t, start: 12.0, duration: 1.4)

        drawStudyChair(&context, in: size)
        strokeLine(&context, from: point(0.50, 0.60, in: size), to: point(0.96, 0.60, in: size))
        strokeLine(&context, from: point(0.80, 0.60, in: size), to: point(0.80, 0.96, in: size))
        drawStudyLaptop(&context, in: size)

        let hip = point(0.20, 0.69, in: size)
        let headRadius = size.width * 0.10
        let neutralShoulder = point(0.35, 0.32, in: size)
        let tiredShoulder = point(0.37, 0.355, in: size)
        let shoulder = interpolate(
            from: neutralShoulder,
            to: tiredShoulder,
            amount: slouch
        )

        let neutralHeadCenter = point(0.40, 0.19, in: size)
        let supportedHeadCenter = point(0.46, 0.285, in: size)
        var headCenter = interpolate(
            from: neutralHeadCenter,
            to: supportedHeadCenter,
            amount: headSupport
        )
        headCenter.x -= drowsiness * size.width * 0.004
        headCenter.y += drowsiness * size.height * 0.014
        headCenter.y -= wakeLift * size.height * 0.006

        let neck = CGPoint(
            x: headCenter.x,
            y: headCenter.y + headRadius * 0.92
        )
        drawStudyHead(
            &context,
            center: headCenter,
            radius: headRadius,
            gaze: 0.22,
            gazeY: drowsiness * 0.10,
            eyeClosure: eyeClosure
        )
        strokeLine(&context, from: neck, to: shoulder)
        strokeCurve(
            &context,
            from: shoulder,
            control: point(0.28, 0.50, in: size),
            to: hip
        )

        // The arm endpoint is the same hand treatment used by the master: a
        // bare rounded line end, with no palm or fingers added for head support.
        let keyboardHand = point(0.60, 0.545 + typing * 0.016, in: size)
        let headRestPoint = CGPoint(
            x: headCenter.x + headRadius * 0.68,
            y: headCenter.y + headRadius * 0.48
        )
        let nearHand = interpolate(
            from: keyboardHand,
            to: headRestPoint,
            amount: headSupport
        )
        let keyboardElbow = armElbow(
            shoulder: shoulder,
            hand: keyboardHand,
            upperLength: size.width * 0.18,
            lowerLength: size.width * 0.18
        )
        let restingElbow = point(0.585, 0.55, in: size)
        let nearElbow = interpolate(
            from: keyboardElbow,
            to: restingElbow,
            amount: headSupport
        )
        strokeLine(&context, from: shoulder, to: nearElbow)
        strokeLine(&context, from: nearElbow, to: nearHand)

        let farShoulder = offset(
            shoulder,
            x: size.width * 0.010,
            y: size.height * 0.020
        )
        let farHand = point(0.67, 0.53 - typing * 0.014, in: size)
        let farElbow = armElbow(
            shoulder: farShoulder,
            hand: farHand,
            upperLength: size.width * 0.19,
            lowerLength: size.width * 0.19
        )
        strokeLine(&context, from: farShoulder, to: farElbow)
        strokeLine(&context, from: farElbow, to: farHand)

        // Seated legs stay planted exactly as they do in both master stories.
        let leftKnee = point(0.43, 0.72, in: size)
        let rightKnee = point(0.53, 0.65, in: size)
        strokeLine(&context, from: hip, to: leftKnee)
        strokeLine(&context, from: leftKnee, to: point(0.47, 0.94, in: size))
        strokeLine(&context, from: point(0.47, 0.94, in: size), to: point(0.53, 0.94, in: size))
        strokeLine(&context, from: hip, to: rightKnee)
        strokeLine(&context, from: rightKnee, to: point(0.62, 0.92, in: size))
        strokeLine(&context, from: point(0.62, 0.92, in: size), to: point(0.70, 0.92, in: size))

        drawCoffeeMug(
            &context,
            center: point(0.71, 0.545, in: size),
            lean: 0,
            liftVelocity: 0,
            steamPhase: t,
            in: size
        )
        drawPhone(
            &context,
            center: point(0.60, 0.575, in: size),
            angle: -CGFloat.pi / 2,
            in: size
        )
        if sleeping > 0.01 {
            drawSleepingMarks(
                &context,
                origin: headCenter,
                sleepTime: t - 8.0,
                amount: sleeping,
                in: size
            )
        }
    }

    // A 5.4-second check-in: ease out from behind the door, blink once, wave,
    // then ease back. The torso, hand, and feet share the same horizontal shift.
    private func drawPeeking(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let t = elapsed.truncatingRemainder(dividingBy: 5.4)
        let reveal = 0.5 - 0.5 * CGFloat(cos(t / 5.4 * .pi * 2.0))
        let shift = reveal * size.width * 0.045
        let wave = CGFloat(sin(t * .pi * 2.2)) * reveal
        let blink = smoothPulse(t, start: 2.35, duration: 0.2)

        let frameRect = rect(0.12, 0.06, 0.28, 0.89, in: size)
        strokeRoundedRect(&context, rect: frameRect, radius: compact ? 4 : 6)
        strokeLine(&context, from: point(0.40, 0.06, in: size), to: point(0.40, 0.96, in: size))
        fillCircle(&context, center: point(0.33, 0.52, in: size), radius: lineWidth * 0.85)

        let head = offset(point(0.50, 0.27, in: size), x: shift)
        let neck = offset(point(0.48, 0.39, in: size), x: shift)
        let shoulder = offset(point(0.475, 0.45, in: size), x: shift)
        let hip = offset(point(0.475, 0.66, in: size), x: shift)
        drawHead(&context, center: head, radius: size.width * 0.092, blink: blink)
        strokeLine(&context, from: offset(point(0.49, 0.36, in: size), x: shift), to: neck)
        strokeCurve(&context, from: neck, control: offset(point(0.45, 0.52, in: size), x: shift), to: hip)

        let holdingHand = point(0.385, 0.54, in: size)
        strokeLine(&context, from: shoulder, to: offset(point(0.43, 0.49, in: size), x: shift * 0.45))
        strokeLine(&context, from: offset(point(0.43, 0.49, in: size), x: shift * 0.45), to: holdingHand)

        let wavingElbow = offset(point(0.57, 0.49, in: size), x: shift)
        let wavingHand = offset(point(0.62 + wave * 0.018, 0.40 - abs(wave) * 0.025, in: size), x: shift)
        strokeLine(&context, from: shoulder, to: wavingElbow)
        strokeLine(&context, from: wavingElbow, to: wavingHand)

        let leftKnee = offset(point(0.42, 0.79, in: size), x: shift)
        let rightKnee = offset(point(0.54, 0.79, in: size), x: shift)
        strokeLine(&context, from: hip, to: leftKnee)
        strokeLine(&context, from: leftKnee, to: offset(point(0.39, 0.92, in: size), x: shift))
        strokeLine(&context, from: hip, to: rightKnee)
        strokeLine(&context, from: rightKnee, to: offset(point(0.59, 0.92, in: size), x: shift))
    }

    private struct CelebrationPose {
        var head: CGPoint
        var shoulder: CGPoint
        var hip: CGPoint
        var nearElbow: CGPoint
        var nearHand: CGPoint
        var farShoulder: CGPoint
        var farElbow: CGPoint
        var farHand: CGPoint
        var leftKnee: CGPoint
        var leftAnkle: CGPoint
        var leftToe: CGPoint
        var rightKnee: CGPoint
        var rightAnkle: CGPoint
        var rightToe: CGPoint
        var gaze: CGFloat
    }

    // Focus completion is a one-way transition into the break: Mike finishes
    // at the exact approved study desk, stands with fixed proportions, takes
    // planted alternating steps, and then stays in a lightweight dance loop.
    // Furniture fades only after he starts walking and is never drawn behind
    // the celebration group.
    private func drawCelebrating(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        if reduceMotion {
            drawReducedWalkingCelebration(elapsed: elapsed, in: size, context: &context)
            return
        }

        let standStart = 1.6
        let walkStart = 4.4
        let danceStart = 8.4
        let headRadius = size.width * 0.10

        if elapsed < walkStart + 1.2 {
            let furnitureOpacity: CGFloat = elapsed < walkStart
                ? 1
                : 1 - easedProgress(elapsed, start: walkStart, duration: 1.2)
            drawCelebrationFurniture(
                opacity: furnitureOpacity,
                elapsed: elapsed,
                in: size,
                context: &context
            )
        }

        if elapsed < standStart {
            drawCelebrationFigure(
                studyCelebrationPose(in: size),
                headRadius: headRadius,
                in: size,
                context: &context
            )
            let completion = eventWindow(
                elapsed,
                start: 0.25,
                end: 1.45,
                attack: 0.2,
                release: 0.45
            )
            if completion > 0.01 {
                drawCompletionBurst(&context, amount: completion, in: size)
            }
        } else if elapsed < walkStart {
            // All joints interpolate together, so standing up never changes
            // Mike's head size or stretches a limb away from the chair.
            let rise = easedProgress(
                elapsed,
                start: standStart,
                duration: walkStart - standStart
            )
            let pose = interpolateCelebrationPose(
                from: studyCelebrationPose(in: size),
                to: standingCelebrationPose(in: size),
                amount: rise
            )
            drawCelebrationFigure(
                pose,
                headRadius: headRadius,
                in: size,
                context: &context
            )
        } else if elapsed < danceStart {
            let walkTime = elapsed - walkStart
            let progress = easedProgress(
                elapsed,
                start: walkStart,
                duration: danceStart - walkStart
            )
            drawCelebrationFigure(
                walkingCelebrationPose(
                    progress: progress,
                    elapsed: walkTime,
                    in: size
                ),
                headRadius: headRadius,
                in: size,
                context: &context
            )
        } else {
            let danceTime = elapsed - danceStart
            drawCelebrationDance(
                elapsed: danceTime,
                in: size,
                context: &context
            )
        }
    }

    private func drawCelebrationFurniture(
        opacity: CGFloat,
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        guard opacity > 0.01 else { return }
        var furnitureContext = context
        furnitureContext.opacity = Double(opacity)
        drawStudyChair(&furnitureContext, in: size)
        strokeLine(
            &furnitureContext,
            from: point(0.50, 0.60, in: size),
            to: point(0.96, 0.60, in: size)
        )
        strokeLine(
            &furnitureContext,
            from: point(0.80, 0.60, in: size),
            to: point(0.80, 0.96, in: size)
        )
        drawStudyLaptop(&furnitureContext, in: size)
        drawCoffeeMug(
            &furnitureContext,
            center: point(0.71, 0.545, in: size),
            lean: 0,
            liftVelocity: 0,
            steamPhase: elapsed,
            in: size
        )
        drawPhone(
            &furnitureContext,
            center: point(0.60, 0.575, in: size),
            angle: -CGFloat.pi / 2,
            in: size
        )
    }

    private func studyCelebrationPose(in size: CGSize) -> CelebrationPose {
        let shoulder = point(0.35, 0.32, in: size)
        let farShoulder = point(0.36, 0.34, in: size)
        let nearHand = point(0.60, 0.545, in: size)
        let farHand = point(0.67, 0.53, in: size)
        return CelebrationPose(
            head: point(0.40, 0.19, in: size),
            shoulder: shoulder,
            hip: point(0.20, 0.69, in: size),
            nearElbow: armElbow(
                shoulder: shoulder,
                hand: nearHand,
                upperLength: size.width * 0.18,
                lowerLength: size.width * 0.18
            ),
            nearHand: nearHand,
            farShoulder: farShoulder,
            farElbow: armElbow(
                shoulder: farShoulder,
                hand: farHand,
                upperLength: size.width * 0.19,
                lowerLength: size.width * 0.19
            ),
            farHand: farHand,
            leftKnee: point(0.43, 0.72, in: size),
            leftAnkle: point(0.47, 0.94, in: size),
            leftToe: point(0.53, 0.94, in: size),
            rightKnee: point(0.53, 0.65, in: size),
            rightAnkle: point(0.62, 0.92, in: size),
            rightToe: point(0.70, 0.92, in: size),
            gaze: 0.22
        )
    }

    private func standingCelebrationPose(in size: CGSize) -> CelebrationPose {
        let shoulder = point(0.32, 0.37, in: size)
        let farShoulder = point(0.33, 0.39, in: size)
        return CelebrationPose(
            head: point(0.32, 0.22, in: size),
            shoulder: shoulder,
            hip: point(0.32, 0.60, in: size),
            nearElbow: point(0.285, 0.51, in: size),
            nearHand: point(0.275, 0.65, in: size),
            farShoulder: farShoulder,
            farElbow: point(0.355, 0.51, in: size),
            farHand: point(0.365, 0.65, in: size),
            leftKnee: point(0.30, 0.77, in: size),
            leftAnkle: point(0.28, 0.93, in: size),
            leftToe: point(0.34, 0.93, in: size),
            rightKnee: point(0.34, 0.77, in: size),
            rightAnkle: point(0.36, 0.93, in: size),
            rightToe: point(0.42, 0.93, in: size),
            gaze: 0.10
        )
    }

    private func walkingCelebrationPose(
        progress: CGFloat,
        elapsed: TimeInterval,
        in size: CGSize
    ) -> CelebrationPose {
        let hipX = 0.32 + (0.50 - 0.32) * progress
        let cycle = CGFloat(elapsed / 1.15)
        let stride = sin(cycle * .pi * 2)
        let bob = (1 - cos(cycle * .pi * 4)) * 0.003
        let leftFoot = celebrationGaitFoot(cycle: cycle)
        let rightFoot = celebrationGaitFoot(cycle: cycle + 0.5)
        let shoulder = point(hipX, 0.37 - bob, in: size)
        let farShoulder = point(hipX + 0.01, 0.39 - bob, in: size)
        let hip = point(hipX, 0.60 - bob, in: size)
        let leftAnkle = point(
            hipX + leftFoot.offset,
            0.93 - leftFoot.lift,
            in: size
        )
        let rightAnkle = point(
            hipX + rightFoot.offset,
            0.93 - rightFoot.lift,
            in: size
        )
        let nearHand = point(
            hipX + 0.075 * stride,
            0.64 - abs(stride) * 0.015,
            in: size
        )
        let farHand = point(
            hipX - 0.075 * stride,
            0.64 - abs(stride) * 0.015,
            in: size
        )
        let legLength = size.width * 0.16

        return CelebrationPose(
            head: point(hipX, 0.22 - bob, in: size),
            shoulder: shoulder,
            hip: hip,
            nearElbow: armElbow(
                shoulder: shoulder,
                hand: nearHand,
                upperLength: size.width * 0.145,
                lowerLength: size.width * 0.145,
                bendDirection: -1
            ),
            nearHand: nearHand,
            farShoulder: farShoulder,
            farElbow: armElbow(
                shoulder: farShoulder,
                hand: farHand,
                upperLength: size.width * 0.145,
                lowerLength: size.width * 0.145
            ),
            farHand: farHand,
            leftKnee: armElbow(
                shoulder: hip,
                hand: leftAnkle,
                upperLength: legLength,
                lowerLength: legLength,
                bendDirection: -1
            ),
            leftAnkle: leftAnkle,
            leftToe: offset(leftAnkle, x: size.width * 0.055),
            rightKnee: armElbow(
                shoulder: hip,
                hand: rightAnkle,
                upperLength: legLength,
                lowerLength: legLength,
                bendDirection: -1
            ),
            rightAnkle: rightAnkle,
            rightToe: offset(rightAnkle, x: size.width * 0.055),
            gaze: 0.14
        )
    }

    // A foot remains planted for most of the gait cycle; only the short swing
    // phase travels forward and lifts. The half-cycle offset makes the legs
    // alternate naturally instead of opening and closing like scissors.
    private func celebrationGaitFoot(
        cycle: CGFloat
    ) -> (offset: CGFloat, lift: CGFloat) {
        let phase = cycle - floor(cycle)
        let stanceEnd: CGFloat = 0.62
        if phase < stanceEnd {
            let amount = phase / stanceEnd
            return (0.045 - amount * 0.09, 0)
        }
        let raw = (phase - stanceEnd) / (1 - stanceEnd)
        let amount = raw * raw * (3 - 2 * raw)
        return (
            -0.045 + amount * 0.09,
            sin(raw * .pi) * 0.065
        )
    }

    private func drawCelebrationDance(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let friendReveal = easedProgress(elapsed, start: 0, duration: 1.2)
        let variation = Int(elapsed / 4.0) % 3

        var friendContext = context
        friendContext.opacity = Double(friendReveal * 0.72)
        drawDancingFigure(
            centerX: 0.25,
            scale: 0.82,
            elapsed: elapsed + 0.55,
            variation: variation,
            in: size,
            context: &friendContext
        )
        drawDancingFigure(
            centerX: 0.75,
            scale: 0.82,
            elapsed: elapsed + 1.15,
            variation: (variation + 1) % 3,
            in: size,
            context: &friendContext
        )
        drawDancingFigure(
            centerX: 0.50,
            scale: 1,
            elapsed: elapsed,
            variation: variation,
            in: size,
            context: &context
        )
        drawDanceSymbols(elapsed: elapsed, in: size, context: &context)
    }

    private func drawDancingFigure(
        centerX: CGFloat,
        scale: CGFloat,
        elapsed: TimeInterval,
        variation: Int,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let cadence = variation == 1 ? 0.92 : (variation == 2 ? 1.18 : 1.05)
        let beat = CGFloat(sin(elapsed * .pi * cadence))
        let secondBeat = CGFloat(sin(elapsed * .pi * cadence * 2))
        let bounce = abs(beat) * 0.012 * scale
        let shoulder = point(
            centerX + beat * 0.008 * scale,
            0.38 - bounce + (1 - scale) * 0.05,
            in: size
        )
        let farShoulder = offset(
            shoulder,
            x: size.width * 0.008 * scale,
            y: size.height * 0.018 * scale
        )
        let hip = point(
            centerX,
            0.60 - bounce + (1 - scale) * 0.06,
            in: size
        )
        let switchSide = (beat + 1) * 0.5
        let nearLow = point(centerX + 0.16 * scale, 0.43, in: size)
        let nearHigh = point(centerX + 0.11 * scale, 0.18, in: size)
        let farLow = point(centerX - 0.16 * scale, 0.43, in: size)
        let farHigh = point(centerX - 0.11 * scale, 0.18, in: size)
        var nearHand = interpolate(from: nearLow, to: nearHigh, amount: switchSide)
        var farHand = interpolate(from: farHigh, to: farLow, amount: switchSide)

        if variation == 1 {
            nearHand.x += secondBeat * size.width * 0.025
            farHand.x -= secondBeat * size.width * 0.025
        } else if variation == 2 {
            nearHand.y += abs(secondBeat) * size.height * 0.035
            farHand.y += abs(secondBeat) * size.height * 0.035
        }

        let footSpread = (0.075 + abs(secondBeat) * 0.012) * scale
        let leftLift = max(0, secondBeat) * 0.045 * scale
        let rightLift = max(0, -secondBeat) * 0.045 * scale
        let leftAnkle = point(centerX - footSpread, 0.93 - leftLift, in: size)
        let rightAnkle = point(centerX + footSpread, 0.93 - rightLift, in: size)
        let armLength = size.width * 0.145 * scale
        let legLength = size.width * 0.165 * scale
        let pose = CelebrationPose(
            head: point(
                shoulder.x / size.width,
                0.22 - bounce + (1 - scale) * 0.05,
                in: size
            ),
            shoulder: shoulder,
            hip: hip,
            nearElbow: armElbow(
                shoulder: shoulder,
                hand: nearHand,
                upperLength: armLength,
                lowerLength: armLength
            ),
            nearHand: nearHand,
            farShoulder: farShoulder,
            farElbow: armElbow(
                shoulder: farShoulder,
                hand: farHand,
                upperLength: armLength,
                lowerLength: armLength,
                bendDirection: -1
            ),
            farHand: farHand,
            leftKnee: armElbow(
                shoulder: hip,
                hand: leftAnkle,
                upperLength: legLength,
                lowerLength: legLength
            ),
            leftAnkle: leftAnkle,
            leftToe: offset(leftAnkle, x: -size.width * 0.05 * scale),
            rightKnee: armElbow(
                shoulder: hip,
                hand: rightAnkle,
                upperLength: legLength,
                lowerLength: legLength,
                bendDirection: -1
            ),
            rightAnkle: rightAnkle,
            rightToe: offset(rightAnkle, x: size.width * 0.05 * scale),
            gaze: beat * 0.30
        )
        drawCelebrationFigure(
            pose,
            headRadius: size.width * 0.10 * scale,
            in: size,
            context: &context
        )
    }

    private func drawDanceSymbols(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        for index in 0..<3 {
            let duration = 2.8 + Double(index) * 0.25
            let age = (elapsed + Double(index) * 0.72)
                .truncatingRemainder(dividingBy: duration) / duration
            let progress = CGFloat(age)
            let opacity = CGFloat(sin(age * .pi)) * 0.70
            guard opacity > 0.01 else { continue }
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let center = point(
                0.50 + side * (0.15 + CGFloat(index) * 0.04),
                0.43 - progress * 0.25,
                in: size
            )
            var symbolContext = context
            symbolContext.opacity = Double(opacity)
            drawCelebrationSymbol(
                &symbolContext,
                kind: index,
                center: center,
                radius: size.width * 0.026,
                in: size
            )
        }
    }

    private func drawCelebrationFigure(
        _ pose: CelebrationPose,
        headRadius: CGFloat,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        drawStudyHead(
            &context,
            center: pose.head,
            radius: headRadius,
            gaze: pose.gaze
        )
        let neck = CGPoint(
            x: pose.head.x,
            y: pose.head.y + headRadius * 0.92
        )
        strokeLine(&context, from: neck, to: pose.shoulder)
        strokeLine(&context, from: pose.shoulder, to: pose.hip)
        strokeLine(&context, from: pose.shoulder, to: pose.nearElbow)
        strokeLine(&context, from: pose.nearElbow, to: pose.nearHand)
        strokeLine(&context, from: pose.farShoulder, to: pose.farElbow)
        strokeLine(&context, from: pose.farElbow, to: pose.farHand)
        strokeLine(&context, from: pose.hip, to: pose.leftKnee)
        strokeLine(&context, from: pose.leftKnee, to: pose.leftAnkle)
        strokeLine(&context, from: pose.leftAnkle, to: pose.leftToe)
        strokeLine(&context, from: pose.hip, to: pose.rightKnee)
        strokeLine(&context, from: pose.rightKnee, to: pose.rightAnkle)
        strokeLine(&context, from: pose.rightAnkle, to: pose.rightToe)
    }

    private func interpolateCelebrationPose(
        from start: CelebrationPose,
        to end: CelebrationPose,
        amount: CGFloat
    ) -> CelebrationPose {
        CelebrationPose(
            head: interpolate(from: start.head, to: end.head, amount: amount),
            shoulder: interpolate(from: start.shoulder, to: end.shoulder, amount: amount),
            hip: interpolate(from: start.hip, to: end.hip, amount: amount),
            nearElbow: interpolate(from: start.nearElbow, to: end.nearElbow, amount: amount),
            nearHand: interpolate(from: start.nearHand, to: end.nearHand, amount: amount),
            farShoulder: interpolate(from: start.farShoulder, to: end.farShoulder, amount: amount),
            farElbow: interpolate(from: start.farElbow, to: end.farElbow, amount: amount),
            farHand: interpolate(from: start.farHand, to: end.farHand, amount: amount),
            leftKnee: interpolate(from: start.leftKnee, to: end.leftKnee, amount: amount),
            leftAnkle: interpolate(from: start.leftAnkle, to: end.leftAnkle, amount: amount),
            leftToe: interpolate(from: start.leftToe, to: end.leftToe, amount: amount),
            rightKnee: interpolate(from: start.rightKnee, to: end.rightKnee, amount: amount),
            rightAnkle: interpolate(from: start.rightAnkle, to: end.rightAnkle, amount: amount),
            rightToe: interpolate(from: start.rightToe, to: end.rightToe, amount: amount),
            gaze: start.gaze + (end.gaze - start.gaze) * amount
        )
    }

    private func drawReducedWalkingCelebration(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        if elapsed < 2.2 {
            drawCelebrationFurniture(
                opacity: 1,
                elapsed: elapsed,
                in: size,
                context: &context
            )
            let amount = easedProgress(elapsed, start: 0.4, duration: 1.4)
            let pose = interpolateCelebrationPose(
                from: studyCelebrationPose(in: size),
                to: standingCelebrationPose(in: size),
                amount: amount
            )
            drawCelebrationFigure(
                pose,
                headRadius: size.width * 0.10,
                in: size,
                context: &context
            )
        } else {
            // Stable celebratory pose: no repeating travel or bouncing.
            drawDancingFigure(
                centerX: 0.50,
                scale: 1,
                elapsed: 0.42,
                variation: 0,
                in: size,
                context: &context
            )
        }
    }

    // Reduce Motion keeps the approved seated scene and replaces the dance
    // with one slow head lift, one reachable arm lift, and one fading sparkle.
    private func drawReducedCelebration(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let t = elapsed.truncatingRemainder(dividingBy: 6.0)
        let lift = eventWindow(
            t,
            start: 0.7,
            end: 5.2,
            attack: 1.1,
            release: 1.1
        )
        let sparkle = eventWindow(
            t,
            start: 1.8,
            end: 4.5,
            attack: 0.8,
            release: 1.2
        )

        drawStudyChair(&context, in: size)
        strokeLine(&context, from: point(0.50, 0.60, in: size), to: point(0.96, 0.60, in: size))
        strokeLine(&context, from: point(0.80, 0.60, in: size), to: point(0.80, 0.96, in: size))
        drawStudyLaptop(&context, in: size)

        let hip = point(0.20, 0.69, in: size)
        let shoulder = interpolate(
            from: point(0.35, 0.32, in: size),
            to: point(0.335, 0.305, in: size),
            amount: lift
        )
        let headRadius = size.width * 0.10
        let headCenter = interpolate(
            from: point(0.40, 0.19, in: size),
            to: point(0.385, 0.175, in: size),
            amount: lift
        )
        let neck = CGPoint(
            x: headCenter.x,
            y: headCenter.y + headRadius * 0.92
        )
        drawStudyHead(
            &context,
            center: headCenter,
            radius: headRadius,
            gaze: 0.22,
            eyeScale: 1 + lift * 0.14
        )
        strokeLine(&context, from: neck, to: shoulder)
        strokeCurve(
            &context,
            from: shoulder,
            control: point(0.28, 0.50, in: size),
            to: hip
        )

        let nearHand = interpolate(
            from: point(0.60, 0.545, in: size),
            to: point(0.51, 0.30, in: size),
            amount: lift * 0.72
        )
        let nearElbow = armElbow(
            shoulder: shoulder,
            hand: nearHand,
            upperLength: size.width * 0.18,
            lowerLength: size.width * 0.18
        )
        strokeLine(&context, from: shoulder, to: nearElbow)
        strokeLine(&context, from: nearElbow, to: nearHand)

        let farShoulder = offset(
            shoulder,
            x: size.width * 0.010,
            y: size.height * 0.020
        )
        let farHand = point(0.67, 0.53, in: size)
        let farElbow = armElbow(
            shoulder: farShoulder,
            hand: farHand,
            upperLength: size.width * 0.19,
            lowerLength: size.width * 0.19
        )
        strokeLine(&context, from: farShoulder, to: farElbow)
        strokeLine(&context, from: farElbow, to: farHand)

        drawNeutralStudyLegs(&context, hip: hip, in: size)
        drawCoffeeMug(
            &context,
            center: point(0.71, 0.545, in: size),
            lean: 0,
            liftVelocity: 0,
            steamPhase: t,
            in: size
        )
        drawPhone(
            &context,
            center: point(0.60, 0.575, in: size),
            angle: -CGFloat.pi / 2,
            in: size
        )

        if sparkle > 0.01 {
            var sparkleContext = context
            sparkleContext.opacity = Double(sparkle * 0.82)
            drawCelebrationSymbol(
                &sparkleContext,
                kind: 1,
                center: point(0.55, 0.19 - sparkle * 0.018, in: size),
                radius: size.width * 0.033,
                in: size
            )
        }
    }

    private func drawNeutralStudyLegs(
        _ context: inout GraphicsContext,
        hip: CGPoint,
        in size: CGSize
    ) {
        let leftKnee = point(0.43, 0.72, in: size)
        let rightKnee = point(0.53, 0.65, in: size)
        strokeLine(&context, from: hip, to: leftKnee)
        strokeLine(&context, from: leftKnee, to: point(0.47, 0.94, in: size))
        strokeLine(&context, from: point(0.47, 0.94, in: size), to: point(0.53, 0.94, in: size))
        strokeLine(&context, from: hip, to: rightKnee)
        strokeLine(&context, from: rightKnee, to: point(0.62, 0.92, in: size))
        strokeLine(&context, from: point(0.62, 0.92, in: size), to: point(0.70, 0.92, in: size))
    }

    private func drawCompletionBurst(
        _ context: inout GraphicsContext,
        amount: CGFloat,
        in size: CGSize
    ) {
        var burstContext = context
        burstContext.opacity = Double(amount)
        let center = point(0.88, 0.245, in: size)
        let expansion = 0.84 + amount * 0.16
        let width = lineWidth * 0.72

        for angle in [-CGFloat.pi * 0.72, -CGFloat.pi * 0.50, -CGFloat.pi * 0.28] {
            let inner = size.width * 0.030 * expansion
            let outer = size.width * 0.070 * expansion
            strokeLine(
                &burstContext,
                from: CGPoint(
                    x: center.x + cos(angle) * inner,
                    y: center.y + sin(angle) * inner
                ),
                to: CGPoint(
                    x: center.x + cos(angle) * outer,
                    y: center.y + sin(angle) * outer
                ),
                width: width
            )
        }
        drawCelebrationSymbol(
            &burstContext,
            kind: 1,
            center: point(0.96, 0.18, in: size),
            radius: size.width * 0.022 * expansion,
            in: size
        )
    }

    // Sparse monochrome symbols rise and evaporate like the approved coffee
    // vapor. Their starts are staggered so the compact widget never gets busy.
    private func drawCelebrationSymbols(
        _ context: inout GraphicsContext,
        elapsed: TimeInterval,
        amount: CGFloat,
        signature: CGFloat,
        in size: CGSize
    ) {
        let starts: [TimeInterval] = [6.9, 8.45, 9.95, 11.35]
        let origins: [(CGFloat, CGFloat)] = [
            (0.51, 0.34),
            (0.11, 0.39),
            (0.48, 0.42),
            (0.10, 0.34)
        ]
        let duration = 1.75

        for index in starts.indices {
            let age = elapsed - starts[index]
            guard age >= 0, age <= duration else { continue }
            let progress = CGFloat(age / duration)
            let fade = CGFloat(sin(.pi * Double(progress))) * amount * 0.84
            guard fade > 0.01 else { continue }

            let drift = CGFloat(sin(Double(progress) * .pi * 1.3 + Double(index)))
                * size.width * 0.012
            let center = CGPoint(
                x: origins[index].0 * size.width + drift,
                y: (origins[index].1 - progress * 0.18) * size.height
            )
            var symbolContext = context
            symbolContext.opacity = Double(fade)
            drawCelebrationSymbol(
                &symbolContext,
                kind: index,
                center: center,
                radius: size.width * (index == 1 ? 0.029 : 0.025),
                in: size
            )
        }

        if signature > 0.01 {
            var signatureContext = context
            signatureContext.opacity = Double(signature * 0.92)
            drawCelebrationSymbol(
                &signatureContext,
                kind: 1,
                center: point(0.58, 0.15 - signature * 0.012, in: size),
                radius: size.width * (0.036 + signature * 0.008),
                in: size
            )
        }
    }

    private func drawCelebrationSymbol(
        _ context: inout GraphicsContext,
        kind: Int,
        center: CGPoint,
        radius: CGFloat,
        in size: CGSize
    ) {
        let width = lineWidth * 0.72
        switch kind % 4 {
        case 0:
            // One simple eighth note: a stem, short flag, and filled dot.
            strokeLine(
                &context,
                from: CGPoint(x: center.x + radius * 0.35, y: center.y - radius),
                to: CGPoint(x: center.x + radius * 0.35, y: center.y + radius * 0.55),
                width: width
            )
            strokeLine(
                &context,
                from: CGPoint(x: center.x + radius * 0.35, y: center.y - radius),
                to: CGPoint(x: center.x + radius, y: center.y - radius * 0.62),
                width: width
            )
            fillCircle(
                &context,
                center: CGPoint(x: center.x, y: center.y + radius * 0.62),
                radius: max(1, width * 0.62)
            )
        case 1:
            // Four-point sparkle using the same rounded pen language.
            strokeLine(
                &context,
                from: CGPoint(x: center.x, y: center.y - radius),
                to: CGPoint(x: center.x, y: center.y + radius),
                width: width
            )
            strokeLine(
                &context,
                from: CGPoint(x: center.x - radius, y: center.y),
                to: CGPoint(x: center.x + radius, y: center.y),
                width: width
            )
        case 2:
            // Two restrained rhythm strokes, kept clear of Mike's body.
            var upper = Path()
            upper.move(to: CGPoint(x: center.x - radius, y: center.y - radius * 0.42))
            upper.addQuadCurve(
                to: CGPoint(x: center.x + radius, y: center.y - radius * 0.42),
                control: CGPoint(x: center.x, y: center.y - radius)
            )
            var lower = Path()
            lower.move(to: CGPoint(x: center.x - radius * 0.78, y: center.y + radius * 0.38))
            lower.addQuadCurve(
                to: CGPoint(x: center.x + radius * 0.78, y: center.y + radius * 0.38),
                control: CGPoint(x: center.x, y: center.y - radius * 0.12)
            )
            context.stroke(
                upper,
                with: .color(ink),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
            context.stroke(
                lower,
                with: .color(ink),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        default:
            // Tiny outlined star; no fill, color, shadow, or extra detail.
            var star = Path()
            for index in 0..<10 {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 5
                let length = index.isMultiple(of: 2) ? radius : radius * 0.43
                let point = CGPoint(
                    x: center.x + cos(angle) * length,
                    y: center.y + sin(angle) * length
                )
                if index == 0 { star.move(to: point) }
                else { star.addLine(to: point) }
            }
            star.closeSubpath()
            context.stroke(
                star,
                with: .color(ink),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // A readable 2.6-second warning: hands stay planted on the hips while one
    // foot makes a controlled stomp. Red is reserved for the alert accents.
    private func drawAngry(
        elapsed: TimeInterval,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let t = elapsed.truncatingRemainder(dividingBy: 2.6)
        let stompLift = smoothPulse(t, start: 0.55, duration: 0.72)
        let impact = smoothPulse(t, start: 1.25, duration: 0.22)
        let breath = CGFloat(sin(t / 2.6 * .pi * 2.0))

        let head = point(0.50, 0.27 + breath * 0.004, in: size)
        let neck = point(0.50, 0.40, in: size)
        let shoulder = point(0.50, 0.46, in: size)
        let hip = point(0.50, 0.68, in: size)
        drawHead(&context, center: head, radius: size.width * 0.10, blink: 0, angry: true)
        strokeLine(&context, from: point(0.50, 0.37, in: size), to: neck)
        strokeLine(&context, from: neck, to: hip)

        let leftElbow = point(0.36, 0.55, in: size)
        let rightElbow = point(0.64, 0.55, in: size)
        strokeLine(&context, from: shoulder, to: leftElbow)
        strokeLine(&context, from: leftElbow, to: point(0.44, 0.61, in: size))
        strokeLine(&context, from: shoulder, to: rightElbow)
        strokeLine(&context, from: rightElbow, to: point(0.56, 0.61, in: size))

        let leftKnee = point(0.40, 0.80, in: size)
        let rightKnee = point(0.61, 0.80 - stompLift * 0.035, in: size)
        strokeLine(&context, from: hip, to: leftKnee)
        strokeLine(&context, from: leftKnee, to: point(0.32, 0.93, in: size))
        strokeLine(&context, from: hip, to: rightKnee)
        strokeLine(&context, from: rightKnee, to: point(0.70, 0.93 - stompLift * 0.045, in: size))

        drawExclamation(&context, in: size)
        if impact > 0.08 {
            let alpha = Double(impact)
            strokeLine(&context, from: point(0.72, 0.94, in: size), to: point(0.78, 0.90, in: size), color: alertInk.opacity(alpha))
            strokeLine(&context, from: point(0.72, 0.95, in: size), to: point(0.80, 0.96, in: size), color: alertInk.opacity(alpha))
        }
    }

    // MARK: - Shared drawing

    private func drawStudyHead(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        gaze: CGFloat,
        gazeY: CGFloat = 0,
        eyeClosure: CGFloat = 0,
        eyeScale: CGFloat = 1
    ) {
        let bounds = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.stroke(
            Path(ellipseIn: bounds),
            with: .color(ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        let eyeY = center.y - radius * 0.08
        let eyeDX = radius * 0.34
        let pupilRadius = max(1.0, lineWidth * 0.4) * eyeScale
        let eyeHeight = max(lineWidth * 0.28, pupilRadius * 2 * (1 - eyeClosure))
        for direction in [CGFloat(-1), CGFloat(1)] {
            let eyeCenter = CGPoint(
                x: center.x + direction * eyeDX + gaze * radius * 0.05,
                y: eyeY + gazeY * radius * 0.05
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: eyeCenter.x - pupilRadius,
                    y: eyeCenter.y - eyeHeight / 2,
                    width: pupilRadius * 2,
                    height: eyeHeight
                )),
                with: .color(ink)
            )
        }
    }

    private func drawStudyLaptop(_ context: inout GraphicsContext, in size: CGSize) {
        // One continuous, closed screen outline keeps the laptop crisp.
        var screen = Path()
        screen.move(to: point(0.77, 0.56, in: size))
        screen.addLine(to: point(0.83, 0.34, in: size))
        screen.addLine(to: point(0.92, 0.33, in: size))
        screen.addLine(to: point(0.86, 0.56, in: size))
        screen.closeSubpath()
        context.stroke(
            screen,
            with: .color(ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        // A shallow keyboard wedge makes the object read clearly as a laptop.
        var base = Path()
        base.move(to: point(0.55, 0.56, in: size))
        base.addLine(to: point(0.87, 0.56, in: size))
        base.addLine(to: point(0.90, 0.59, in: size))
        base.addLine(to: point(0.53, 0.59, in: size))
        context.stroke(
            base,
            with: .color(ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawPhoneNotification(
        _ context: inout GraphicsContext,
        center: CGPoint,
        amount: CGFloat,
        in size: CGSize
    ) {
        var notificationContext = context
        notificationContext.opacity = Double(amount)
        let width = lineWidth * 0.82

        // Three large rays sit entirely above the phone. Their isolated fan
        // silhouette stays readable among the desk, hand, mug and steam lines.
        strokeLine(
            &notificationContext,
            from: CGPoint(x: center.x - size.width * 0.028, y: center.y - size.height * 0.065),
            to: CGPoint(x: center.x - size.width * 0.080, y: center.y - size.height * 0.135),
            width: width
        )
        strokeLine(
            &notificationContext,
            from: CGPoint(x: center.x, y: center.y - size.height * 0.075),
            to: CGPoint(x: center.x, y: center.y - size.height * 0.160),
            width: width
        )
        strokeLine(
            &notificationContext,
            from: CGPoint(x: center.x + size.width * 0.028, y: center.y - size.height * 0.065),
            to: CGPoint(x: center.x + size.width * 0.070, y: center.y - size.height * 0.135),
            width: width
        )
    }

    // Monochrome social-feed symbols use the same pen weight as the scene.
    // Only three drift up and to the right over a slow 4.6-second cycle, then
    // fade like the mug's vapor without popping into or out of existence.
    private func drawPhoneFeedSymbols(
        _ context: inout GraphicsContext,
        origin: CGPoint,
        elapsed: TimeInterval,
        amount: CGFloat,
        in size: CGSize
    ) {
        let feedCycle = 4.6
        let cycleIndex = Int(floor(elapsed / feedCycle))
        for index in 0..<3 {
            let age = (elapsed / feedCycle + Double(index) * 0.29)
                .truncatingRemainder(dividingBy: 1.0)
            let rise = CGFloat(age)
            let fade = CGFloat(sin(.pi * age)) * amount * 0.82
            let sway = CGFloat(sin(elapsed * 0.72 + Double(index) * 1.8))
                * size.width * 0.010
            let symbolCenter = CGPoint(
                x: origin.x + size.width * (0.035 + rise * 0.11) + sway,
                y: origin.y - size.height * (0.050 + rise * 0.23)
            )
            var symbolContext = context
            symbolContext.opacity = Double(fade)
            drawFeedSymbol(
                &symbolContext,
                kind: (index + cycleIndex) % 4,
                center: symbolCenter,
                radius: size.width * 0.028,
                in: size
            )
        }
    }

    private func drawFeedSymbol(
        _ context: inout GraphicsContext,
        kind: Int,
        center: CGPoint,
        radius: CGFloat,
        in size: CGSize
    ) {
        let symbolWidth = max(1.2, lineWidth * 0.58)
        switch kind {
        case 0: // Music note
            fillCircle(
                &context,
                center: CGPoint(x: center.x - radius * 0.28, y: center.y + radius * 0.45),
                radius: symbolWidth * 0.72
            )
            strokeLine(
                &context,
                from: CGPoint(x: center.x + radius * 0.02, y: center.y + radius * 0.35),
                to: CGPoint(x: center.x + radius * 0.02, y: center.y - radius * 0.72),
                width: symbolWidth
            )
            strokeLine(
                &context,
                from: CGPoint(x: center.x + radius * 0.02, y: center.y - radius * 0.72),
                to: CGPoint(x: center.x + radius * 0.60, y: center.y - radius * 0.48),
                width: symbolWidth
            )

        case 1: // Heart
            var heart = Path()
            heart.move(to: CGPoint(x: center.x, y: center.y + radius * 0.72))
            heart.addCurve(
                to: CGPoint(x: center.x, y: center.y - radius * 0.45),
                control1: CGPoint(x: center.x - radius * 1.05, y: center.y + radius * 0.05),
                control2: CGPoint(x: center.x - radius * 0.72, y: center.y - radius * 0.88)
            )
            heart.addCurve(
                to: CGPoint(x: center.x, y: center.y + radius * 0.72),
                control1: CGPoint(x: center.x + radius * 0.72, y: center.y - radius * 0.88),
                control2: CGPoint(x: center.x + radius * 1.05, y: center.y + radius * 0.05)
            )
            context.stroke(
                heart,
                with: .color(ink),
                style: StrokeStyle(lineWidth: symbolWidth, lineCap: .round, lineJoin: .round)
            )

        case 2: // Star
            var star = Path()
            for vertex in 0..<10 {
                let angle = -CGFloat.pi / 2 + CGFloat(vertex) * .pi / 5
                let vertexRadius = vertex.isMultiple(of: 2) ? radius : radius * 0.42
                let point = CGPoint(
                    x: center.x + cos(angle) * vertexRadius,
                    y: center.y + sin(angle) * vertexRadius
                )
                if vertex == 0 { star.move(to: point) } else { star.addLine(to: point) }
            }
            star.closeSubpath()
            context.stroke(
                star,
                with: .color(ink),
                style: StrokeStyle(lineWidth: symbolWidth, lineCap: .round, lineJoin: .round)
            )

        default: // Message bubble
            let bubble = CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.62,
                width: radius * 2,
                height: radius * 1.25
            )
            context.stroke(
                Path(roundedRect: bubble, cornerRadius: radius * 0.32),
                with: .color(ink),
                style: StrokeStyle(lineWidth: symbolWidth, lineCap: .round, lineJoin: .round)
            )
            strokeLine(
                &context,
                from: CGPoint(x: center.x - radius * 0.28, y: center.y + radius * 0.60),
                to: CGPoint(x: center.x - radius * 0.60, y: center.y + radius * 0.92),
                width: symbolWidth
            )
        }
    }

    private func drawPhone(
        _ context: inout GraphicsContext,
        center: CGPoint,
        angle: CGFloat,
        in size: CGSize
    ) {
        let phoneRect = CGRect(
            x: center.x - size.width * 0.0225,
            y: center.y - size.height * 0.045,
            width: size.width * 0.045,
            height: size.height * 0.09
        )
        var phoneContext = context
        phoneContext.translateBy(x: center.x, y: center.y)
        phoneContext.rotate(by: .radians(Double(angle)))
        phoneContext.translateBy(x: -center.x, y: -center.y)
        phoneContext.stroke(
            Path(phoneRect),
            with: .color(ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawCoffeeMug(
        _ context: inout GraphicsContext,
        center: CGPoint,
        lean: CGFloat,
        liftVelocity: CGFloat,
        steamPhase: TimeInterval,
        in size: CGSize
    ) {
        let width = size.width * 0.07
        let height = size.height * 0.10
        let body = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
        let angleRadians = CGFloat(-12.0 * .pi / 180.0) * lean
        var mugContext = context
        mugContext.translateBy(x: center.x, y: center.y)
        mugContext.rotate(by: .radians(Double(angleRadians)))
        mugContext.translateBy(x: -center.x, y: -center.y)
        strokeRoundedRect(
            &mugContext,
            rect: body,
            radius: max(2, lineWidth * 0.7)
        )

        // A single open curve forms the handle; the arm endpoint meets it.
        var handle = Path()
        handle.move(to: CGPoint(x: body.minX, y: center.y - height * 0.22))
        handle.addCurve(
            to: CGPoint(x: body.minX, y: center.y + height * 0.22),
            control1: CGPoint(x: body.minX - width * 0.72, y: center.y - height * 0.28),
            control2: CGPoint(x: body.minX - width * 0.72, y: center.y + height * 0.28)
        )
        mugContext.stroke(
            handle,
            with: .color(ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        let topCenter = CGPoint(
            x: center.x + sin(angleRadians) * height * 0.5,
            y: center.y - cos(angleRadians) * height * 0.5
        )

        // Each trail fades in, rises, and fully evaporates before its phase wraps.
        for index in 0..<3 {
            let rise = CGFloat(
                (steamPhase / 9.0 + Double(index) * 0.31)
                    .truncatingRemainder(dividingBy: 1.0)
            )
            let fade = sin(.pi * rise)
            let motionTrail = liftVelocity * width * 0.22
            let x = topCenter.x
                + CGFloat(index - 1) * width * 0.20
                + motionTrail * rise * 0.25
            let sway = CGFloat(sin(steamPhase * .pi / 3.0 + Double(index) * 1.7)) * width * 0.13
            let startY = topCenter.y - height * (0.20 + rise * 0.72)
            var steam = Path()
            steam.move(to: CGPoint(x: x, y: startY))
            steam.addCurve(
                to: CGPoint(x: x + sway + motionTrail, y: startY - height * 0.42),
                control1: CGPoint(x: x - sway, y: startY - height * 0.13),
                control2: CGPoint(
                    x: x + sway * 1.5 + motionTrail * 0.7,
                    y: startY - height * 0.29
                )
            )
            var steamContext = context
            steamContext.opacity = Double(fade)
            steamContext.stroke(
                steam,
                with: .color(ink),
                style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round)
            )
        }
    }

    private func drawStudyChair(_ context: inout GraphicsContext, in size: CGSize) {
        var chair = Path()
        chair.move(to: point(0.12, 0.42, in: size))
        chair.addCurve(
            to: point(0.20, 0.69, in: size),
            control1: point(0.17, 0.39, in: size),
            control2: point(0.17, 0.66, in: size)
        )
        chair.addCurve(
            to: point(0.53, 0.64, in: size),
            control1: point(0.31, 0.70, in: size),
            control2: point(0.47, 0.61, in: size)
        )
        context.stroke(
            chair,
            with: .color(ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
        strokeLine(&context, from: point(0.20, 0.69, in: size), to: point(0.13, 0.95, in: size))
        strokeLine(&context, from: point(0.43, 0.71, in: size), to: point(0.48, 0.96, in: size))
    }

    private func drawSleepingMarks(
        _ context: inout GraphicsContext,
        origin: CGPoint,
        sleepTime: TimeInterval,
        amount: CGFloat,
        in size: CGSize
    ) {
        for index in 0..<3 {
            let age = (sleepTime * 0.25 + Double(index) * 0.22)
                .truncatingRemainder(dividingBy: 1.0)
            let fontSize = (compact ? 10.0 : 15.0) + CGFloat(index) * (compact ? 2.0 : 3.0)
            let mark = Text("Z")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            let resolved = context.resolve(mark)
            var markContext = context
            markContext.opacity = Double(amount) * (0.58 + Double(index) * 0.16)
            markContext.draw(
                resolved,
                at: CGPoint(
                    x: origin.x
                        + size.width * (0.14 + CGFloat(index) * 0.055),
                    y: origin.y
                        - size.height * (0.03
                            + CGFloat(index) * 0.065
                            + CGFloat(age) * 0.02)
                ),
                anchor: .center
            )
        }
    }

    private func drawHead(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        blink: CGFloat,
        smile: Bool = false,
        angry: Bool = false
    ) {
        let bounds = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.stroke(
            Path(ellipseIn: bounds),
            with: .color(ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        let eyeY = center.y - radius * 0.08
        let eyeDX = radius * 0.34
        if blink > 0.62 || angry {
            let slope = angry ? radius * 0.18 : 0
            strokeLine(
                &context,
                from: CGPoint(x: center.x - eyeDX - radius * 0.13, y: eyeY - slope),
                to: CGPoint(x: center.x - eyeDX + radius * 0.13, y: eyeY + slope),
                color: angry ? alertInk : ink,
                width: lineWidth * 0.72
            )
            strokeLine(
                &context,
                from: CGPoint(x: center.x + eyeDX - radius * 0.13, y: eyeY + slope),
                to: CGPoint(x: center.x + eyeDX + radius * 0.13, y: eyeY - slope),
                color: angry ? alertInk : ink,
                width: lineWidth * 0.72
            )
        } else {
            fillCircle(&context, center: CGPoint(x: center.x - eyeDX, y: eyeY), radius: max(1.2, lineWidth * 0.48))
            fillCircle(&context, center: CGPoint(x: center.x + eyeDX, y: eyeY), radius: max(1.2, lineWidth * 0.48))
        }

        if smile || angry {
            var mouth = Path()
            mouth.move(to: CGPoint(x: center.x - radius * 0.27, y: center.y + radius * 0.31))
            mouth.addQuadCurve(
                to: CGPoint(x: center.x + radius * 0.27, y: center.y + radius * 0.31),
                control: CGPoint(
                    x: center.x,
                    y: center.y + radius * (smile ? 0.58 : 0.05)
                )
            )
            context.stroke(
                mouth,
                with: .color(angry ? alertInk : ink),
                style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round)
            )
        }
    }

    private func drawExclamation(_ context: inout GraphicsContext, in size: CGSize) {
        strokeLine(
            &context,
            from: point(0.81, 0.13, in: size),
            to: point(0.79, 0.28, in: size),
            color: alertInk,
            width: lineWidth * 1.45
        )
        fillCircle(
            &context,
            center: point(0.785, 0.35, in: size),
            radius: lineWidth * 0.78,
            color: alertInk
        )
    }

    private func strokeLine(
        _ context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        color: Color? = nil,
        width: CGFloat? = nil
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(
            path,
            with: .color(color ?? ink),
            style: StrokeStyle(
                lineWidth: width ?? lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func strokeCurve(
        _ context: inout GraphicsContext,
        from: CGPoint,
        control: CGPoint,
        to: CGPoint,
        color: Color? = nil
    ) {
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: control)
        context.stroke(
            path,
            with: .color(color ?? ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func strokeRoundedRect(
        _ context: inout GraphicsContext,
        rect: CGRect,
        radius: CGFloat,
        color: Color? = nil
    ) {
        context.stroke(
            Path(roundedRect: rect, cornerRadius: radius),
            with: .color(color ?? ink),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func fillCircle(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color? = nil
    ) {
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .color(color ?? ink)
        )
    }

    // MARK: - Timing and geometry

    private func smoothPulse(
        _ time: TimeInterval,
        start: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard time >= start, time <= start + duration else { return 0 }
        let progress = (time - start) / duration
        return CGFloat(sin(progress * .pi))
    }

    private func easedProgress(
        _ time: TimeInterval,
        start: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard duration > 0 else { return time >= start ? 1 : 0 }
        let raw = min(1, max(0, (time - start) / duration))
        let smooth = raw * raw * (3 - 2 * raw)
        return CGFloat(smooth)
    }

    private func eventWindow(
        _ time: TimeInterval,
        start: TimeInterval,
        end: TimeInterval,
        attack: TimeInterval,
        release: TimeInterval
    ) -> CGFloat {
        let fadeIn = easedProgress(time, start: start, duration: attack)
        let fadeOut = 1 - easedProgress(time, start: end - release, duration: release)
        return max(0, min(fadeIn, fadeOut))
    }

    private func stablePoseTime(for mood: CharacterMood) -> TimeInterval {
        switch mood {
        case .studying: 0.8
        case .peeking: 2.7
        case .celebrating: 0.35
        case .angry: 0.25
        }
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    private func rect(
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        in size: CGSize
    ) -> CGRect {
        CGRect(
            x: x * size.width,
            y: y * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }

    private func offset(_ point: CGPoint, x: CGFloat = 0, y: CGFloat = 0) -> CGPoint {
        CGPoint(x: point.x + x, y: point.y + y)
    }

    private func interpolate(from start: CGPoint, to end: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * amount,
            y: start.y + (end.y - start.y) * amount
        )
    }

    private func rotated(
        _ point: CGPoint,
        around pivot: CGPoint,
        angle: CGFloat
    ) -> CGPoint {
        let dx = point.x - pivot.x
        let dy = point.y - pivot.y
        return CGPoint(
            x: pivot.x + dx * cos(angle) - dy * sin(angle),
            y: pivot.y + dx * sin(angle) + dy * cos(angle)
        )
    }

    // Fixed-length two-bone solve: the arm bends, but never shrinks or stretches.
    private func armElbow(
        shoulder: CGPoint,
        hand: CGPoint,
        upperLength: CGFloat,
        lowerLength: CGFloat,
        bendDirection: CGFloat = 1
    ) -> CGPoint {
        let dx = hand.x - shoulder.x
        let dy = hand.y - shoulder.y
        let distance = max(0.001, sqrt(dx * dx + dy * dy))
        let along = (
            upperLength * upperLength
                - lowerLength * lowerLength
                + distance * distance
        ) / (2 * distance)
        let bend = sqrt(max(0, upperLength * upperLength - along * along))
        let base = CGPoint(
            x: shoulder.x + dx / distance * along,
            y: shoulder.y + dy / distance * along
        )
        return CGPoint(
            x: base.x - dy / distance * bend * bendDirection,
            y: base.y + dx / distance * bend * bendDirection
        )
    }

    private var accessibilityDescription: String {
        switch mood {
        case .studying: "Stick figure studying at a laptop"
        case .peeking: "Stick figure checking in from behind a door"
        case .celebrating: "Mike walks away from the desk and celebrates with friends"
        case .angry: "Stick figure showing a red distraction warning"
        }
    }
}
