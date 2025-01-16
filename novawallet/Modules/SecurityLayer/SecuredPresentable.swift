import UIKit
import UIKit_iOS

protocol SecuredPresentable: AnyObject {
    func securePresentingView(animated: Bool)
    func unsecurePresentingView()
}

private enum SecuredPresentableConstants {
    static var securityViewKey = "com.nova.secure.view"
}

private let securePresentation = UUID().uuidString

extension SecuredPresentable {
    private var securityView: UIView? {
        get {
            objc_getAssociatedObject(
                securePresentation,
                &SecuredPresentableConstants.securityViewKey
            )
                as? UIView
        }

        set {
            objc_setAssociatedObject(
                securePresentation,
                &SecuredPresentableConstants.securityViewKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    private var presentationView: UIView? {
        UIApplication.shared.keyWindow
    }
}

extension SecuredPresentable {
    func securePresentingView(animated: Bool) {
        guard securityView == nil, let presentationView = presentationView else {
            return
        }

        guard
            let splashView = UIStoryboard(
                resource: R.storyboard.launchScreen
            ).instantiateInitialViewController()?.view else {
            return
        }

        presentationView.addSubview(splashView)

        splashView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        securityView = splashView

        if animated {
            let transitionAnimator = TransitionAnimator(type: .reveal)
            transitionAnimator.animate(view: splashView, completionBlock: nil)
        }
    }

    func unsecurePresentingView() {
        securityView?.removeFromSuperview()
        securityView = nil
    }
}
