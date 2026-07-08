import UIKit
import Foundation_iOS

/// Subtensor-specific confirm view controller. Mirrors `CollatorStakingConfirmViewController`
/// but uses `SubtensorStakingConfirmViewLayout` (which adds the Nova-fee row) and conforms
/// to `SubtensorStakingConfirmViewProtocol` instead of the shared collator protocol.
///
/// Both stake AND unstake confirm factories point at this class.
final class SubtensorStakingConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorStakingConfirmViewLayout

    let presenter: CollatorStakingConfirmPresenterProtocol

    let localizableTitle: LocalizableResource<String>
    let localizableCollatorLabel: LocalizableResource<String>

    init(
        presenter: CollatorStakingConfirmPresenterProtocol,
        localizableTitle: LocalizableResource<String>,
        localizableCollatorLabel: LocalizableResource<String> = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingCollator()
        },
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizableTitle = localizableTitle
        self.localizableCollatorLabel = localizableCollatorLabel

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorStakingConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = localizableTitle.value(for: selectedLocale)

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonConfirm()

        rootView.walletCell.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonWallet()

        rootView.accountCell.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonAccount()

        rootView.networkFeeCell.rowContentView.locale = selectedLocale
        rootView.novaFeeCell.rowContentView.locale = selectedLocale

        rootView.novaFeeDisclaimerLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.subtensorNovaFeeDisclaimer(SubtensorStakingConstants.novaFeePercentDisplay)

        rootView.collatorCell.titleLabel.text = localizableCollatorLabel.value(for: selectedLocale)
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )

        rootView.accountCell.addTarget(
            self,
            action: #selector(actionSelectAccount),
            for: .touchUpInside
        )

        rootView.collatorCell.addTarget(
            self,
            action: #selector(actionSelectCollator),
            for: .touchUpInside
        )
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }

    @objc private func actionSelectCollator() {
        presenter.selectCollator()
    }
}

// MARK: - SubtensorStakingConfirmViewProtocol

extension SubtensorStakingConfirmViewController: SubtensorStakingConfirmViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol) {
        rootView.amountView.bind(viewModel: viewModel)
    }

    func didReceiveWallet(viewModel: DisplayWalletViewModel) {
        rootView.walletCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveCollator(viewModel: DisplayAddressViewModel) {
        rootView.collatorCell.titleLabel.lineBreakMode = viewModel.lineBreakMode
        rootView.collatorCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintListView.bind(texts: viewModel)
    }

    func didReceiveNovaFee(viewModel: BalanceViewModelProtocol?) {
        if let viewModel {
            rootView.novaFeeCell.rowContentView.bind(viewModel: viewModel)
            rootView.novaFeeCell.isHidden = false
        } else {
            rootView.novaFeeCell.isHidden = true
        }
    }

    func didReceiveNovaFeeDisclaimer(visible: Bool) {
        rootView.novaFeeDisclaimerLabel.isHidden = !visible
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

// MARK: - Localizable

extension SubtensorStakingConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
