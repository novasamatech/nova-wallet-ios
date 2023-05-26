import Foundation
import CommonWallet

protocol TransferSetupPresenterFactoryProtocol {
    func createOnChainPresenter(
        for chainAsset: ChainAsset,
        initialState: TransferSetupInputState,
        view: TransferSetupChildViewProtocol
    ) -> TransferSetupChildPresenterProtocol?

    func createCrossChainPresenter(
        for originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        xcmTransfers: XcmTransfers,
        initialState: TransferSetupInputState,
        view: TransferSetupChildViewProtocol
    ) -> TransferSetupChildPresenterProtocol?
}

final class TransferSetupPresenterFactory: TransferSetupPresenterFactoryProtocol {
    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.logger = logger
    }
}
