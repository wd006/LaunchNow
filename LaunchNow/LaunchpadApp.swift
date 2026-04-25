import SwiftUI
import AppKit
import SwiftData
import Combine
import QuartzCore

extension Notification.Name {
    static let launchpadWindowShown = Notification.Name("LaunchpadWindowShown")
    static let launchpadWindowHidden = Notification.Name("LaunchpadWindowHidden")
}

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@main
struct LaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {}
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate?
    
    private enum GesturePreviewMode {
        case showing
        case hiding
    }
    
    private enum GestureCommittedAction {
        case show
        case hide
    }

    private var window: NSWindow?
    private let minimumContentSize = NSSize(width: 800, height: 600)
    private var lastShowAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private var gesturePreviewMode: GesturePreviewMode?
    private var gesturePreviewMadeVisible = false
    private var gesturePreviewTargetRect: NSRect?
    private var gestureCommittedAction: GestureCommittedAction?
    private var gesturePreviewProgress: CGFloat = 0
    private var gestureContinuityProgress: CGFloat?
    private var gesturePreviewActivated = false
    private let showStartScale: CGFloat = 1.28
    private let hideEndScale: CGFloat = 1.28
    private let previewActivationProgress: CGFloat = 0.08
    private let gestureCompletionProgressThreshold: CGFloat = 0.52
    
    let appStore = AppStore()
    var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        
        setupWindow()
        bindGestureSettings()
        appStore.performInitialScanIfNeeded()
        appStore.startAutoRescan()
        
        if appStore.isFullscreenMode { updateWindowMode(isFullscreen: true) }
    }

    private func bindGestureSettings() {
        appStore.$isGlobalPinchEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                if isEnabled {
                    GlobalPinchGestureMonitor.shared.start(
                        promptForAccessibility: true,
                        onPinchIn: { self.registerGestureCommit(.show) },
                        onPinchOut: { self.registerGestureCommit(.hide) },
                        onProgress: { direction, progress in
                            self.applyGestureProgress(direction: direction, progress: progress)
                        },
                        onGestureEnded: {
                            self.finishGesturePreview()
                        }
                    )
                } else {
                    GlobalPinchGestureMonitor.shared.stop()
                    self.cancelGesturePreview()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let rect = calculateContentRect(for: screen)
        
        window = BorderlessWindow(contentRect: rect, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        window?.delegate = self
        window?.isMovable = false
        window?.level = .floating
        window?.collectionBehavior = [.transient, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        window?.isOpaque = true
        window?.backgroundColor = .clear
        window?.hasShadow = true
        window?.contentAspectRatio = NSSize(width: 4, height: 3)
        window?.contentMinSize = minimumContentSize
        window?.minSize = window?.frameRect(forContentRect: NSRect(origin: .zero, size: minimumContentSize)).size ?? minimumContentSize
        
        // SwiftData 支持（固定到 Application Support 目录，避免替换应用后数据丢失）
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let storeDir = appSupport.appendingPathComponent("LaunchNow", isDirectory: true)
            if !fm.fileExists(atPath: storeDir.path) {
                try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
            }
            let storeURL = storeDir.appendingPathComponent("Data.store")

            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: TopItemData.self, PageEntryData.self, configurations: configuration)
            modelContainer = container
            appStore.configure(modelContext: container.mainContext)
            window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore).modelContainer(container))
        } catch {
            // 回退到默认容器，保证功能可用
            if let container = try? ModelContainer(for: TopItemData.self, PageEntryData.self) {
                modelContainer = container
                appStore.configure(modelContext: container.mainContext)
                window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore).modelContainer(container))
            } else {
                window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore))
            }
        }
        
        applyCornerRadius()
        window?.orderFrontRegardless()
        window?.makeKey()
        lastShowAt = Date()
        NotificationCenter.default.post(name: .launchpadWindowShown, object: nil)
        
    }
    
    func showWindow() {
        guard let window = window else { return }
        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        let rect = appStore.isFullscreenMode ? screen.frame : calculateContentRect(for: screen)
        resetGesturePreviewState()
        window.setFrame(rect, display: true)
        applyCornerRadius()
        applyPreviewVisual(scale: 1, alpha: 1)
        window.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        lastShowAt = Date()
        NotificationCenter.default.post(name: .launchpadWindowShown, object: nil)
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = [.transient, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        window.orderFrontRegardless()
    }
    
    func hideWindow() {
        resetGesturePreviewState()
        window?.orderOut(nil)
        applyPreviewVisual(scale: 1, alpha: 1)
        window?.alphaValue = 1
        appStore.isSetting = false
        appStore.currentPage = 0
        appStore.searchText = ""
        appStore.openFolder = nil
        appStore.saveAllOrder()
        appStore.refresh()
        NotificationCenter.default.post(name: .launchpadWindowHidden, object: nil)
    }
    
    func updateWindowMode(isFullscreen: Bool) {
        guard let window = window else { return }
        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        window.setFrame(isFullscreen ? screen.frame : calculateContentRect(for: screen), display: true)
        window.hasShadow = !isFullscreen
        window.contentAspectRatio = isFullscreen ? NSSize(width: 0, height: 0) : NSSize(width: 4, height: 3)
        applyCornerRadius()
        applyPreviewVisual(scale: 1, alpha: window.alphaValue)
    }
    
    private func applyCornerRadius() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = appStore.isFullscreenMode ? 0 : 30
        contentView.layer?.masksToBounds = true
        contentView.layer?.allowsEdgeAntialiasing = true
        configurePreviewLayerGeometry()
    }

    private func applyGestureProgress(direction: GlobalPinchGestureDirection, progress: CGFloat) {
        guard let window else { return }
        let clamped = max(0, min(1, progress))
        if gesturePreviewMode == nil {
            gesturePreviewMode = window.isVisible ? .hiding : .showing
            gesturePreviewTargetRect = targetRectForCurrentScreen()
        }
        transitionPreviewModeIfNeeded(for: direction)
        guard let mode = gesturePreviewMode, let targetRect = gesturePreviewTargetRect else { return }
        let resolvedProgress = resolvedProgress(for: direction, progress: clamped)
        gesturePreviewProgress = resolvedProgress
        if resolvedProgress >= previewActivationProgress {
            gesturePreviewActivated = true
        }

        switch mode {
        case .showing:
            guard direction == .pinchIn else { return }
            guard gesturePreviewActivated else { return }
            if !window.isVisible {
                gesturePreviewMadeVisible = true
                window.setFrame(targetRect, display: true)
                applyCornerRadius()
                applyPreviewVisual(scale: showingScale(for: resolvedProgress), alpha: showingAlpha(for: resolvedProgress))
                window.orderFrontRegardless()
                return
            }
            applyPreviewVisual(scale: showingScale(for: resolvedProgress), alpha: showingAlpha(for: resolvedProgress))
        case .hiding:
            guard direction == .pinchOut, window.isVisible else { return }
            guard gesturePreviewActivated else { return }
            if window.frame != targetRect {
                window.setFrame(targetRect, display: true)
            }
            applyPreviewVisual(scale: hidingScale(for: resolvedProgress), alpha: 1 - 0.92 * resolvedProgress)
        }
    }

    private func registerGestureCommit(_ action: GestureCommittedAction) {
        switch (gesturePreviewMode, action) {
        case (.showing, .show), (.hiding, .hide):
            gestureCommittedAction = action
        default:
            break
        }
    }

    private func finishGesturePreview() {
        guard let window else { return }
        defer { resetGesturePreviewState() }
        guard let mode = gesturePreviewMode, gesturePreviewTargetRect != nil else { return }
        guard gesturePreviewActivated else { return }

        switch mode {
        case .showing where shouldCompleteCurrentGesture():
            animatePreviewVisual(toScale: 1, alpha: 1) {
                self.showWindow()
            }
        case .showing:
            rollbackToHidden(window: window)
        case .hiding where shouldCompleteCurrentGesture():
            animatePreviewVisual(toScale: hidingScale(for: 1), alpha: 0) {
                self.hideWindow()
            }
        case .hiding:
            rollbackToShown()
        }
    }

    private func cancelGesturePreview() {
        guard let window else { return }
        if let targetRect = gesturePreviewTargetRect {
            window.setFrame(targetRect, display: true)
            applyPreviewVisual(scale: 1, alpha: 1)
            if gesturePreviewMadeVisible {
                window.orderOut(nil)
            }
        }
        resetGesturePreviewState()
    }

    private func resetGesturePreviewState() {
        gesturePreviewMode = nil
        gesturePreviewMadeVisible = false
        gesturePreviewTargetRect = nil
        gestureCommittedAction = nil
        gesturePreviewProgress = 0
        gestureContinuityProgress = nil
        gesturePreviewActivated = false
    }

    private func animatePreviewVisual(toScale scale: CGFloat, alpha: CGFloat, completion: (() -> Void)?) {
        guard let contentLayer = window?.contentView?.layer else {
            completion?()
            return
        }
        configurePreviewLayerGeometry()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            CATransaction.begin()
            CATransaction.setAnimationDuration(context.duration)
            CATransaction.setAnimationTimingFunction(context.timingFunction)
            contentLayer.opacity = Float(alpha)
            contentLayer.transform = CATransform3DMakeScale(scale, scale, 1)
            CATransaction.commit()
        } completionHandler: {
            completion?()
        }
    }

    private func rollbackToHidden(window: NSWindow) {
        guard gesturePreviewMadeVisible else { return }
        animatePreviewVisual(toScale: showingScale(for: 0), alpha: 0) {
            window.orderOut(nil)
            self.applyPreviewVisual(scale: 1, alpha: 1)
            window.alphaValue = 1
        }
    }

    private func rollbackToShown() {
        animatePreviewVisual(toScale: 1, alpha: 1, completion: nil)
    }

    private func applyPreviewVisual(scale: CGFloat, alpha: CGFloat) {
        guard let contentLayer = window?.contentView?.layer else { return }
        configurePreviewLayerGeometry()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.transform = CATransform3DMakeScale(scale, scale, 1)
        contentLayer.opacity = Float(alpha)
        CATransaction.commit()
    }

    private func configurePreviewLayerGeometry() {
        guard let contentView = window?.contentView, let contentLayer = contentView.layer else { return }
        contentLayer.bounds = contentView.bounds
        contentLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        contentLayer.position = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
    }

    private func targetRectForCurrentScreen() -> NSRect {
        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        return appStore.isFullscreenMode ? screen.frame : calculateContentRect(for: screen)
    }

    private func transitionPreviewModeIfNeeded(for direction: GlobalPinchGestureDirection) {
        switch (gesturePreviewMode, direction) {
        case (.showing, .pinchOut):
            gesturePreviewMode = .hiding
            gestureCommittedAction = nil
            gestureContinuityProgress = 1 - gesturePreviewProgress
        case (.hiding, .pinchIn):
            gesturePreviewMode = .showing
            gestureCommittedAction = nil
            gestureContinuityProgress = 1 - gesturePreviewProgress
        default:
            break
        }
    }

    private func resolvedProgress(for direction: GlobalPinchGestureDirection, progress: CGFloat) -> CGFloat {
        let continuityProgress = gestureContinuityProgress ?? 0
        let baseProgress: CGFloat
        switch (gestureCommittedAction, gesturePreviewMode, direction) {
        case (.show, .showing, .pinchIn), (.hide, .hiding, .pinchOut):
            baseProgress = 1
        default:
            baseProgress = progress
        }
        let resolved = max(baseProgress, continuityProgress)
        if baseProgress >= continuityProgress {
            gestureContinuityProgress = nil
        } else {
            gestureContinuityProgress = resolved
        }
        return resolved
    }

    private func shouldCompleteCurrentGesture() -> Bool {
        if let action = gestureCommittedAction {
            switch (gesturePreviewMode, action) {
            case (.showing, .show), (.hiding, .hide):
                return true
            default:
                break
            }
        }
        return gesturePreviewProgress >= gestureCompletionProgressThreshold
    }

    private func showingScale(for progress: CGFloat) -> CGFloat {
        showStartScale - (showStartScale - 1) * progress
    }

    private func hidingScale(for progress: CGFloat) -> CGFloat {
        1 + (hideEndScale - 1) * progress
    }

    private func showingAlpha(for progress: CGFloat) -> CGFloat {
        max(0, (progress - 0.12) / 0.88)
    }
    
    private func calculateContentRect(for screen: NSScreen) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let frame = screen.frame
        let width = max(visibleFrame.width * 0.4, minimumContentSize.width, minimumContentSize.height * 4/3)
        let height = width * 3/4
        return NSRect(x: frame.midX - width/2, y: frame.midY - height/2, width: width, height: height)
    }
    
    private func getCurrentActiveScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minSize = minimumContentSize
        let contentSize = sender.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize)).size
        let clamped = NSSize(width: max(contentSize.width, minSize.width), height: max(contentSize.height, minSize.height))
        return sender.frameRect(forContentRect: NSRect(origin: .zero, size: clamped)).size
    }
    
    func windowDidResignKey(_ notification: Notification) { autoHideIfNeeded() }
    func windowDidResignMain(_ notification: Notification) { autoHideIfNeeded() }
    private func autoHideIfNeeded() {
        guard !appStore.isSetting else { return }
        hideWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if window?.isVisible == true {
            hideWindow()
        } else {
            showWindow()
        }
        return false
    }
    
}
