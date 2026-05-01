import ApplicationServices
import CoreFoundation
import Darwin

private struct MTPoint {
    var x: Float
    var y: Float
}

private struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

private struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: UInt32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}

private typealias MTDeviceRef = UnsafeMutableRawPointer
private typealias MTContactCallback = @convention(c) (
    MTDeviceRef?,
    UnsafeMutableRawPointer?,
    Int32,
    Double,
    Int32
) -> Int32

private let mtTouchStateMakeTouch: UInt32 = 3
private let mtTouchStateTouching: UInt32 = 4
private let mtTouchStateBreakTouch: UInt32 = 5

private struct FrameTouch {
    let id: Int32
    let x: CGFloat
    let y: CGFloat
    let vx: CGFloat
    let vy: CGFloat
}

private struct PinchSession {
    var fingerIDs = Set<Int32>()
    var initialRadius: CGFloat?
    var filteredRadius: CGFloat?
    var filteredProgress: CGFloat = 0
    var touchLossCount: Int = 0
}

enum GlobalPinchGestureDirection {
    case pinchIn
    case pinchOut
}

@MainActor
final class GlobalPinchGestureMonitor {
    static let shared = GlobalPinchGestureMonitor()

    private var multitouch: MultitouchAPI?
    private var onPinchIn: (() -> Void)?
    private var onPinchOut: (() -> Void)?
    private var onProgress: ((GlobalPinchGestureDirection, CGFloat) -> Void)?
    private var onGestureEnded: (() -> Void)?
    private var lastRecognitionAt = Date.distantPast
    private var session = PinchSession()

    private let minimumTouchCount = 4
    private let pinchInRatioThreshold: CGFloat = 0.9
    private let pinchOutRatioThreshold: CGFloat = 1.1
    private let triggerCooldown: TimeInterval = 0.2
    private let radiusFilterFactor: CGFloat = 0.20
    private let progressDeadZone: CGFloat = 0.015
    /// 进度 EMA 平滑系数（值越小越平滑）
    private let progressFilterFactor: CGFloat = 0.30
    /// 连续丢帧容忍次数，超过才重置会话
    private let touchLossDebounce: Int = 5
    private let minimumVelocityThreshold: CGFloat = 0.005
    /// 最大角度聚类范围（弧度），小于此值视为滑动手势
    private let swipeAngleThreshold: CGFloat = .pi / 3  // 60°

    private init() {}

    func start(
        promptForAccessibility: Bool,
        onPinchIn: @escaping () -> Void,
        onPinchOut: @escaping () -> Void,
        onProgress: @escaping (GlobalPinchGestureDirection, CGFloat) -> Void,
        onGestureEnded: @escaping () -> Void
    ) {
        self.onPinchIn = onPinchIn
        self.onPinchOut = onPinchOut
        self.onProgress = onProgress
        self.onGestureEnded = onGestureEnded
        if promptForAccessibility {
            requestAccessibilityTrustIfNeeded()
        }

        if multitouch == nil {
            do {
                let api = try MultitouchAPI()
                try api.start()
                multitouch = api
            } catch {
                NSLog("LaunchNow: failed to start global pinch monitor: \(String(describing: error))")
            }
        }
    }

    func stop() {
        session = PinchSession()
        onPinchIn = nil
        onPinchOut = nil
        onProgress = nil
        onGestureEnded = nil
        multitouch?.stop()
        multitouch = nil
    }

