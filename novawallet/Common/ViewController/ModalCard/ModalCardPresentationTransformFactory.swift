import Foundation
import UIKit

protocol ModalCardPresentationTransformFactoryProtocol {
    func createAppearanceTransform(for presentingViewController: UIViewController) -> CGAffineTransform
    func createDismissingTransform(for presentingViewController: UIViewController) -> CGAffineTransform
}

class ModalCardPresentationTransformFactory {}

// MARK: Private

private extension ModalCardPresentationTransformFactory {
    func presentsLastController(_ presentingViewController: UIViewController) -> Bool {
        presentingViewController
            .presentedViewController?
            .presentedViewController == nil
    }

    func createLastPresenterTransform(for presentingViewController: UIViewController) -> CGAffineTransform {
        guard let sourceView = presentingViewController.view else { return CGAffineTransform.identity }

        let presentationController = presentingViewController.presentationController
        let cardPresentationController = presentationController as? ModalCardPresentationController
        let presenterIsModalCard = cardPresentationController != nil

        let widthDelta: CGFloat = UIConstants.horizontalInset * 2
        let scale = (sourceView.bounds.width - widthDelta) / sourceView.bounds.width

        let heightDeltaAfterScale = (sourceView.bounds.height - (sourceView.bounds.height * scale)) / 2

        var yOffset = heightDeltaAfterScale + Constants.cardPresenterTopInset

        if !presenterIsModalCard {
            yOffset -= presentingViewController.presentedViewController?.view?.frame.origin.y ?? 0
        }

        let sourceTransform = CGAffineTransform.identity
        let sourceScaleTransform = CGAffineTransform(
            scaleX: scale,
            y: scale
        )
        let sourceTranslateTransform = CGAffineTransform(
            translationX: .zero,
            y: -yOffset
        )

        let finalTransform = sourceTransform
            .concatenating(sourceScaleTransform)
            .concatenating(sourceTranslateTransform)

        return finalTransform
    }
}

// MARK: ModalCardPresentationTransformFactoryProtocol

extension ModalCardPresentationTransformFactory: ModalCardPresentationTransformFactoryProtocol {
    func createAppearanceTransform(for presentingViewController: UIViewController) -> CGAffineTransform {
        if presentsLastController(presentingViewController) {
            createLastPresenterTransform(for: presentingViewController)
        } else {
            presentingViewController.view.transform.concatenating(
                CGAffineTransform(
                    translationX: .zero,
                    y: Constants.cardPresenterTopInset
                )
            )
        }
    }

    func createDismissingTransform(for presentingViewController: UIViewController) -> CGAffineTransform {
        if presentsLastController(presentingViewController) {
            .identity
        } else {
            createLastPresenterTransform(for: presentingViewController)
        }
    }
}

// MARK: Constants

private extension ModalCardPresentationTransformFactory {
    enum Constants {
        static let cardPresenterTopInset: CGFloat = 10
    }
}
