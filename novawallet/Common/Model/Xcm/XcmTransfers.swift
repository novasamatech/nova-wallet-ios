import Foundation
import BigInt

struct XcmTransfers {
    let legacyTransfers: XcmLegacyTransfers
    let dynamicTransfers: XcmDynamicTransfers

    let indexedByOrigins: [ChainAssetId: Set<ChainAssetId>]
    let indexedByDestinations: [ChainAssetId: Set<ChainAssetId>]

    init(
        legacyTransfers: XcmLegacyTransfers,
        dynamicTransfers: XcmDynamicTransfers
    ) {
        self.legacyTransfers = legacyTransfers
        self.dynamicTransfers = dynamicTransfers

        var indexedByOrigins: [ChainAssetId: Set<ChainAssetId>] = [:]
        var indexedByDestinations: [ChainAssetId: Set<ChainAssetId>] = [:]

        let allChains: [XcmTransferChainProtocol] = legacyTransfers.getChains() + dynamicTransfers.getChains()

        for chain in allChains {
            for asset in chain.getAssets() {
                let origin = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                for transfer in asset.getDestinations() {
                    let destination = ChainAssetId(chainId: transfer.chainId, assetId: transfer.assetId)

                    if indexedByOrigins[origin] == nil {
                        indexedByOrigins[origin] = [destination]
                    } else {
                        indexedByOrigins[origin]?.insert(destination)
                    }

                    if indexedByDestinations[destination] == nil {
                        indexedByDestinations[destination] = [origin]
                    } else {
                        indexedByDestinations[destination]?.insert(origin)
                    }
                }
            }
        }

        self.indexedByOrigins = indexedByOrigins
        self.indexedByDestinations = indexedByDestinations
    }
}

enum XcmTransfersError: Error {
    case noTransfer(ChainAssetId, ChainModel.Id)
    case noReserve(ChainAssetId)
    case noInstructions(String)
    case deliveryFeeNotAvailable
    case noDestinationFee(origin: ChainAssetId, destination: ChainModel.Id)
    case noBaseWeight(ChainModel.Id)
}

private extension XcmTransfers {
    func checkLegacyDeliveryFee(
        from originChain: ChainModel,
        destinationChain: ChainModel
    ) -> Bool {
        do {
            let deliveryFee = try legacyTransfers.deliveryFee(from: originChain.chainId)

            if !destinationChain.isRelaychain {
                return deliveryFee?.toParachain?.alwaysHoldingPays ?? false
            } else if !originChain.isRelaychain {
                return deliveryFee?.toParent?.alwaysHoldingPays ?? false
            } else {
                return false
            }
        } catch {
            return true
        }
    }

    func getLegacyDestinationFeeParams(
        for chainAsset: ChainAsset,
        destinationChain: ChainModel
    ) throws -> XcmTransferMetadata.LegacyFeeDetails {
        guard let destinationFee = legacyTransfers.transfer(
            from: chainAsset.chainAssetId,
            destinationChainId: destinationChain.chainId
        )?.destination.fee else {
            throw XcmTransfersError.noTransfer(
                chainAsset.chainAssetId,
                destinationChain.chainId
            )
        }

        guard
            let destinationInstructions = legacyTransfers.instructions(
                for: destinationFee.instructions
            ) else {
            throw XcmTransfersError.noInstructions(destinationFee.instructions)
        }

        guard let destinationBaseWeight = legacyTransfers.baseWeight(for: destinationChain.chainId) else {
            throw XcmTransfersError.noBaseWeight(destinationChain.chainId)
        }

        return XcmTransferMetadata.LegacyFeeDetails(
            instructions: destinationInstructions,
            mode: destinationFee,
            baseWeight: destinationBaseWeight
        )
    }

    func getLegacyReserveFeeParams(
        for originChainAsset: ChainAsset
    ) throws -> XcmTransferMetadata.LegacyFeeDetails? {
        guard let reserveFee = legacyTransfers.reserveFee(from: originChainAsset.chainAssetId) else {
            return nil
        }

        guard let reserveFeeInstructions = legacyTransfers.instructions(
            for: reserveFee.instructions
        ) else {
            throw XcmTransfersError.noInstructions(reserveFee.instructions)
        }

        guard let reserveId = legacyTransfers.getReserveChainId(for: originChainAsset.chainAssetId) else {
            throw XcmTransfersError.noReserve(originChainAsset.chainAssetId)
        }

        guard let reserveBaseWeight = legacyTransfers.baseWeight(for: reserveId) else {
            throw XcmTransfersError.noBaseWeight(reserveId)
        }

        return XcmTransferMetadata.LegacyFeeDetails(
            instructions: reserveFeeInstructions,
            mode: reserveFee,
            baseWeight: reserveBaseWeight
        )
    }

