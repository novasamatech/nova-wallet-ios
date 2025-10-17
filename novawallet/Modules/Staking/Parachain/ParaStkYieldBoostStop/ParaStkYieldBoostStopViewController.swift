import UIKit
import Foundation_iOS

final class ParaStkYieldBoostStopViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = ParaStkYieldBoostStopViewLayout

    let presenter: ParaStkYieldBoostStopPresenterProtocol

    init(presenter: ParaStkYieldBoostStopPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParaStkYieldBoostStopViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionLoadableView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )

        rootView.senderCell.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.commonYieldBoost()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()
        rootView.senderCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonSender()

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.collatorCell.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.parachainStakingCollator()

        rootView.stakingTypeCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.stakingTitle()

        rootView.stakingTypeCell.bind(
            details: R.string(preferredLanguages: languages).localizable.withoutYieldBoost()
        )

        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonConfirm()

        rootView.actionLoadableView.actionButton.applyState(title: title, enabled: true)
    }

    @objc private func actionConfirm() {
        presenter.submit()
    }

    @objc private func actionSender() {
        presenter.showSenderActions()
    }
}

extension ParaStkYieldBoostStopViewController: ParaStkYieldBoostStopViewProtocol {
    func didReceiveSender(viewModel: DisplayAddressViewModel) {
        rootView.senderCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveCollator(viewModel: DisplayAddressViewModel) {
        rootView.collatorCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension ParaStkYieldBoostStopViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
