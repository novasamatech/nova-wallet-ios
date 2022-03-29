import Foundation
import SoraFoundation
import SubstrateSdk
import BigInt

final class TransferConfirmPresenter: TransferPresenter {
    weak var view: TransferConfirmViewProtocol?
    let wireframe: TransferConfirmWireframeProtocol
    let interactor: TransferConfirmInteractorInputProtocol

    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol

    let recepientAccountAddress: AccountAddress
    let wallet: MetaAccountModel
    let amount: Decimal

    private lazy var walletIconGenerator = NovaIconGenerator()

    init(
        interactor: TransferConfirmInteractorInputProtocol,
        wireframe: TransferConfirmWireframeProtocol,
        wallet: MetaAccountModel,
        recepient: AccountAddress,
        amount: Decimal,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        recepientAccountAddress = recepient
        self.amount = amount
        self.displayAddressViewModelFactory = displayAddressViewModelFactory

        super.init(
            chainAsset: chainAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            senderAccountAddress: senderAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        self.localizationManager = localizationManager
    }

    private func provideNetworkViewModel() {
        let viewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        view?.didReceiveNetwork(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        let name = wallet.name

        let icon = try? walletIconGenerator.generateFromAccountId(wallet.substrateAccountId)
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }
        let viewModel = StackCellViewModel(details: name, imageViewModel: iconViewModel)
        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func provideSenderViewModel() {
        let displayAddress = DisplayAddress(address: senderAccountAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveSender(viewModel: viewModel)
    }

    private func provideRecepientViewModel() {
        let displayAddress = DisplayAddress(address: recepientAccountAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveRecepient(viewModel: viewModel)
    }

    private func provideNetworkFeeViewModel() {
        let optAssetInfo = chainAsset.chain.utilityAssets().first?.displayInfo
        if let fee = fee, let assetInfo = optAssetInfo {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModelFactory = utilityBalanceViewModelFactory ?? sendingBalanceViewModelFactory
            let priceData = isUtilityTransfer ? sendingAssetPrice : utilityAssetPrice

            let viewModel = viewModelFactory.balanceFromPrice(feeDecimal, priceData: priceData)
                .value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAmountViewModel() {
        let viewModel = sendingBalanceViewModelFactory.spendingAmountFromPrice(
            amount,
            priceData: sendingAssetPrice
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: chainAsset.chain.explorers,
            locale: selectedLocale
        )
    }

    // MARK: Subsclass

    override func refreshFee() {
        let assetInfo = chainAsset.assetDisplayInfo

        guard let amountValue = amount.toSubstrateAmount(precision: assetInfo.assetPrecision) else {
            return
        }

        interactor.estimateFee(for: amountValue, recepient: recepientAccountAddress)
    }

    override func askFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshFee()
        }
    }

    override func didReceiveFee(result: Result<BigUInt, Error>) {
        super.didReceiveFee(result: result)

        if case .success = result {
            provideNetworkFeeViewModel()
        }
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        if isUtilityTransfer {
            provideNetworkFeeViewModel()
        }

        provideAmountViewModel()
    }

    override func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        super.didReceiveUtilityAssetPrice(priceData)

        provideNetworkFeeViewModel()
    }

    override func didCompleteSetup() {
        super.didCompleteSetup()

        refreshFee()

        interactor.change(recepient: recepientAccountAddress)
    }

    override func didReceiveError(_ error: Error) {
        super.didReceiveError(error)

        view?.didStopLoading()

        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
    }
}

extension TransferConfirmPresenter: TransferConfirmPresenterProtocol {
    func setup() {
        provideAmountViewModel()
        provideNetworkViewModel()
        provideWalletViewModel()
        provideSenderViewModel()
        provideNetworkFeeViewModel()
        provideRecepientViewModel()

        interactor.setup()
    }

    func submit() {
        guard let amountValue = amount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) else {
            return
        }

        let validators: [DataValidating] = baseValidators(
            for: amount,
            recepientAddress: recepientAccountAddress,
            selectedLocale: selectedLocale
        )

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(
                amount: amountValue,
                recepient: strongSelf.recepientAccountAddress,
                lastFee: strongSelf.fee
            )
        }
    }

    func showSenderActions() {
        presentOptions(for: senderAccountAddress)
    }

    func showRecepientActions() {
        presentOptions(for: recepientAccountAddress)
    }
}

extension TransferConfirmPresenter: TransferConfirmInteractorOutputProtocol {
    func didCompleteSubmition() {
        view?.didStopLoading()
        wireframe.complete(on: view, locale: selectedLocale)
    }
}

extension TransferConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideNetworkFeeViewModel()
        }
    }
}