    func getLegacyFeeParams(
        for chainAsset: ChainAsset,
        destinationChain: ChainModel
    ) throws -> XcmTransferMetadata.LegacyFee {
        let destinationDetails = try getLegacyDestinationFeeParams(
            for: chainAsset,
            destinationChain: destinationChain
        )

        let reserveDetails = try getLegacyReserveFeeParams(for: chainAsset)
        let originDelivery = try legacyTransfers.deliveryFee(from: chainAsset.chain.chainId)

        guard let reserveId = legacyTransfers.getReserveChainId(for: chainAsset.chainAssetId) else {
            throw XcmTransfersError.noReserve(chainAsset.chainAssetId)
        }

        let reserveDeliveryFee = try legacyTransfers.deliveryFee(from: reserveId)

        return XcmTransferMetadata.LegacyFee(
            destinationExecution: destinationDetails,
            reserveExecution: reserveDetails,
            originDelivery: originDelivery,
            reserveDelivery: reserveDeliveryFee
        )
    }

    func getLegacyTransferMetadata(
        for chainAsset: ChainAsset,
        destinationChain: ChainModel
    ) throws -> XcmTransferMetadata? {
        guard
            let transfer = legacyTransfers.transfer(
                from: chainAsset.chainAssetId,
                destinationChainId: destinationChain.chainId
            ) else {
            return nil
        }

        guard
            let reservePath = legacyTransfers.getReservePath(for: chainAsset.chainAssetId),
            let reserveId = legacyTransfers.getReserveChainId(for: chainAsset.chainAssetId) else {
            throw XcmTransfersError.noReserve(chainAsset.chainAssetId)
        }

        let paysDeliveryFee = checkLegacyDeliveryFee(
            from: chainAsset.chain,
            destinationChain: destinationChain
        )

        let feeParams = try getLegacyFeeParams(
            for: chainAsset,
            destinationChain: destinationChain
        )

        return XcmTransferMetadata(
            callType: transfer.type,
            reserve: XcmTransferMetadata.Reserve(
                reserveId: reserveId,
                path: reservePath
            ),
            fee: .legacy(feeParams),
            paysDeliveryFee: paysDeliveryFee,
            supportsXcmExecute: false
        )
    }

    func getDynamicTransferMetadata(
        for chainAsset: ChainAsset,
        destinationChain: ChainModel
    ) throws -> XcmTransferMetadata? {
        guard
            let transfer = dynamicTransfers.transfer(
                from: chainAsset.chainAssetId,
                destinationChainId: destinationChain.chainId
            ) else {
            return nil
        }

        guard
            let reservePath = dynamicTransfers.getReservePath(for: chainAsset),
            let reserveId = dynamicTransfers.getReserveChainId(for: chainAsset) else {
            throw XcmTransfersError.noReserve(chainAsset.chainAssetId)
        }

        return XcmTransferMetadata(
            callType: transfer.type,
            reserve: XcmTransferMetadata.Reserve(
                reserveId: reserveId,
                path: reservePath
            ),
            fee: .dynamic,
            paysDeliveryFee: transfer.hasDeliveryFee ?? false,
            supportsXcmExecute: transfer.supportsXcmExecute ?? false
        )
    }
}

extension XcmTransfers {
    func getTransferMetadata(
        for chainAsset: ChainAsset,
        destinationChain: ChainModel
    ) throws -> XcmTransferMetadata {
        if let dynamicMetadata = try getDynamicTransferMetadata(
            for: chainAsset,
            destinationChain: destinationChain
        ) {
            return dynamicMetadata
        }

        if let legacyMetadata = try getLegacyTransferMetadata(
            for: chainAsset,
            destinationChain: destinationChain
        ) {
            return legacyMetadata
        }

        throw XcmTransfersError.noTransfer(chainAsset.chainAssetId, destinationChain.chainId)
    }

    func getAllTransfers() -> [ChainAssetId: Set<ChainAssetId>] {
        indexedByOrigins
    }

    func getOrigins(for chainAssetId: ChainAssetId) -> Set<ChainAssetId> {
        indexedByDestinations[chainAssetId] ?? []
    }

    func getDestinations(for chainAssetId: ChainAssetId) -> Set<ChainAssetId> {
        indexedByOrigins[chainAssetId] ?? []
    }
}

struct XcmTransferMetadata {
    struct Reserve {
        let reserveId: ChainModel.Id
        let path: XcmAsset.ReservePath
    }

    enum Fee {
        case legacy(LegacyFee)
        case dynamic
    }

    struct LegacyFeeDetails {
        let instructions: [String]
        let mode: XcmAssetTransferFee
        let baseWeight: BigUInt

        var maxWeight: BigUInt {
            baseWeight * BigUInt(instructions.count)
        }
    }

    struct LegacyFee {
        let destinationExecution: LegacyFeeDetails
        let reserveExecution: LegacyFeeDetails?
        let originDelivery: XcmDeliveryFee?
        let reserveDelivery: XcmDeliveryFee?

        var maxWeight: BigUInt {
            let reserveMaxWeight = reserveExecution?.maxWeight ?? 0

            return destinationExecution.maxWeight + reserveMaxWeight
        }
    }

    let callType: XcmTransferType
    let reserve: Reserve
    let fee: Fee
    let paysDeliveryFee: Bool
    let supportsXcmExecute: Bool
}
