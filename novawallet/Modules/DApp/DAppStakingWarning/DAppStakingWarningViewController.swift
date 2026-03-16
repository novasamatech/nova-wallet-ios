import UIKit
import Foundation_iOS
import UIKit_iOS

final class DAppStakingWarningViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppStakingWarningViewLayout

    let presenter: DAppStakingWarningPresenterProtocol

    init(
        presenter: DAppStakingWarningPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0.0, height: 380.0)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppStakingWarningViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    func showContinueOption() {
        rootView.advancedButton.isHidden = true
        rootView.continueButton.isHidden = false
    }

    private func setupHandlers() {
        rootView.goToStakeButton.addTarget(
            self,
            action: #selector(actionGoToStake),
            for: .touchUpInside
        )

        rootView.advancedButton.addTarget(
            self,
            action: #selector(actionAdvanced),
            for: .touchUpInside
        )

        rootView.continueButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable
            .dappStakingWarningTitle()
        rootView.subtitleLabel.text = R.string(preferredLanguages: languages).localizable
            .dappStakingWarningSubtitle()
        rootView.goToStakeButton.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable
            .dappStakingWarningGoToStaking()
        rootView.advancedButton.setTitle(
            R.string(preferredLanguages: languages).localizable.dappStakingWarningAdvanced(),
            for: .normal
        )
        rootView.continueButton.setTitle(
            R.string(preferredLanguages: languages).localizable.dappStakingWarningContinue(),
            for: .normal
        )
    }

    @objc func actionGoToStake() {
        presenter.goToStake()
    }

    @objc func actionAdvanced() {
        presenter.showAdvanced()
    }

    @objc func actionContinue() {
        presenter.continueToSite()
    }
}

extension DAppStakingWarningViewController: DAppStakingWarningViewProtocol {}

extension DAppStakingWarningViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension DAppStakingWarningViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool { false }

    func presenterDidHide(_: ModalPresenterProtocol) {}
}
