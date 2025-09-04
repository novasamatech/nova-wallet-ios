import UIKit
import Foundation_iOS

final class NPoolsUnstakeSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = NPoolsUnstakeSetupViewLayout

    let presenter: NPoolsUnstakeSetupPresenterProtocol

    init(presenter: NPoolsUnstakeSetupPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NPoolsUnstakeSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.stakingUnbond_v190()

        rootView.amountView.titleView.text = R.string(preferredLanguages: languages).localizable.walletSendAmountTitle()

        rootView.amountView.detailsTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonStakedPrefix()

        rootView.transferableView.titleLabel.text = R.string(preferredLanguages: languages).localizable.walletBalanceAvailable()

        rootView.networkFeeView.locale = selectedLocale

        setupAmountInputAccessoryView()
        updateActionButtonState()
    }

    private func updateActionButtonState() {
        if !rootView.amountInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .transferSetupEnterAmount(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonContinue()
        rootView.actionButton.invalidateLayout()
    }

    private func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupHandlers() {
        rootView.amountInputView.addTarget(
            self,
            action: #selector(actionAmountChange),
            for: .editingChanged
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )
    }

    @objc func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)

        updateActionButtonState()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }
}

extension NPoolsUnstakeSetupViewController: NPoolsUnstakeSetupViewProtocol {
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }

    func didReceiveInput(viewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    func didReceiveTransferable(viewModel: BalanceViewModelProtocol?) {
        rootView.transferableView.bind(viewModel: viewModel)
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintListView.bind(texts: viewModel)
    }
}

extension NPoolsUnstakeSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension NPoolsUnstakeSetupViewController: ImportantViewProtocol {}

extension NPoolsUnstakeSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
