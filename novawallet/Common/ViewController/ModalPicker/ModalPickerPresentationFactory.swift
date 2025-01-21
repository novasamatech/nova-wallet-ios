import UIKit
import SoraUI

// TODO: Remove after migration to UIKit-iOS
public class ModalPickerPresentationFactory: NSObject {
    let configuration: ModalSheetPresentationConfiguration

    weak var presentation: ModalPickerPresentationController?

    public init(configuration: ModalSheetPresentationConfiguration) {
        self.configuration = configuration

        super.init()
    }
}

extension ModalPickerPresentationFactory: UIViewControllerTransitioningDelegate {
    public func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ModalSheetPresentationAppearanceAnimator(animator: configuration.contentAppearanceAnimator)
    }

    public func animationController(forDismissed _: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        ModalSheetPresentationDismissAnimator(
            animator: configuration.contentDissmisalAnimator,
            finalPositionOffset: configuration.style.headerStyle?.preferredHeight ?? 0.0
        )
    }

    public func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source _: UIViewController
    ) -> UIPresentationController? {
        let presentation = ModalPickerPresentationController(
            presentedViewController: presented,
            presenting: presenting,
            configuration: configuration
        )

        self.presentation = presentation

        return presentation
    }

    public func interactionControllerForDismissal(using _: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        presentation?.interactiveDismissal
    }
}
