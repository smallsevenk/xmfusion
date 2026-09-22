//
//  FusionViewController.swift
//  fusion
//
//  Created by gtbluesky on 2022/3/10.
//

import Flutter
import Foundation

private final class FusionNavigationDelegateProxy: NSObject, UINavigationControllerDelegate {
    weak var owner: FusionViewController?
    weak var navigationController: UINavigationController?
    private var previousDelegate: UINavigationControllerDelegate?

    init(
        owner: FusionViewController,
        navigationController: UINavigationController,
        previousDelegate: UINavigationControllerDelegate?
    ) {
        self.owner = owner
        self.navigationController = navigationController
        self.previousDelegate = previousDelegate
        super.init()
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        previousDelegate?.navigationController?(
            navigationController,
            willShow: viewController,
            animated: animated
        )
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        previousDelegate?.navigationController?(
            navigationController,
            didShow: viewController,
            animated: animated
        )
        owner?.fusionNavigationController(
            navigationController,
            didShow: viewController
        )
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || previousDelegate?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if previousDelegate?.responds(to: selector) == true {
            return previousDelegate
        }
        return super.forwardingTarget(for: selector)
    }

    func restorePreviousDelegate() {
        guard let navigationController else { return }
        if navigationController.delegate === self {
            navigationController.delegate = previousDelegate
        }
        previousDelegate = nil
    }
}

open class FusionViewController: FlutterViewController, FusionPopGestureHandler {
    internal var history: [Dictionary<String, Any?>] = []
    internal var uniqueId = "container_\(UUID().uuidString)"
    private let engineBinding = Fusion.instance.engineBinding
    private var backgroundColor: UIColor = .white
    private var didHandleAttachFailure = false
    private var didRequestNativeClose = false
    private var didReportClose = false
    private var activeInteractiveTransition: UUID?
    private var navigationDelegateProxy: FusionNavigationDelegateProxy?
    private var previousPopGestureEnabled: Bool?

    /// Current Flutter depth as last synchronized by the Fusion Dart runtime.
    public var flutterPageDepth: Int { history.count }

    /// Whether this controller currently owns Fusion's managed engine view.
    public var isFusionEngineAttached: Bool { isAttached }
    
    private var isAttached: Bool {
        get {
            engineBinding?.engine?.viewController == self
        }
    }
    
    @discardableResult
    private func attachToContainer() -> Bool {
        guard let engine = engineBinding?.engine else {
            handleAttachFailure(reason: "managedEngineUnavailable")
            return false
        }
        if !isAttached {
            engine.viewController = self
        }
        guard engine.viewController === self else {
            handleAttachFailure(reason: "managedEngineRejectedController")
            return false
        }
        (self as? FusionMessengerHandler)?.configureFlutterChannel(
            binaryMessenger: engine.binaryMessenger
        )
        return true
    }

    private func detachFromContainer() {
        if isAttached {
            engineBinding?.engine?.viewController = nil
        }
        (self as? FusionMessengerHandler)?.releaseFlutterChannel()
    }
    
    private func onContainerCreate() {
        if isViewOpaque {
            modalPresentationStyle = .fullScreen
            view.backgroundColor = backgroundColor
        } else {
            modalPresentationStyle = .overFullScreen
        }
        FusionStackManager.instance.add(self)
    }

    private func onContainerVisible() {
        guard !didRequestNativeClose else { return }
        installNavigationObservationIfNeeded()
        FusionStackManager.instance.add(self)
        engineBinding?.switchTop(uniqueId) { [weak self] in
            guard let self, !self.didRequestNativeClose else { return }
            self.attachToContainer()
            self.updateSystemOverlayStyle()
        }
        engineBinding?.notifyPageVisible(uniqueId)
        attachToContainer()
    }

