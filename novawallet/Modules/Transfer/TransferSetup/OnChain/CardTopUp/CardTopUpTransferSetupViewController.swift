import UIKit
import Foundation_iOS

final class CardTopUpTransferSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = CardTopUpTransferSetupViewLayout

    let presenter: TransferSetupPresenterProtocol

    let titleResource: LocalizableResource<String>

    init(
        presenter: TransferSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        titleResource: LocalizableResource<String>
    ) {
        self.presenter = presenter
        self.titleResource = titleResource

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CardTopUpTransferSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.recepientInputView.addTarget(
            self,
            action: #selector(actionRecepientAddressChange),
            for: .editingChanged
        )

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

    private func setupLocalization() {
        rootView.title.text = titleResource.value(for: selectedLocale)

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()

        rootView.recepientTitleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonRecipient()

        rootView.amountView.titleView.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.walletSendAmountTitle()

        rootView.originFeeView.titleButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonNetworkFee()

        rootView.recepientInputView.locale = selectedLocale

        updateActionButtonState()
    }

    private func updateActionButtonState() {
        if !rootView.recepientInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.transferSetupEnterAddress()
            rootView.actionButton.invalidateLayout()

            return
        }

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

    @objc func actionRecepientAddressChange() {
        let partialAddress = rootView.recepientInputView.textField.text ?? ""
        presenter.updateRecepient(partialAddress: partialAddress)

        updateActionButtonState()
    }

    @objc func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)

        updateActionButtonState()
    }

    @objc func actionProceed() {
        if rootView.recepientInputView.textField.isFirstResponder {
            let partialAddress = rootView.recepientInputView.textField.text ?? ""
            presenter.complete(recipient: partialAddress)

            rootView.recepientInputView.textField.resignFirstResponder()
        }

        presenter.proceed()
    }

    // TODO: Use when design will be ready
    @objc func actionYourWallets() {
        presenter.didTapOnYourWallets()
    }
}

extension CardTopUpTransferSetupViewController: CardTopUpTransferSetupViewProtocol {
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel) {
        rootView.amountInputView.bind(assetViewModel: viewModel.assetViewModel)
    }

    func didReceiveTransferableBalance(viewModel: String) {
        let detailsTitleLabel = rootView.amountView.detailsTitleLabel
        let detailsValueLabel = rootView.amountView.detailsValueLabel

        detailsTitleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonTransferablePrefix()

        detailsValueLabel.text = viewModel
    }

    func didReceiveOriginFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.originFeeView.bind(loadableViewModel: viewModel)
    }

    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)

        updateActionButtonState()
    }

    func didReceiveAmountInputPrice(viewModel: String?) {
        rootView.amountInputView.bind(priceViewModel: viewModel)
    }

    func didReceiveAccountState(viewModel: AccountFieldStateViewModel) {
        rootView.recepientInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveAccountInput(viewModel: InputViewModelProtocol) {
        rootView.recepientInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }
}

extension CardTopUpTransferSetupViewController {
    func applyLocalization() {
        if isSetup {
            setupLocalization()
        }
    }
}
