import UIKit
import Foundation_iOS

class CollatorStkBaseUnstakeSetupVC<V: CollatorStkBaseUnstakeSetupLayout>: UIViewController,
    ViewHolder, ImportantViewProtocol {
    typealias RootViewType = V

    let basePresenter: CollatorStkBaseUnstakeSetupPresenterProtocol

    private var collatorViewModel: AccountDetailsSelectionViewModel?

    init(
        basePresenter: CollatorStkBaseUnstakeSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.basePresenter = basePresenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = V()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        updateActionButtonState()

        onViewDidLoad()

        basePresenter.setup()
    }

    func onViewDidLoad() {}
    func onSetupLocalization() {}

    func updateActionButtonState() {
        if collatorViewModel == nil {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.parachainStakingHintSelectCollator()
            rootView.actionButton.invalidateLayout()

            return
        }

        if !rootView.amountInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.transferSetupEnterAmount()
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()
        rootView.actionButton.invalidateLayout()
    }
}

private extension CollatorStkBaseUnstakeSetupVC {
    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.stakingUnbond_v190()

        rootView.collatorTitleLabel.text = R.string(preferredLanguages: languages
        ).localizable.parachainStakingCollator()

        applyCollator(viewModel: collatorViewModel)

        rootView.amountView.titleView.text = R.string(preferredLanguages: languages
        ).localizable.walletSendAmountTitle()

        rootView.amountView.detailsTitleLabel.text = R.string(preferredLanguages: languages
        ).localizable.commonStakedPrefix()

        rootView.transferableView.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.walletBalanceAvailable()

        rootView.minStakeView.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.stakingMainMinimumStakeTitle()

        rootView.networkFeeView.locale = selectedLocale

        onSetupLocalization()

        updateActionButtonState()
    }

    private func applyAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }

    private func applyCollator(viewModel: AccountDetailsSelectionViewModel?) {
        if let viewModel = viewModel {
            rootView.collatorActionView.bind(viewModel: viewModel)
        } else {
            let emptyViewModel = AccountDetailsSelectionViewModel(
                displayAddress: DisplayAddressViewModel(
                    address: "",
                    name: R.string(preferredLanguages: selectedLocale.rLanguages
                    ).localizable.parachainStakingSelectCollator(),
                    imageViewModel: nil
                ),
                details: nil
            )

            rootView.collatorActionView.bind(viewModel: emptyViewModel)
        }
    }

    private func setupHandlers() {
        let selectCollatorAction = UIAction { [weak self] _ in
            self?.basePresenter.selectCollator()
        }

        rootView.collatorActionView.addAction(selectCollatorAction, for: .touchUpInside)

        let proceedAction = UIAction { [weak self] _ in
            self?.basePresenter.proceed()
        }

        rootView.actionButton.addAction(proceedAction, for: .touchUpInside)
    }
}

extension CollatorStkBaseUnstakeSetupVC: CollatorStkBaseUnstakeSetupViewProtocol {
    func didReceiveCollator(viewModel: AccountDetailsSelectionViewModel?) {
        collatorViewModel = viewModel

        applyCollator(viewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        applyAssetBalance(viewModel: viewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    func didReceiveMinStake(viewModel: LoadableViewModelState<BalanceViewModelProtocol>?) {
        if let viewModel {
            rootView.minStakeView.isHidden = false

            rootView.minStakeView.bind(viewModel: viewModel.value)

        } else {
            rootView.minStakeView.isHidden = true
        }
    }

    func didReceiveTransferable(viewModel: BalanceViewModelProtocol?) {
        rootView.transferableView.bind(viewModel: viewModel)
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintListView.bind(texts: viewModel)
    }

    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)

        updateActionButtonState()
    }
}

extension CollatorStkBaseUnstakeSetupVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
