import Foundation
import BigInt

struct XcmUnweightedTransferRequest {
    let origin: XcmTransferOrigin
    let destination: XcmTransferDestination
    let reserve: XcmTransferReserve
    let metadata: XcmTransferMetadata
    let amount: BigUInt

    var originChain: ChainModel {
        origin.chainAsset.chain
    }

    var reserveChain: ChainModel {
        reserve.chain
    }

    var destinationChain: ChainModel {
        destination.chain
    }

    var isNativeAssetTransferBetweenSystemChains: Bool {
        origin.chainAsset.isUtilityAsset &&
            origin.parachainId.isSystemParachain &&
            destination.parachainId.isSystemParachain
    }

    var isNonReserveTransfer: Bool {
        !isNativeAssetTransferBetweenSystemChains &&
            reserveChain.chainId != originChain.chainId && reserveChain.chainId != destinationChain.chainId
    }

    var paraIdAfterOrigin: ParaId? {
        isNonReserveTransfer ? reserve.parachainId : destination.parachainId
    }

    var paraIdBeforeDestination: ParaId? {
        isNonReserveTransfer ? reserve.parachainId : origin.parachainId
    }

    init(
        origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        reserve: XcmTransferReserve,
        metadata: XcmTransferMetadata,
        amount: BigUInt
    ) {
        self.origin = origin
        self.destination = destination
        self.reserve = reserve
        self.metadata = metadata
        self.amount = amount
    }

    func replacing(amount: Balance) -> XcmUnweightedTransferRequest {
        XcmUnweightedTransferRequest(
            origin: origin,
            destination: destination,
            reserve: reserve,
            metadata: metadata,
            amount: amount
        )
    }
}
