import Foundation
import Operation_iOS

struct GenericLedgerSubstrateSigningParams {
    let extrinsicProof: Data
    let derivationPath: Data
}

protocol GenericLedgerSubstrateApplicationProtocol {
    var displayName: String { get }

    var connectionManager: LedgerConnectionManagerProtocol { get }

    func getAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse>

    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        params: GenericLedgerSubstrateSigningParams
    ) -> CompoundOperationWrapper<Data>
}

extension GenericLedgerSubstrateApplicationProtocol {
    func getUniversalAccountWrapper(
        for deviceId: UUID,
        index: UInt32 = 0,
        displayVerificationDialog: Bool = false
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        getAccountWrapper(
            for: deviceId,
            index: index,
            addressPrefix: 42,
            displayVerificationDialog: displayVerificationDialog
        )
    }
}

final class GenericLedgerSubstrateApplication: NewSubstrateLedgerApplication {}

extension GenericLedgerSubstrateApplication: GenericLedgerSubstrateApplicationProtocol {
    static let coin: UInt32 = 354

    var displayName: String { "Generic" }

    func getAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        getAccountWrapper(
            for: deviceId,
            coin: Self.coin,
            index: index,
            addressPrefix: addressPrefix,
            displayVerificationDialog: displayVerificationDialog
        )
    }

    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        params: GenericLedgerSubstrateSigningParams
    ) -> CompoundOperationWrapper<Data> {
        let derivationPathClosure: LedgerPayloadClosure = {
            let total = params.derivationPath.bytes + UInt16(payload.count).littleEndianBytes
            return Data(total)
        }

        let payloadAndProof = payload + params.extrinsicProof

        let payloadAndProofChunkClosures: [LedgerPayloadClosure] = payloadAndProof.chunked(
            by: LedgerConstants.chunkSize
        ).map { chunk in { chunk } }

        let chunks = [derivationPathClosure] + payloadAndProofChunkClosures

        return prepareSignatureWrapper(
            for: deviceId,
            cla: Self.cla,
            chunks: chunks
        )
    }
}
