import UIKit
import Foundation_iOS

final class StartStakingConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = StartStakingConfirmViewLayout

    let presenter: StartStakingConfirmPresenterProtocol

    init(presenter: StartStakingConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StartStakingConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.accountCell.addTarget(
            self,
            action: #selector(actionSelectSender),
            for: .touchUpInside
        )

        rootView.stakingDetailsCell.addTarget(
            self,
            action: #selector(actionSelectDetails),
            for: .touchUpInside
        )

        rootView.genericActionView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.stakingStartTitle()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()
        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonAccount()

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.stakingTypeCell.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.stakingTypeTitle()

        rootView.genericActionView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonConfirm()
    }

    @objc func actionSelectSender() {
        presenter.selectSender()
    }

    @objc func actionSelectDetails() {
        presenter.selectStakingDetails()
    }

    @objc func actionConfirm() {
        presenter.confirm()
    }
}

extension StartStakingConfirmViewController: StartStakingConfirmViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol) {
        rootView.amountView.bind(viewModel: viewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.feeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveStakingType(viewModel: String) {
        rootView.stakingTypeCell.bind(details: viewModel)
    }

    func didReceiveStakingDetails(title: String, info: DisplayAddressViewModel) {
        rootView.stakingDetailsCell.titleLabel.text = title
        rootView.stakingDetailsCell.detailsLabel.lineBreakMode = info.lineBreakMode
        rootView.stakingDetailsCell.bind(viewModel: info.cellViewModel)
    }

    func didStartLoading() {
        rootView.genericActionView.startLoading()
    }

    func didStopLoading() {
        rootView.genericActionView.stopLoading()
    }
}

extension StartStakingConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
