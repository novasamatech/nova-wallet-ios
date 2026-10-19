import UIKit

extension ModalCardPresentationController {
    func performWithoutSourceTransforms(_ actions: () -> Void) {
        let sourceViews = sourceViews
        let transforms = sourceViews.map(\.transform)
        let heights = sourceViews.map(\.bounds.height)

        UIView.performWithoutAnimation {
            sourceViews.forEach { $0.transform = .identity }
        }

        actions()

        UIView.performWithoutAnimation {
            zip(sourceViews, transforms).forEach { sourceView, transform in
                sourceView.transform = transform
            }
        }

        guard !presentedViewController.isBeingDismissed else { return }

        zip(sourceViews, heights).forEach { sourceView, height in
            let topEdgeDrift = (sourceView.bounds.height - height) * (1 - sourceView.transform.d) / 2

            if topEdgeDrift != 0 {
                sourceView.transform = sourceView.transform.concatenating(
                    CGAffineTransform(translationX: 0, y: -topEdgeDrift)
                )
            }
        }
    }

    func applySourceRestingTransforms() {
        let sourceViewControllers = sourceViewControllers

        sourceViewControllers.forEach { $0.viewIfLoaded?.transform = .identity }

        sourceViewControllers.enumerated().reversed().forEach { depth, viewController in
            viewController.viewIfLoaded?.transform = transformFactory.createRestingTransform(
                for: viewController,
                depth: depth
            )
        }
    }
}

private extension ModalCardPresentationController {
    var sourceViewControllers: [UIViewController] {
        var viewControllers: [UIViewController] = []
        var presentationController: ModalCardPresentationController? = self

        while let currentController = presentationController {
            viewControllers.append(currentController.presentingViewController)

            presentationController = currentController.presentingViewController.presentationController
                as? ModalCardPresentationController
        }

        return viewControllers
    }

    var sourceViews: [UIView] {
        sourceViewControllers.compactMap(\.viewIfLoaded)
    }
}
