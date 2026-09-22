import UIKit
import Foundation_iOS

final class AnalyticsPrivacyViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsPrivacyViewLayout

    let presenter: AnalyticsPrivacyPresenterProtocol

    init(
        presenter: AnalyticsPrivacyPresenterProtocol,
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
        view = AnalyticsPrivacyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }
}

private extension AnalyticsPrivacyViewController {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        title = strings.settingsPrivacyTitle()
        rootView.titleLabel.text = strings.settingsAnalyticsTitle()
        rootView.consentSwitch.accessibilityLabel = strings.settingsAnalyticsTitle()
        rootView.detailsView.applyLocalization(locale: selectedLocale)
    }

    func setupHandlers() {
        rootView.consentSwitch.addTarget(self, action: #selector(actionToggle), for: .valueChanged)
        rootView.detailsView.onPrivacyNotice = { [weak self] in
            self?.presenter.showPrivacyNotice()
        }
    }

    @objc func actionToggle() {
        presenter.setEnabled(rootView.consentSwitch.isOn)
    }
}

extension AnalyticsPrivacyViewController: AnalyticsPrivacyViewProtocol {
    func didReceive(isOn: Bool, canToggle: Bool) {
        rootView.bind(isOn: isOn, canToggle: canToggle)
    }
}

extension AnalyticsPrivacyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
