import UIKit
import Foundation_iOS

final class GovernanceUnlockConfirmViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = GovernanceUnlockConfirmViewLayout

    let presenter: GovernanceUnlockConfirmPresenterProtocol

    init(
        presenter: GovernanceUnlockConfirmPresenterProtocol,
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
        view = GovernanceUnlockConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.accountCell.addTarget(self, action: #selector(actionSender), for: .touchUpInside)

        rootView.actionLoadableView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.commonUnlock()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()

        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonAccount()

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.transferableTitleLabel.text = R.string(preferredLanguages: languages).localizable.walletBalanceAvailable()

        rootView.lockAmountTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonGovLock()

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSender() {
        presenter.presentSenderDetails()
    }
}

extension GovernanceUnlockConfirmViewController: GovernanceUnlockConfirmViewProtocol {
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

    func didReceiveTransferableAmount(viewModel: ReferendumLockTransitionViewModel) {
        rootView.transferableCell.bind(viewModel: viewModel)
    }

    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel) {
        rootView.lockedAmountCell.bind(viewModel: viewModel)
    }

    func didReceiveRemainedLock(viewModel: GovernanceRemainedLockViewModel?) {
        if let viewModel = viewModel {
            let amountString = NSMutableAttributedString(
                string: viewModel.amount + " ",
                attributes: [
                    .foregroundColor: R.color.colorTextPrimary()!,
                    .font: UIFont.caption1
                ]
            )

            let remainingLocksString = viewModel.modules
                .map { $0.firstLetterCapitalized() }
                .joined(separator: ", ")

            let remainingLocksAttributedString = NSAttributedString(
                string: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govRemainsLockedSuffix(
                    remainingLocksString
                ),
                attributes: [
                    .foregroundColor: R.color.colorTextSecondary()!,
                    .font: UIFont.caption1
                ]
            )

            amountString.append(remainingLocksAttributedString)

            rootView.hintsView.bind(attributedTexts: [amountString])
        } else {
            rootView.hintsView.bind(attributedTexts: [])
        }
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension GovernanceUnlockConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
