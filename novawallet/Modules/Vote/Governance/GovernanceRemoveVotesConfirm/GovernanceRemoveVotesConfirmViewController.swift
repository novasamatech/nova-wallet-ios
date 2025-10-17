import UIKit
import Foundation_iOS
import UIKit_iOS

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

        title = R.string(preferredLanguages: languages).localizable.govRemoveVotes()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()
        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonAccount()

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonConfirm()
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
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govTracks()

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
