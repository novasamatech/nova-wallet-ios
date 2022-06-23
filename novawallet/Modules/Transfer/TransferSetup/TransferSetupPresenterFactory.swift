import Foundation
import CommonWallet

protocol TransferSetupPresenterFactoryProtocol {
    func createOnChainPresenter(
        for chainAsset: ChainAsset,
        initialState: TransferSetupInputState,
        view: TransferSetupViewProtocol
    ) -> TransferSetupChildPresenterProtocol?

    func createCrossChainPresenter(
        for originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        xcmTransfers: XcmTransfers,
        initialState: TransferSetupInputState,
        view: TransferSetupViewProtocol
    ) -> TransferSetupChildPresenterProtocol?
}

final class TransferSetupPresenterFactory: TransferSetupPresenterFactoryProtocol {
    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        commandFactory: WalletCommandFactoryProtocol?,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.commandFactory = commandFactory
        self.eventCenter = eventCenter
        self.logger = logger
    }
}
