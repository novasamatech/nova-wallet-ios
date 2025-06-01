import Foundation
import Operation_iOS

protocol NewLedgerPolkadotSigningProtocol {
    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        params: GenericLedgerPolkadotSigningParams
    ) -> CompoundOperationWrapper<Data>
}

class NewLedgerPolkadotApplication: PolkadotLedgerCommonApplication {
    static let cla: UInt8 = 249

    func getSubstrateAccountWrapper(
        for deviceId: UUID,
        coin: UInt32,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse> {
        let path = LedgerPathBuilder()
            .appendingStandardJunctions(coin: coin, accountIndex: index)
            .build()

        return prepareAccountWrapper(
            for: deviceId,
            cla: Self.cla,
            derivationPath: path,
            payloadClosure: { Data(path.bytes + addressPrefix.littleEndianBytes) },
            cryptoScheme: LedgerConstants.defaultSubstrateCryptoScheme,
            displayVerificationDialog: displayVerificationDialog
        )
    }

    func getEvmAccountWrapper(
        for deviceId: UUID,
        coin: UInt32,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerEvmAccountResponse> {
        let path = LedgerPathBuilder()
            .appendingStandardJunctions(coin: coin, accountIndex: index)
            .build()

        return prepareAccountWrapper(
            for: deviceId,
            cla: Self.cla,
            derivationPath: path,
            payloadClosure: { Data(path.bytes) },
            cryptoScheme: LedgerConstants.defaultEvmCryptoScheme,
            displayVerificationDialog: displayVerificationDialog
        )
    }

    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        params: GenericLedgerPolkadotSigningParams
    ) -> CompoundOperationWrapper<Data> {
        let derivationPathClosure: LedgerPayloadClosure = {
            let total = params.derivationPath.bytes + UInt16(payload.count).littleEndianBytes
            return Data(total)
        }

        let payloadAndProof = payload + params.extrinsicProof

        let payloadAndProofChunkClosures: [LedgerPayloadClosure] = payloadAndProof.chunked(
            by: LedgerConstants.chunkSize
        ).map { chunk in { chunk } }

        let cryptoScheme: LedgerCryptoScheme = switch params.mode {
        case .substrate:
            LedgerConstants.defaultSubstrateCryptoScheme
        case .evm:
            LedgerConstants.defaultEvmCryptoScheme
        }

        let chunks = [derivationPathClosure] + payloadAndProofChunkClosures

        return prepareSignatureWrapper(
            for: deviceId,
            cla: Self.cla,
            cryptoScheme: cryptoScheme,
            chunks: chunks
        )
    }
}
