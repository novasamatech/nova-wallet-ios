import Foundation_iOS
import UIKit

final class SubtensorUnstakeConfirmVC: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorStakingConfirmViewLayout

    let presenter: CollatorStkUnstakeConfirmPresenterProtocol
    let statics: CollatorStakingDelegateStatics

    init(
        presenter: CollatorStkUnstakeConfirmPresenterProtocol,
        statics: CollatorStakingDelegateStatics,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.statics = statics

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
}

private extension SubtensorUnstakeConfirmVC {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.stakingUnbond_v190()

        rootView.actionButton.imageWithTitleView?.title = strings.commonConfirm()

        rootView.walletCell.titleLabel.text = strings.commonWallet()
        rootView.accountCell.titleLabel.text = strings.commonAccount()

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.receiveCell.titleLabel.text = strings.stakingSubtensorQuoteReceiveTitle()
        rootView.poolFeeCell.titleLabel.text = strings.stakingSubtensorQuotePoolFeeTitle()
        rootView.priceImpactCell.titleLabel.text = strings.stakingSubtensorQuotePriceImpactTitle()
        rootView.slippageCell.titleLabel.text = strings.swapsSetupSlippage()

        rootView.collatorCell.titleLabel.text = statics.delegateTitle.value(for: selectedLocale)
    }

    func setupHandlers() {
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

    @objc func actionConfirm() {
        presenter.confirm()
    }

    @objc func actionSelectAccount() {
        presenter.selectAccount()
    }

    @objc func actionSelectCollator() {
        presenter.selectCollator()
    }
}

extension SubtensorUnstakeConfirmVC: SubtensorUnstakeConfirmViewProtocol {
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

    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?) {
        rootView.quoteTableView.isHidden = viewModel == nil

        guard let viewModel else {
            return
        }

        rootView.receiveCell.bind(details: viewModel.receive)
        rootView.poolFeeCell.bind(details: viewModel.poolFee)
        rootView.priceImpactCell.bind(details: viewModel.priceImpact)

        rootView.priceImpactCell.detailsLabel.textColor = viewModel.isImpactHigh
            ? R.color.colorTextNegative()
            : R.color.colorTextPrimary()
    }

    func didReceiveSlippage(viewModel: String?) {
        rootView.slippageCell.isHidden = viewModel == nil
        rootView.slippageCell.bind(details: viewModel ?? "")
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension SubtensorUnstakeConfirmVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
