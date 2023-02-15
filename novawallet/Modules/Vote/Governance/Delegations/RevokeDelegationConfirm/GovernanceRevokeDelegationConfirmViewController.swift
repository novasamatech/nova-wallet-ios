import UIKit
import SoraFoundation

final class GovRevokeDelegationConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovRevokeDelegationConfirmViewLayout

    let presenter: GovernanceRevokeDelegationConfirmPresenterProtocol

    init(
        presenter: GovernanceRevokeDelegationConfirmPresenterProtocol,
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
        view = GovRevokeDelegationConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionLoadableView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )

        rootView.accountCell.addTarget(
            self,
            action: #selector(actionSenderOptions),
            for: .touchUpInside
        )

        rootView.delegateCell.addTarget(
            self,
            action: #selector(actionDelegateOptions),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.govRevokeDelegationTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(preferredLanguages: languages)

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.delegateCell.titleLabel.text = R.string.localizable.govDelegate(
            preferredLanguages: languages
        )

        rootView.undelegatingPeriodTitleLabel.text = R.string.localizable.govUndelegatingPeriod(
            preferredLanguages: languages
        )

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSenderOptions() {
        presenter.presentSenderAccount()
    }

    @objc private func actionDelegateOptions() {
        presenter.presentDelegateAccount()
    }

    @objc private func actionTracks() {
        presenter.presentTracks()
    }
}

extension GovRevokeDelegationConfirmViewController: GovernanceRevokeDelegationConfirmViewProtocol {
    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.feeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveDelegate(viewModel: GovernanceDelegateStackCell.Model) {
        rootView.delegateCell.bind(viewModel: viewModel)
    }

    func didReceiveTracks(viewModel: GovernanceTracksViewModel) {
        if
            let cell = rootView.addTracksCell(
                for: R.string.localizable.govTracks(preferredLanguages: selectedLocale.rLanguages),
                viewModel: viewModel
            ) {
            cell.addTarget(self, action: #selector(actionTracks), for: .touchUpInside)
        }
    }

    func didReceiveYourDelegation(viewModel: GovernanceYourDelegationViewModel) {
        rootView.addYourDelegationCell(for: viewModel, locale: selectedLocale)
    }

    func didReceiveUndelegatingPeriod(viewModel: String) {
        rootView.undelegatingPeriodCell.valueLabel.text = viewModel
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintsView.bind(texts: viewModel)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension GovRevokeDelegationConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