    private func updateSystemOverlayStyle() {
        engineBinding?.checkStyle { statusBarStyle in
            NotificationCenter.default.post(
                name: .OverlayStyleUpdateNotificationName,
                object: nil,
                userInfo: [FusionConstant.OverlayStyleUpdateNotificationKey: statusBarStyle.rawValue]
            )
        }
    }

    private func onContainerInvisible() {
        engineBinding?.notifyPageInvisible(uniqueId)
        detachFromContainer()
    }

    private func onContainerDestroy() {
        reportCloseIfNeeded()
        restoreNavigationState()
        FusionStackManager.instance.remove(self)
        engineBinding?.destroy(uniqueId)
    }

    private func handleAttachFailure(reason: String) {
        guard !didHandleAttachFailure else { return }
        didHandleAttachFailure = true
        (Fusion.instance.delegate as? FusionViewControllerLifecycleDelegate)?
            .fusionViewController(self, didFailToAttach: reason)
        DispatchQueue.main.async { [weak self] in
            self?.closeNativeContainerOnce()
        }
    }

    private func installNavigationObservationIfNeeded() {
        guard navigationDelegateProxy == nil, let navigationController else { return }
        previousPopGestureEnabled = navigationController.interactivePopGestureRecognizer?.isEnabled
        let proxy = FusionNavigationDelegateProxy(
            owner: self,
            navigationController: navigationController,
            previousDelegate: navigationController.delegate
        )
        navigationDelegateProxy = proxy
        navigationController.delegate = proxy
    }

    private func restoreNavigationState() {
        navigationDelegateProxy?.restorePreviousDelegate()
        navigationDelegateProxy = nil
        if let previousPopGestureEnabled {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = previousPopGestureEnabled
        }
        previousPopGestureEnabled = nil
    }

    private func reportCloseIfNeeded() {
        guard !didReportClose else { return }
        didReportClose = true
        (Fusion.instance.delegate as? FusionViewControllerLifecycleDelegate)?
            .fusionViewControllerWillClose(self)
    }

