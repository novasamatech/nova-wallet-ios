import Foundation
import Operation_iOS

protocol NewSubstrateLedgerSigningProtocol {
    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        params: GenericLedgerSubstrateSigningParams
    ) -> CompoundOperationWrapper<Data>
}

class NewSubstrateLedgerApplication: SubstrateLedgerCommonApplication {
    static let cla: UInt8 = 249

    func getAccountWrapper(
        for deviceId: UUID,
        coin: UInt32,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        let path = LedgerPathBuilder()
            .appendingStandardJunctions(coin: coin, accountIndex: index)
            .build()

        return prepareAccountWrapper(
            for: deviceId,
            cla: Self.cla,
            derivationPath: path,
            payloadClosure: { Data(path.bytes + addressPrefix.littleEndianBytes) },
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
