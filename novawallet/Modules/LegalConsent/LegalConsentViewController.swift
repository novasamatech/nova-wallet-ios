import UIKit
import UIKit_iOS
import Foundation_iOS

final class LegalConsentViewController: UIViewController, ViewHolder {
    typealias RootViewType = LegalConsentViewLayout

    let presenter: LegalConsentPresenterProtocol

    init(
        presenter: LegalConsentPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LegalConsentViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()

        presenter.setup()
    }
}

// MARK: - Private

private extension LegalConsentViewController {
    func setupHandlers() {
        rootView.acceptButton.addTarget(self, action: #selector(actionAccept), for: .touchUpInside)

        rootView.consentView.onCheckboxToggle = { [weak self] in
            self?.presenter.toggleConsent()
        }

        rootView.consentView.onLinkTap = { [weak self] type in
            self?.presenter.activateLegalDocument(type)
        }
    }

    @objc func actionAccept() {
        presenter.accept()
    }
}

// MARK: - LegalConsentViewProtocol

extension LegalConsentViewController: LegalConsentViewProtocol {
    func didReceive(viewModel: LegalConsentViewModel) {
        rootView.bind(viewModel: viewModel)

        didReceiveConsent(accepted: viewModel.consentAccepted)
    }

    func didReceiveConsent(accepted: Bool) {
        rootView.consentView.isChecked = accepted
        rootView.setAcceptEnabled(accepted)
    }
}

// MARK: - Localizable

extension LegalConsentViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        presenter.updateLocalization()
    }
}

// MARK: - ModalSheetPresenterDelegate

/// The only mechanism that blocks dismissal for a `.custom` bottom sheet: `presenterShouldHide`
/// gates both the backdrop tap and the interactive swipe down, while `presenterCanDrag` blocks the
/// drag outright. Not conforming at all is the worst case — the backdrop tap then dismisses
/// unconditionally. `isModalInPresentation` is deliberately unused because
/// `ModalSheetPresentationController` never consults it.
extension LegalConsentViewController: ModalSheetPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool { false }

    func presenterDidHide(_: ModalPresenterProtocol) {}

    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool { false }
}
