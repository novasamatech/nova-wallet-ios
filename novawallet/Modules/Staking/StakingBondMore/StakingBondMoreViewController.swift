import UIKit
import SoraFoundation
import CommonWallet

final class StakingBondMoreViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingBondMoreViewLayout

    let presenter: StakingBondMorePresenterProtocol

    private var amountInputViewModel: AmountInputViewModelProtocol?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingBondMorePresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
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
        view = StakingBondMoreViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAmountInputView()
        setupActionButton()
        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.stakingBondMore_v190(
            preferredLanguages: languages
        )

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: languages
        )

        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonTransferablePrefix(
            preferredLanguages: languages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )

        rootView.hintView.detailsLabel.text = R.string.localizable.stakingHintRewardBondMore_v2_2_0(
            preferredLanguages: languages
        )

        rootView.networkFeeView.locale = selectedLocale
    }

    private func setupAmountInputView() {
        rootView.amountInputView.textField.keyboardType = .decimalPad
        rootView.amountInputView.textField.delegate = self

        let accessoryView = UIFactory().createAmountAccessoryView(for: self, locale: selectedLocale)
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupActionButton() {
        rootView.actionButton.addTarget(self, action: #selector(handleActionButton), for: .touchUpInside)
    }

    @objc
    private func handleActionButton() {
        presenter.handleContinueAction()
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)
        rootView.actionButton.set(enabled: isEnabled)
    }

    private func applyAsset() {
        if let viewModel = assetViewModel?.value(for: selectedLocale) {
            let assetViewModel = AssetViewModel(
                symbol: viewModel.symbol,
                imageViewModel: viewModel.iconViewModel
            )

            rootView.amountInputView.bind(assetViewModel: assetViewModel)
            rootView.amountInputView.bind(priceViewModel: viewModel.price)

            rootView.amountView.detailsValueLabel.text = viewModel.balance
        }
    }

    private func applyFee() {
        let fee = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeView.bind(viewModel: fee)
    }
}

extension StakingBondMoreViewController: StakingBondMoreViewProtocol {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()

        updateActionButton()
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAsset()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        let concreteViewModel = viewModel.value(for: selectedLocale)

        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = concreteViewModel

        rootView.amountInputView.bind(inputViewModel: concreteViewModel)
        concreteViewModel.observable.add(observer: self)

        updateActionButton()
    }
}

extension StakingBondMoreViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension StakingBondMoreViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension StakingBondMoreViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingBondMoreViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}
