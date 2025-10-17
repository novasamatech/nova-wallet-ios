import UIKit
import Foundation_iOS

final class NominationPoolBondMoreSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = NominationPoolBondMoreSetupViewLayout

    let presenter: NominationPoolBondMoreSetupPresenterProtocol
    private var amountInputViewModel: AmountInputViewModelProtocol?

    init(
        presenter: NominationPoolBondMoreSetupPresenterProtocol,
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
        view = NominationPoolBondMoreSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.stakingBondMore_v190()

        rootView.amountView.titleView.text = R.string(
            preferredLanguages: languages
        ).localizable.walletSendAmountTitle()

        rootView.amountView.detailsTitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.commonAvailablePrefix()

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.commonContinue()

        rootView.networkFeeView.locale = selectedLocale

        setupAmountInputAccessoryView()
        updateProceedButtonState()
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

        updateProceedButtonState()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    private func updateProceedButtonState() {
        if !rootView.amountInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.transferSetupEnterAmount()
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()
        rootView.actionButton.invalidateLayout()
    }
}

extension NominationPoolBondMoreSetupViewController: NominationPoolBondMoreSetupViewProtocol {
    func didReceiveInput(viewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: viewModel)
        updateProceedButtonState()
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bind(viewModel: viewModel)
        updateProceedButtonState()
    }

    func didReceiveTransferable(viewModel: String?) {
        rootView.amountView.detailsValueLabel.text = viewModel
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintListView.bind(texts: viewModel)
    }

    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }
}

extension NominationPoolBondMoreSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension NominationPoolBondMoreSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension NominationPoolBondMoreSetupViewController: ImportantViewProtocol {}
