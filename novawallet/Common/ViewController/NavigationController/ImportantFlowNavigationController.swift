import UIKit
import Foundation_iOS

class ImportantFlowNavigationController: NovaNavigationController, ControllerBackedProtocol {
    let localizationManager: LocalizationManagerProtocol

    let dismissalClosure: (() -> Void)?

    init(
        rootViewController: UIViewController,
        localizationManager: LocalizationManagerProtocol,
        dismissalClosure: (() -> Void)?
    ) {
        self.localizationManager = localizationManager
        self.dismissalClosure = dismissalClosure

        // from iOS 13 we can do init(rootController:) but due to iOS 12 bug need to stick to this approach
        super.init(nibName: nil, bundle: nil)

        viewControllers = [rootViewController]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: ModalCardPresentationControllerDelegate

extension ImportantFlowNavigationController: ModalCardPresentationControllerDelegate {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        let containsImportantViews = viewControllers.contains { ($0 as? ImportantViewProtocol) != nil }
        return !containsImportantViews
    }

    func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {
        let languages = localizationManager.selectedLocale.rLanguages

        let action = AlertPresentableAction(
            title: R.string.localizable.commonCancelOperationAction(preferredLanguages: languages),
            style: .destructive
        ) { [weak self] in
            self?.dismiss(animated: true, completion: nil)
            self?.dismissalClosure?()
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.commonCancelOperationMessage(preferredLanguages: languages),
            message: nil,
            actions: [action],
            closeAction: R.string.localizable.commonKeepEditingAction(preferredLanguages: languages)
        )

        present(viewModel: viewModel, style: .actionSheet, from: self)
    }
}

// MARK: AlertPresentable

extension ImportantFlowNavigationController: AlertPresentable {}
