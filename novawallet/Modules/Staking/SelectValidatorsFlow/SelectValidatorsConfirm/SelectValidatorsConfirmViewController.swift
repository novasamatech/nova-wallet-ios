import UIKit
import SoraUI
import SoraFoundation

final class SelectValidatorsConfirmViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = SelectValidatorsConfirmViewLayout

    let presenter: SelectValidatorsConfirmPresenterProtocol
    let quantityFormatter: NumberFormatter
    let localizableTitle: LocalizableResource<String>

    private var confirmationViewModel: SelectValidatorsConfirmViewModel?
    private var amountViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var hintsViewModel: LocalizableResource<[String]>?

    init(
        presenter: SelectValidatorsConfirmPresenterProtocol,
        localizableTitle: LocalizableResource<String>,
        quantityFormatter: NumberFormatter,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizableTitle = localizableTitle
        self.quantityFormatter = quantityFormatter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SelectValidatorsConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        updateActionButton()

        rootView.removeAmountIfNeeded()
        rootView.removeRewardDestinationIfNeeded()

        presenter.setup()
    }

    private func configure() {
        rootView.accountCell.addTarget(
            self,
            action: #selector(actionOnWalletAccount),
            for: .touchUpInside
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(proceed),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = localizableTitle.value(for: selectedLocale)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: languages
        )

        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: languages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: languages
        )

        rootView.actionButton.invalidateLayout()

        rootView.validatorsCell.titleLabel.text = R.string.localizable.stakingSelectedValidatorsTitle(
            preferredLanguages: languages
        )

        rootView.rewardDestinationCell.titleLabel.text = R.string.localizable
            .stakingRewardsDestinationTitle_v2_0_0(
                preferredLanguages: languages
            )

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        applyAmountViewModel()
        applyFeeViewModel()
        applyHints()
    }

    private func updateActionButton() {
        let isEnabled = (confirmationViewModel != nil)

        rootView.actionButton.isUserInteractionEnabled = isEnabled

        if isEnabled {
            rootView.actionButton.applyEnabledStyle()
        } else {
            rootView.actionButton.applyTranslucentDisabledStyle()
        }
    }

    private func applyConfirmationViewModel() {
        guard let viewModel = confirmationViewModel else {
            return
        }

        rootView.walletCell.bind(viewModel: viewModel.walletViewModel.cellViewModel)
        rootView.accountCell.bind(viewModel: viewModel.accountViewModel.cellViewModel)

        if let rewardDestination = viewModel.rewardDestination {
            rootView.addRewardDestinationIfNeeded()
            applyRewardDestinationViewModel(rewardDestination)
        } else {
            rootView.removeRewardDestinationIfNeeded()
        }

        rootView.validatorsCell.detailsLabel.text = R.string.localizable.stakingValidatorInfoNominators(
            quantityFormatter.string(from: NSNumber(value: viewModel.validatorsCount)) ?? "",
            quantityFormatter.string(from: NSNumber(value: viewModel.maxValidatorCount)) ?? "",
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func applyRewardDestinationViewModel(_ viewModel: RewardDestinationTypeViewModel) {
        switch viewModel {
        case .restake:
            rootView.rewardDestinationCell.detailsLabel.text = R.string.localizable
                .stakingRestakeTitle_v2_2_0(preferredLanguages: selectedLocale.rLanguages)
            rootView.removePayoutAccountIfNeeded()
        case let .payout(details):
            rootView.rewardDestinationCell.detailsLabel.text = R.string.localizable
                .stakingPayoutTitle_v2_2_0(preferredLanguages: selectedLocale.rLanguages)
            rootView.addPayoutAccountIfNeeded()

            rootView.payoutAccountCell?.addTarget(
                self,
                action: #selector(actionOnPayoutAccount),
                for: .touchUpInside
            )

            rootView.payoutAccountCell?.titleLabel.text =
                R.string.localizable.stakingRewardPayoutAccount(
                    preferredLanguages: selectedLocale.rLanguages
                )

            rootView.payoutAccountCell?.bind(viewModel: details.displayAddress().cellViewModel)
        }
    }

    private func applyHints() {
        guard let hints = hintsViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.bindHints(hints)
    }

    private func applyAmountViewModel() {
        if let viewModel = amountViewModel?.value(for: selectedLocale) {
            rootView.addAmountIfNeeded()
            rootView.amountView.bind(viewModel: viewModel)
        } else {
            rootView.removeAmountIfNeeded()
        }
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    // MARK: Action

    @objc private func actionOnPayoutAccount() {
        presenter.selectPayoutAccount()
    }

    @objc private func actionOnWalletAccount() {
        presenter.selectWalletAccount()
    }

    @objc private func proceed() {
        presenter.proceed()
    }
}

extension SelectValidatorsConfirmViewController: SelectValidatorsConfirmViewProtocol {
    func didReceive(confirmationViewModel: SelectValidatorsConfirmViewModel) {
        self.confirmationViewModel = confirmationViewModel
        applyConfirmationViewModel()
        updateActionButton()
    }

    func didReceive(hintsViewModel: LocalizableResource<[String]>) {
        self.hintsViewModel = hintsViewModel
        applyHints()
    }

    func didReceive(amountViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.amountViewModel = amountViewModel
        applyAmountViewModel()
    }

    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.feeViewModel = feeViewModel
        applyFeeViewModel()
    }
}

extension SelectValidatorsConfirmViewController {
    func applyLocalization() {
        if isViewLoaded {
            applyLocalization()
            view.setNeedsLayout()
        }
    }
}
