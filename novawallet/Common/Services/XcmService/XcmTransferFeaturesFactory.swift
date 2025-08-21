import Foundation

protocol XcmTransferFeaturesFactoryProtocol {
    func createFeatures(for metadata: XcmTransferMetadata) -> XcmTransferFeatures
}

extension XcmTransferFeaturesFactoryProtocol {
    func createFeatures(
        for transfers: XcmTransfers,
        originAsset: ChainAsset,
        destinationChain: ChainModel
    ) throws -> XcmTransferFeatures {
        let metadata = try transfers.getTransferMetadata(
            for: originAsset,
            destinationChain: destinationChain
        )

        return createFeatures(for: metadata)
    }
}

struct XcmTransferFeaturesFactory {
    let hasXcmPaymentApi: Bool
}

private extension XcmTransferFeaturesFactory {
    func getShouldUseXcmExecute(for metadata: XcmTransferMetadata) -> Bool {
        // we are enabling xcm execute to take advantage of delivery fee payment
        // also we need to have xcm payment api

        metadata.paysDeliveryFee && metadata.supportsXcmExecute && hasXcmPaymentApi
    }
}

extension XcmTransferFeaturesFactory: XcmTransferFeaturesFactoryProtocol {
    func createFeatures(for metadata: XcmTransferMetadata) -> XcmTransferFeatures {
        let shouldUseXcmExecute = getShouldUseXcmExecute(for: metadata)

        return XcmTransferFeatures(
            hasDeliveryFee: metadata.paysDeliveryFee,
            usesTeleports: metadata.usesTeleport,
            shouldUseXcmExecute: shouldUseXcmExecute
        )
    }
}
