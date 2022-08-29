import UIKit
import SoraFoundation
import CommonWallet

final class TransferSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = TransferSetupViewLayout

    let presenter: TransferSetupPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    init(
        presenter: TransferSetupPresenterProtocol,
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
        view = TransferSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
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

        rootView.recepientInputView.scanButton.addTarget(
            self,
            action: #selector(actionRecepientScan),
            for: .touchUpInside
        )

        rootView.yourWalletsView.actionControl.addTarget(
            self,
            action: #selector(actionYourWallets),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.recepientTitleLabel.text = R.string.localizable.commonRecipient(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.recepientInputView.locale = selectedLocale
        rootView.originFeeView.locale = selectedLocale

        rootView.networkContainerView.locale = selectedLocale

        setupCrossChainLocalization()

        setupAmountInputAccessoryView(for: selectedLocale)

        updateActionButtonState()

        let selectYourWalletTitle = R.string.localizable.assetsSelectSendYourWallets(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.yourWalletsView.bind(model: .init(
            name: selectYourWalletTitle,
            image: R.image.iconUsers()
        ))
    }

    private func setupCrossChainLocalization() {
        rootView.crossChainFeeView?.locale = selectedLocale
    }

    private func setupAmountInputAccessoryView(for locale: Locale) {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: locale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func updateActionButtonState() {
        if !rootView.recepientInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .transferSetupEnterAddress(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.invalidateLayout()

            return
        }

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

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )
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

    @objc func actionRecepientScan() {
        presenter.scanRecepientCode()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }

    @objc func actionChangeDestination() {
        presenter.changeDestinationChain()
    }

    @objc func actionSendMyself() {
        presenter.applyMyselfRecepient()
    }

    @objc func actionYourWallets() {
        presenter.didTapOnYourWallets()
    }
}

extension TransferSetupViewController: TransferSetupViewProtocol {
    func didSwitchCrossChain() {
        rootView.switchCrossChain()
        setupCrossChainLocalization()
    }

    func didSwitchOnChain() {
        rootView.switchOnChain()
    }

    func changeYourWalletsViewState(isHidden: Bool) {
        rootView.yourWalletsView.isHidden = isHidden
    }

    func didReceiveOriginChain(_ originChain: ChainAssetViewModel, destinationChain: NetworkViewModel?) {
        let assetViewModel = originChain.assetViewModel
        let viewModel = TransferNetworkContainerViewModel(
            assetSymbol: assetViewModel.symbol,
            originNetwork: originChain.networkViewModel,
            destNetwork: destinationChain
        )

        rootView.networkContainerView.bind(viewModel: viewModel)

        rootView.networkContainerView.destinationNetworkView?.actionControl.addTarget(
            self,
            action: #selector(actionChangeDestination),
            for: .touchUpInside
        )
    }

    func didCompleteDestinationSelection() {
        rootView.networkContainerView.destinationNetworkView?.actionControl.deactivate(animated: true)
    }

    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel) {
        rootView.amountInputView.bind(assetViewModel: viewModel.assetViewModel)
    }

    func didReceiveTransferableBalance(viewModel: String) {
        let detailsTitleLabel = rootView.amountView.detailsTitleLabel
        let detailsValueLabel = rootView.amountView.detailsValueLabel

        detailsTitleLabel.text = R.string.localizable.commonTransferablePrefix(
            preferredLanguages: selectedLocale.rLanguages
        )

        detailsValueLabel.text = viewModel
    }

    func didReceiveOriginFee(viewModel: BalanceViewModelProtocol?) {
        rootView.originFeeView.bind(viewModel: viewModel)
    }

    func didReceiveCrossChainFee(viewModel: BalanceViewModelProtocol?) {
        rootView.crossChainFeeView?.bind(viewModel: viewModel)
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

    func didReceiveCanSendMySelf(_ canSendMySelf: Bool) {
        rootView.recepientInputView.showsMyself = canSendMySelf

        rootView.recepientInputView.mySelfButton?.addTarget(
            self,
            action: #selector(actionSendMyself),
            for: .touchUpInside
        )
    }
}

extension TransferSetupViewController {
    func applyLocalization() {
        if isSetup {
            setupLocalization()
        }
    }
}

extension TransferSetupViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if rootView.recepientInputView.textField.isFirstResponder {
                targetView = rootView.recepientInputView
            } else if rootView.amountInputView.textField.isFirstResponder {
                targetView = rootView.amountInputView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

extension TransferSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}
