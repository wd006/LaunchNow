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
}

private struct PinchSession {
    var fingerIDs = Set<Int32>()
    var initialRadius: CGFloat?
    var minimumRadius: CGFloat?
    var maximumRadius: CGFloat?
}

@MainActor
final class GlobalPinchGestureMonitor {
    static let shared = GlobalPinchGestureMonitor()

    private var multitouch: MultitouchAPI?
    private var onPinchIn: (() -> Void)?
    private var onPinchOut: (() -> Void)?
    private var lastRecognitionAt = Date.distantPast
    private var session = PinchSession()

    private let minimumTouchCount = 4
    private let pinchInRatioThreshold: CGFloat = 0.72
    private let pinchOutRatioThreshold: CGFloat = 1.28
    private let triggerCooldown: TimeInterval = 0.2

    private init() {}

    func start(
        promptForAccessibility: Bool,
        onPinchIn: @escaping () -> Void,
        onPinchOut: @escaping () -> Void
    ) {
        self.onPinchIn = onPinchIn
        self.onPinchOut = onPinchOut
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
                y: CGFloat(touch.normalizedVector.position.y)
            )
        }

        Task { @MainActor in
            GlobalPinchGestureMonitor.shared.process(activeTouches: activeTouches)
        }
        return 0
    }

    private func process(activeTouches: [FrameTouch]) {
        guard activeTouches.count >= minimumTouchCount else {
            resetSession()
            return
        }

        let touches = Array(activeTouches.sorted { $0.id < $1.id }.prefix(minimumTouchCount))
        let ids = Set(touches.map(\.id))
        if ids.count < minimumTouchCount {
            resetSession()
            return
        }

        if session.fingerIDs != ids {
            session = PinchSession()
            session.fingerIDs = ids
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
            session.minimumRadius = radius
            session.maximumRadius = radius
            return
        }

        session.minimumRadius = min(session.minimumRadius ?? radius, radius)
        session.maximumRadius = max(session.maximumRadius ?? radius, radius)

        guard
            let initialRadius = session.initialRadius,
            let minimumRadius = session.minimumRadius,
            let maximumRadius = session.maximumRadius,
            initialRadius > 0
        else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastRecognitionAt) >= triggerCooldown else { return }

        let shrinkRatio = minimumRadius / initialRadius
        if shrinkRatio <= pinchInRatioThreshold {
            lastRecognitionAt = now
            resetTrackingBaseline(to: radius)
            onPinchIn?()
            return
        }

        let expandRatio = maximumRadius / initialRadius
        if expandRatio >= pinchOutRatioThreshold {
            lastRecognitionAt = now
            resetTrackingBaseline(to: radius)
            onPinchOut?()
        }
    }

    private func resetSession() {
        session = PinchSession()
    }

    private func resetTrackingBaseline(to radius: CGFloat) {
        session.initialRadius = radius
        session.minimumRadius = radius
        session.maximumRadius = radius
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