    private func closeNativeContainerOnce() {
        guard !didRequestNativeClose else { return }
        didRequestNativeClose = true
        reportCloseIfNeeded()

        if let navigationController,
           navigationController.viewControllers.contains(where: { $0 === self }) {
            if navigationController.topViewController === self,
               navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: true)
            } else if navigationController.viewControllers.count > 1 {
                navigationController.setViewControllers(
                    navigationController.viewControllers.filter { $0 !== self },
                    animated: false
                )
            } else if navigationController.presentingViewController != nil {
                navigationController.dismiss(animated: isViewOpaque)
            }
        } else if presentingViewController != nil {
            dismiss(animated: isViewOpaque)
        }
    }

    /// Native back entry used by host buttons and engine-unavailable fallback.
    /// Flutter pages are removed before the UIKit container is closed.
    @objc open func requestFusionBack() {
        guard !didRequestNativeClose else { return }
        guard isAttached, engineBinding?.engine != nil else {
            closeNativeContainerOnce()
            return
        }
        if history.count > 1 {
            FusionNavigator.maybePop(nil as Any?)
        } else {
            closeNativeContainerOnce()
        }
    }

    public func enablePopGesture() {
        installNavigationObservationIfNeeded()
        guard let navigationController,
              navigationController.topViewController === self,
              navigationController.viewControllers.count > 1 else { return }
        navigationController.interactivePopGestureRecognizer?.isEnabled = true
    }

    public func disablePopGesture() {
        installNavigationObservationIfNeeded()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    fileprivate func fusionNavigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController
    ) {
        guard activeInteractiveTransition != nil else { return }
        finishInteractiveTransition(
            cancelled: viewController === self || navigationController.viewControllers.contains(where: { $0 === self })
        )
    }

    private func finishInteractiveTransition(cancelled: Bool) {
        guard activeInteractiveTransition != nil else { return }
        activeInteractiveTransition = nil
        (Fusion.instance.delegate as? FusionViewControllerLifecycleDelegate)?
            .fusionViewController(self, interactivePopDidFinish: cancelled)
        if cancelled {
            enablePopGesture()
        } else {
            reportCloseIfNeeded()
        }
    }

    public init(routeName: String, routeArgs: Dictionary<String, Any>?, transparent: Bool = false, backgroundColor: UIColor? = nil) {
        if let backgroundColor = backgroundColor {
            self.backgroundColor = backgroundColor
        }
        guard let engine = engineBinding?.engine else {
            super.init()
            return
        }
        engineBinding?.engine?.viewController = nil
        super.init(engine: engine, nibName: nil, bundle: nil)
        isViewOpaque = !transparent
        engineBinding?.create(uniqueId, name: routeName, args: routeArgs)
        onContainerCreate()
    }

    public convenience init(routeName: String, routeArgs: Dictionary<String, Any>?, transparent: Bool = false, backgroundColor: Int) {
        let alpha = CGFloat((backgroundColor & 0xFF000000) >> 24) / 255.0
        let red = CGFloat((backgroundColor & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((backgroundColor & 0xFF00) >> 8) / 255.0
        let blue = CGFloat(backgroundColor & 0xFF) / 255.0
        let bgColor = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        self.init(routeName: routeName, routeArgs: routeArgs, transparent: transparent, backgroundColor: bgColor)
    }

    public required init(coder: NSCoder) {
        guard let engine = engineBinding?.engine else {
            super.init()
            return
        }
        engineBinding?.engine?.viewController = nil
        super.init(engine: engine, nibName: nil, bundle: nil)
        isViewOpaque = coder.decodeBool(forKey: FusionConstant.FUSION_RESTORATION_OPAQUE_KEY)
        if let uniqueId = coder.decodeObject(forKey: FusionConstant.FUSION_RESTORATION_UNIQUE_ID_KEY) as? String {
            self.uniqueId = uniqueId
        }
        let classSet = [NSArray.self, NSDictionary.self, NSString.self, NSNumber.self]
        if let history = coder.decodeObject(of: classSet, forKey: FusionConstant.FUSION_RESTORATION_HISTORY_KEY) as? [Dictionary<String, Any?>] {
            engineBinding?.restore(uniqueId, history: history)
        }
        onContainerCreate()
    }

    open override func encodeRestorableState(with coder: NSCoder) {
        coder.encode(uniqueId, forKey: FusionConstant.FUSION_RESTORATION_UNIQUE_ID_KEY)
        coder.encode(history, forKey: FusionConstant.FUSION_RESTORATION_HISTORY_KEY)
        coder.encode(isViewOpaque, forKey: FusionConstant.FUSION_RESTORATION_OPAQUE_KEY)
        super.encodeRestorableState(with: coder)
    }

    open override func viewWillAppear(_ animated: Bool) {
        onContainerVisible()
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewDidLayoutSubviews()
    }

    open override func viewDidAppear(_ animated: Bool) {
        viewDidLayoutSubviews()
        super.viewDidAppear(animated)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        UIApplication.shared.keyWindow?.endEditing(true)
        super.viewWillDisappear(animated)

        if let transitionCoordinator, transitionCoordinator.isInteractive {
            let transition = UUID()
            activeInteractiveTransition = transition
            transitionCoordinator.notifyWhenInteractionChanges { [weak self] context in
                guard let self, self.activeInteractiveTransition == transition else { return }
                self.finishInteractiveTransition(cancelled: context.isCancelled)
            }
        } else if isMovingFromParent
                    || isBeingDismissed
                    || navigationController?.isBeingDismissed == true {
            reportCloseIfNeeded()
        }
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onContainerInvisible()
        if isMovingFromParent
            || isBeingDismissed
            || navigationController?.viewControllers.contains(where: { $0 === self }) == false {
            reportCloseIfNeeded()
            restoreNavigationState()
        }
    }

    deinit {
        onContainerDestroy()
    }
}
