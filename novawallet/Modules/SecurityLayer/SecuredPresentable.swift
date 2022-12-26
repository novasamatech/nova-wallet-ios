import UIKit
import SoraUI

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

        let blurView = UIVisualEffectView()
        blurView.effect = UIBlurEffect(style: .regular)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        presentationView.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: presentationView.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: presentationView.widthAnchor),
            blurView.centerXAnchor.constraint(equalTo: presentationView.centerXAnchor),
            blurView.centerYAnchor.constraint(equalTo: presentationView.centerYAnchor)
        ])

        securityView = blurView

        if animated {
            let transitionAnimator = TransitionAnimator(type: .reveal)
            transitionAnimator.animate(view: blurView, completionBlock: nil)
        }
    }

    func unsecurePresentingView() {
        securityView?.removeFromSuperview()
        securityView = nil
    }
}
