import UIKit
import SoraFoundation
import CommonWallet

final class StakingUnbondSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingUnbondSetupLayout

    let presenter: StakingUnbondSetupPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingUnbondSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    var uiFactory: UIFactoryProtocol = UIFactory()

    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var transferableViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var bondingDurationViewModel: LocalizableResource<String>?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingUnbondSetupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupAmountInputView()
        setupLocalization()
        updateActionButton()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingUnbond_v190(preferredLanguages: selectedLocale.rLanguages)

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonStakedPrefix(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.transferrableView.titleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.networkFeeView.locale = selectedLocale
        rootView.hintListView.locale = selectedLocale

        setupBalanceAccessoryView()
        applyTransferableViewModel()
        applyAssetViewModel()
        applyFeeViewModel()
        applyBondingDuration()
    }

    private func setupAmountInputView() {
        rootView.amountInputView.textField.delegate = self

        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = uiFactory.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupNavigationItem() {
        let closeBarItem = UIBarButtonItem(
            image: R.image.iconClose(),
            style: .plain,
            target: self,
            action: #selector(actionClose)
        )

        navigationItem.leftBarButtonItem = closeBarItem
    }

    private func applyAssetViewModel() {
        guard let viewModel = assetViewModel?.value(for: selectedLocale) else {
            return
        }

        let assetViewModel = AssetViewModel(symbol: viewModel.symbol, imageViewModel: viewModel.iconViewModel)

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }

    private func applyTransferableViewModel() {
        let viewModel = transferableViewModel?.value(for: selectedLocale)
        rootView.transferrableView.bind(viewModel: viewModel)
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    private func applyBondingDuration() {
        let bondingDuration = bondingDurationViewModel?.value(for: selectedLocale)
        rootView.hintListView.bondingDuration = bondingDuration
    }

    @objc private func actionClose() {
        presenter.close()
    }

    @objc private func actionProceed() {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.proceed()
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.actionButton.set(enabled: isEnabled)
    }
}

extension StakingUnbondSetupViewController: StakingUnbondSetupViewProtocol {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAssetViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFeeViewModel()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        amountInputViewModel?.observable.remove(observer: self)

        let inputViewModel = viewModel.value(for: selectedLocale)
        amountInputViewModel = inputViewModel
        amountInputViewModel?.observable.add(observer: self)

        rootView.amountInputView.bind(inputViewModel: inputViewModel)

        updateActionButton()
    }

    func didReceiveTransferable(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        transferableViewModel = viewModel
        applyTransferableViewModel()
    }

    func didReceiveBonding(duration: LocalizableResource<String>) {
        bondingDurationViewModel = duration
        applyBondingDuration()
    }
}

extension StakingUnbondSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension StakingUnbondSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension StakingUnbondSetupViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingUnbondSetupViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}
