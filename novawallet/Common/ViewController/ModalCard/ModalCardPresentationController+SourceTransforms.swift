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

    func applySourceDismissTransform() {
        applySourceTransforms { depth, viewController in
            depth == 0 ? .identity : transformFactory.createRestingTransform(for: viewController, depth: depth - 1)
        }
    }

    func applySourceRestingTransforms() {
        applySourceTransforms { depth, viewController in
            transformFactory.createRestingTransform(for: viewController, depth: depth)
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

    func applySourceTransforms(_ createTransform: (Int, UIViewController) -> CGAffineTransform) {
        let sourceViewControllers = sourceViewControllers
        let currentTransforms = sourceViewControllers.map { $0.viewIfLoaded?.transform ?? .identity }

        UIView.performWithoutAnimation {
            sourceViewControllers.forEach { $0.viewIfLoaded?.transform = .identity }
        }

        let transforms = sourceViewControllers.enumerated().map { depth, viewController in
            createTransform(depth, viewController)
        }

        UIView.performWithoutAnimation {
            zip(sourceViewControllers, currentTransforms).forEach { viewController, transform in
                viewController.viewIfLoaded?.transform = transform
            }
        }

        zip(sourceViewControllers, transforms).forEach { viewController, transform in
            viewController.viewIfLoaded?.transform = transform
        }
    }
}
