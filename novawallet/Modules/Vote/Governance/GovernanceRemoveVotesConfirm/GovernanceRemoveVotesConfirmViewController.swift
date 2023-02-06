import UIKit
import SoraFoundation
import SoraUI

final class GovRemoveVotesConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceRemoveVotesConfirmViewLayout

    let presenter: GovernanceRemoveVotesConfirmPresenterProtocol

    init(
        presenter: GovernanceRemoveVotesConfirmPresenterProtocol,
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
        view = GovernanceRemoveVotesConfirmViewLayout()
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
            action: #selector(actionAccountOptions),
            for: .touchUpInside
        )

        rootView.actionLoadableView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.govRemoveVotes(preferredLanguages: languages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(preferredLanguages: languages)

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionTracks() {
        presenter.showTracks()
    }

    @objc private func actionAccountOptions() {
        presenter.showAccountOptions()
    }
}

extension GovRemoveVotesConfirmViewController: GovernanceRemoveVotesConfirmViewProtocol {
    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.feeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveTracks(viewModel: GovernanceTracksViewModel) {
        let title = R.string.localizable.govTracks(preferredLanguages: selectedLocale.rLanguages)

        if viewModel.canExpand {
            let cell = rootView.setSelectableTracks(for: title, tracks: viewModel.details)
            cell.addTarget(self, action: #selector(actionTracks), for: .touchUpInside)
        } else {
            rootView.setNotSelectableTracks(for: title, tracks: viewModel.details)
        }
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension GovRemoveVotesConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
