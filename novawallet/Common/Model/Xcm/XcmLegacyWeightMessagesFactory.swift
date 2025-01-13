import Foundation
import BigInt

protocol XcmLegacyWeightMessagesFactoryProtocol {
    func createWeightMessages(
        from chainAsset: ChainAsset,
        reserve: XcmTransferReserve,
        destination: XcmTransferDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfersProtocol
    ) throws -> XcmWeightMessages
}

enum XcmLegacyWeightMessagesFactoryError: Error {
    case unsupportedInstruction(String)
    case noInstructions(String)
    case noDestinationFee(origin: ChainAssetId, destination: ChainModel.Id)
    case noReserveFee(ChainAssetId)
    case noBaseWeight(ChainModel.Id)
}

final class XcmLegacyWeightMessagesFactory {
    
}

extension XcmLegacyWeightMessagesFactory: XcmLegacyWeightMessagesFactoryProtocol {
    
}
