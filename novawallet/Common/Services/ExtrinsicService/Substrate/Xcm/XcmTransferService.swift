import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

final class XcmTransferService {
    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol?

    let callDerivator: XcmCallDerivating
    let crosschainFeeCalculator: XcmCrosschainFeeCalculating

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol? = nil,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
        self.customFeeEstimatingFactory = customFeeEstimatingFactory

        callDerivator = XcmOneOfCallDerivator(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        crosschainFeeCalculator = XcmCrosschainFeeCalculator(
            chainRegistry: chainRegistry,
            callDerivator: callDerivator,
            operationQueue: operationQueue,
            wallet: wallet,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            customFeeEstimatingFactory: customFeeEstimatingFactory,
            logger: logger
        )
    }

    func createExtrinsicOperationFactory(
        for chain: ChainModel,
        chainAccount: ChainAccountResponse
    ) throws -> ExtrinsicOperationFactoryProtocol {
        let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)

        let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

        if let customFeeEstimatingFactory {
            return ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: substrateStorageFacade
            ).createOperationFactory(
                account: chainAccount,
                chain: chain,
                customFeeEstimatingFactory: customFeeEstimatingFactory
            )
        } else {
            return ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: substrateStorageFacade
            ).createOperationFactory(account: chainAccount, chain: chain)
        }
    }
}
