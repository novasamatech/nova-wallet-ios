import Foundation
import BigInt
import SoraFoundation

final class TransferSetupPresenter {
    weak var view: TransferSetupViewProtocol?
    let wireframe: TransferSetupWireframeProtocol
    let interactor: TransferSetupInteractorInputProtocol

    let chainAsset: ChainAsset

    private(set) var recepientAddress: AccountAddress?

    private(set) var senderSendingAssetBalance: AssetBalance?
    private(set) var senderUtilityAssetBalance: AssetBalance?

    private(set) var recepientSendingAssetBalance: AssetBalance?
    private(set) var recepientUtilityAssetBalance: AssetBalance?

    private(set) var sendingAssetPrice: PriceData?
    private(set) var utilityAssetPrice: PriceData?

    private(set) var fee: BigUInt?

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol
    let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

    var isUtilityTransfer: Bool {
        chainAsset.chain.utilityAssets().first?.assetId == chainAsset.asset.assetId
    }

    init(
        interactor: TransferSetupInteractorInputProtocol,
        wireframe: TransferSetupWireframeProtocol,
        chainAsset: ChainAsset,
        recepientAddress: AccountAddress?,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.recepientAddress = recepientAddress
        self.networkViewModelFactory = networkViewModelFactory
        self.sendingBalanceViewModelFactory = sendingBalanceViewModelFactory
        self.utilityBalanceViewModelFactory = utilityBalanceViewModelFactory

        self.localizationManager = localizationManager
    }

    private func updateChainAssetViewModel() {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)

        let assetIconUrl = chainAsset.asset.icon ?? chainAsset.chain.icon
        let assetIconViewModel = RemoteImageViewModel(url: assetIconUrl)

        let assetViewModel = AssetViewModel(
            symbol: chainAsset.asset.symbol,
            imageViewModel: assetIconViewModel
        )

        let viewModel = ChainAssetViewModel(
            networkViewModel: networkViewModel,
            assetViewModel: assetViewModel
        )

        view?.didReceiveChainAsset(viewModel: viewModel)
    }

    private func updateFeeView() {
        let optAssetInfo = chainAsset.chain.utilityAssets().first?.displayInfo
        if let fee = fee, let assetInfo = optAssetInfo {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModelFactory = utilityBalanceViewModelFactory ?? sendingBalanceViewModelFactory
            let priceData = isUtilityTransfer ? sendingAssetPrice : utilityAssetPrice

            let viewModel = viewModelFactory.balanceFromPrice(
                feeDecimal,
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func updateTransferableBalance() {
        if let senderSendingAssetBalance = senderSendingAssetBalance {
            let precision = chainAsset.asset.displayInfo.assetPrecision
            let balanceDecimal = Decimal.fromSubstrateAmount(
                senderSendingAssetBalance.transferable,
                precision: precision
            ) ?? 0

            let viewModel = sendingBalanceViewModelFactory.balanceFromPrice(
                balanceDecimal,
                priceData: nil
            ).value(for: selectedLocale).amount

            view?.didReceiveTransferableBalance(viewModel: viewModel)
        }
    }
}

extension TransferSetupPresenter: TransferSetupPresenterProtocol {
    func setup() {
        updateChainAssetViewModel()
        updateFeeView()

        interactor.setup()
    }
}

extension TransferSetupPresenter: TransferSetupInteractorOutputProtocol {
    func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance?) {
        senderSendingAssetBalance = balance

        updateTransferableBalance()
    }

    func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance?) {
        senderUtilityAssetBalance = balance
    }

    func didReceiveSendingAssetRecepientBalance(_ balance: AssetBalance?) {
        recepientSendingAssetBalance = balance
    }

    func didReceiveUtilityAssetRecepientBalance(_ balance: AssetBalance?) {
        recepientUtilityAssetBalance = balance
    }

    func didReceiveFee(_ fee: BigUInt) {
        self.fee = fee

        updateFeeView()
    }

    func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        sendingAssetPrice = priceData

        if isUtilityTransfer {
            updateFeeView()
        }
    }

    func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        utilityAssetPrice = priceData

        updateFeeView()
    }

    func didReceiveUtilityAssetMinBalance(_: BigUInt) {}

    func didReceiveSendingAssetMinBalance(_: BigUInt) {}

    func didCompleteSetup() {
        interactor.estimateFee(for: 0, recepient: recepientAddress)
    }

    func didReceiveSetup(error _: Error) {}
}

extension TransferSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateChainAssetViewModel()
            updateFeeView()
            updateTransferableBalance()
        }
    }
}
