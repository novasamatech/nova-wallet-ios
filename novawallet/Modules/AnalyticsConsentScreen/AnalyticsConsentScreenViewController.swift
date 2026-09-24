import UIKit
import Foundation_iOS

final class AnalyticsConsentScreenViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsConsentScreenViewLayout

    let presenter: AnalyticsConsentScreenPresenterProtocol

    init(
        presenter: AnalyticsConsentScreenPresenterProtocol,
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
        view = AnalyticsConsentScreenViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }
}

private extension AnalyticsConsentScreenViewController {
    func setupHandlers() {
        rootView.agreeButton.addTarget(self, action: #selector(actionAgree), for: .touchUpInside)
        rootView.declineButton.addTarget(self, action: #selector(actionDecline), for: .touchUpInside)
        rootView.detailsView.onPrivacyNotice = { [weak self] in
            self?.presenter.showPrivacyNotice()
        }
    }

    func setupLocalization() {
        rootView.applyLocalization(locale: selectedLocale)
    }

    @objc func actionAgree() {
        presenter.agree()
    }

    @objc func actionDecline() {
        presenter.decline()
    }
}

extension AnalyticsConsentScreenViewController: AnalyticsConsentScreenViewProtocol {}

extension AnalyticsConsentScreenViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