    fileprivate nonisolated static let callback: MTContactCallback = { _, touchesRawPointer, touchCount, _, _ in
        guard let touchesRawPointer, touchCount > 0 else {
            Task { @MainActor in
                GlobalPinchGestureMonitor.shared.resetSession()
            }
            return 0
        }

        let touchesPointer = touchesRawPointer.bindMemory(to: MTTouch.self, capacity: Int(touchCount))
        let buffer = UnsafeBufferPointer(start: touchesPointer, count: Int(touchCount))
        let makeTouch = mtTouchStateMakeTouch
        let touching = mtTouchStateTouching
        let breakTouch = mtTouchStateBreakTouch
        let activeTouches = buffer.compactMap { touch -> FrameTouch? in
            guard touch.state == makeTouch ||
                    touch.state == touching ||
                    touch.state == breakTouch else {
                return nil
            }
            return FrameTouch(
                id: touch.fingerID,
                x: CGFloat(touch.normalizedVector.position.x),
                y: CGFloat(touch.normalizedVector.position.y),
                vx: CGFloat(touch.normalizedVector.velocity.x),
                vy: CGFloat(touch.normalizedVector.velocity.y)
            )
        }

        Task { @MainActor in
            GlobalPinchGestureMonitor.shared.process(activeTouches: activeTouches)
        }
        return 0
    }

    private func process(activeTouches: [FrameTouch]) {
        // 会话防抖：容忍短暂丢帧，避免因瞬态触丢失重置而闪烁
        guard activeTouches.count >= minimumTouchCount else {
            session.touchLossCount += 1
            if session.touchLossCount >= touchLossDebounce {
                resetSession()
            }
            return
        }
        session.touchLossCount = 0

        let touches = Array(activeTouches.sorted { $0.id < $1.id }.prefix(minimumTouchCount))
        let ids = Set(touches.map(\.id))
        if ids.count < minimumTouchCount {
            session.touchLossCount += 1
            if session.touchLossCount >= touchLossDebounce {
                resetSession()
            }
            return
        }
        session.touchLossCount = 0

        if session.fingerIDs != ids {
            session = PinchSession()
            session.fingerIDs = ids
        }

        // 速度方向聚类检测：若 3+ 手指有明显运动且方向一致，判定为滑动，不处理
        let movingCount = touches.filter { hypot($0.vx, $0.vy) > minimumVelocityThreshold }.count
        if movingCount >= 3 && isSwipeGesture(touches: touches) {
            resetSession()
            return
        }

        let center = CGPoint(
            x: touches.map(\.x).reduce(0, +) / CGFloat(touches.count),
            y: touches.map(\.y).reduce(0, +) / CGFloat(touches.count)
        )
        let radius = touches.reduce(CGFloat.zero) { partial, touch in
            partial + hypot(touch.x - center.x, touch.y - center.y)
        } / CGFloat(touches.count)

        if session.initialRadius == nil {
            session.initialRadius = radius
            session.filteredRadius = radius
            session.filteredProgress = 0
            return
        }

        guard
            let initialRadius = session.initialRadius,
            let previousFilteredRadius = session.filteredRadius,
            initialRadius > 0
        else {
            return
        }

        let filteredRadius = previousFilteredRadius + (radius - previousFilteredRadius) * radiusFilterFactor
        session.filteredRadius = filteredRadius
        let radiusRatio = filteredRadius / initialRadius
        if abs(radiusRatio - 1) < progressDeadZone {
            // 方向切换时重置进度平滑状态
            session.filteredProgress = 0
            return
        }
        if radiusRatio < 1 {
            let rawProgress = (1 - radiusRatio) / (1 - pinchInRatioThreshold)
            let clamped = max(0, min(1, rawProgress))
            session.filteredProgress += (clamped - session.filteredProgress) * progressFilterFactor
            onProgress?(.pinchIn, session.filteredProgress)
        } else if radiusRatio > 1 {
            let rawProgress = (radiusRatio - 1) / (pinchOutRatioThreshold - 1)
            let clamped = max(0, min(1, rawProgress))
            session.filteredProgress += (clamped - session.filteredProgress) * progressFilterFactor
            onProgress?(.pinchOut, session.filteredProgress)
        }

        let now = Date()
        guard now.timeIntervalSince(lastRecognitionAt) >= triggerCooldown else { return }

        if radiusRatio <= pinchInRatioThreshold {
            lastRecognitionAt = now
            resetTrackingBaseline()
            onPinchIn?()
            return
        }

        if radiusRatio >= pinchOutRatioThreshold {
            lastRecognitionAt = now
            resetTrackingBaseline()
            onPinchOut?()
        }
    }

