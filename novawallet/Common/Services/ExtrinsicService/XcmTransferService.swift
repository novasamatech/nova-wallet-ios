import Foundation
import BigInt

typealias XmcTrasferFeeResult = Result<BigUInt, Error>
typealias XcmTransferEstimateFeeClosure = (XmcTrasferFeeResult) -> Void

protocol XcmTransferServiceProtocol {
    func estimateTransferFee(
        for assetId: AssetModel.Id,
        to destinationChainId: ChainModel.Id,
        using transfersRouter: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )
}

final class XcmTransferService {
    let originChain: ChainModel
    let wallet: MetaAccountModel
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        originChain: ChainModel,
        wallet: MetaAccountModel,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.originChain = originChain
        self.wallet = wallet
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}