    /// 判断手指速度方向是否高度一致（聚类于小角度范围），若是则判定为滑动手势。
    private func isSwipeGesture(touches: [FrameTouch]) -> Bool {
        guard touches.count >= 4 else { return false }

        let angles = touches.map { atan2($0.vy, $0.vx) }
        let sorted = angles.sorted()
        let n = sorted.count

        var maxGap: CGFloat = 0
        for i in 0..<n {
            var gap = sorted[(i + 1) % n] - sorted[i]
            if gap < 0 { gap += 2 * .pi }
            maxGap = max(maxGap, gap)
        }

        // 最大间隙的补角即为所有角度的聚类范围
        let clusterRange = 2 * .pi - maxGap
        return clusterRange < swipeAngleThreshold
    }

    private func resetSession() {
        if session.initialRadius != nil {
            onGestureEnded?()
        }
        session = PinchSession()
    }

    private func resetTrackingBaseline() {
        guard let filtered = session.filteredRadius else { return }
        session.initialRadius = filtered
        session.filteredProgress = 0
    }

    private func requestAccessibilityTrustIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

private final class MultitouchAPI {
    private typealias CreateListFunc = @convention(c) () -> CFArray?
    private typealias RegisterCallbackFunc = @convention(c) (MTDeviceRef, MTContactCallback) -> Void
    private typealias UnregisterCallbackFunc = @convention(c) (MTDeviceRef, MTContactCallback?) -> Void
    private typealias StartDeviceFunc = @convention(c) (MTDeviceRef, Int32) -> Int32
    private typealias StopDeviceFunc = @convention(c) (MTDeviceRef) -> Int32

    private let handle: UnsafeMutableRawPointer
    private let createList: CreateListFunc
    private let registerCallback: RegisterCallbackFunc
    private let unregisterCallback: UnregisterCallbackFunc?
    private let startDevice: StartDeviceFunc
    private let stopDevice: StopDeviceFunc?
    private var devices: [MTDeviceRef] = []

    init() throws {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            throw MonitorError.libraryUnavailable
        }
        self.handle = handle

        guard
            let createList = MultitouchAPI.loadSymbol("MTDeviceCreateList", from: handle, as: CreateListFunc.self),
            let registerCallback = MultitouchAPI.loadSymbol("MTRegisterContactFrameCallback", from: handle, as: RegisterCallbackFunc.self),
            let startDevice = MultitouchAPI.loadSymbol("MTDeviceStart", from: handle, as: StartDeviceFunc.self)
        else {
            dlclose(handle)
            throw MonitorError.symbolMissing
        }

        self.createList = createList
        self.registerCallback = registerCallback
        self.unregisterCallback = MultitouchAPI.loadSymbol("MTUnregisterContactFrameCallback", from: handle, as: UnregisterCallbackFunc.self)
        self.startDevice = startDevice
        self.stopDevice = MultitouchAPI.loadSymbol("MTDeviceStop", from: handle, as: StopDeviceFunc.self)
    }

    deinit {
        dlclose(handle)
    }

    func start() throws {
        guard let list = createList() else {
            throw MonitorError.deviceListUnavailable
        }

        let count = CFArrayGetCount(list)
        for index in 0 ..< count {
            let value = CFArrayGetValueAtIndex(list, index)
            let device = unsafeBitCast(value, to: MTDeviceRef.self)
            registerCallback(device, GlobalPinchGestureMonitor.callback)
            _ = startDevice(device, 0)
            devices.append(device)
        }

        if devices.isEmpty {
            throw MonitorError.noTrackpadDevice
        }
    }

    func stop() {
        let devices = devices
        self.devices.removeAll()

        for device in devices {
            unregisterCallback?(device, GlobalPinchGestureMonitor.callback)
        }

        guard let stopDevice else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            for device in devices {
                _ = stopDevice(device)
            }
        }
    }

    private static func loadSymbol<T>(_ name: String, from handle: UnsafeMutableRawPointer, as type: T.Type) -> T? {
        guard let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }

    enum MonitorError: Error {
        case libraryUnavailable
        case symbolMissing
        case deviceListUnavailable
        case noTrackpadDevice
    }
}
