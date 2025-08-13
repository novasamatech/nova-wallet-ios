import Foundation
import Operation_iOS

protocol LedgerAccountRetrievable {
    var connectionManager: LedgerConnectionManagerProtocol { get }

    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse>
}

extension LedgerAccountRetrievable {
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse> {
        getAccountWrapper(for: deviceId, chainId: chainId, index: index, displayVerificationDialog: false)
    }
}

protocol LedgerApplicationProtocol: LedgerAccountRetrievable {
    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        chainId: ChainModel.Id,
        derivationPathClosure: @escaping LedgerPayloadClosure
    ) -> CompoundOperationWrapper<Data>
}

enum LedgerApplicationError: Error {
    case unsupportedApp(chainId: ChainModel.Id)
}

final class LedgerApplication: PolkadotLedgerCommonApplication {
    let supportedApps: [SupportedLedgerApp]

    init(connectionManager: LedgerConnectionManagerProtocol, supportedApps: [SupportedLedgerApp]) {
        self.supportedApps = supportedApps

        super.init(connectionManager: connectionManager)
    }
}

extension LedgerApplication: LedgerApplicationProtocol {
    /// https://github.com/Zondax/ledger-substrate-js/blob/main/src/substrate_app.ts#L143
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse> {
        guard let application = supportedApps.first(where: { $0.chainId == chainId }) else {
            return CompoundOperationWrapper.createWithError(LedgerApplicationError.unsupportedApp(chainId: chainId))
        }

        let path = LedgerPathBuilder()
            .appendingStandardJunctions(coin: application.coin, accountIndex: index)
            .build()

        return prepareAccountWrapper(
            for: deviceId,
            cla: application.cla,
            derivationPath: path,
            payloadClosure: { path },
            cryptoScheme: LedgerConstants.defaultSubstrateCryptoScheme,
            displayVerificationDialog: displayVerificationDialog
        )
    }

    /// https://github.com/Zondax/ledger-substrate-js/blob/main/src/substrate_app.ts#L203
    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        chainId: ChainModel.Id,
        derivationPathClosure: @escaping LedgerPayloadClosure
    ) -> CompoundOperationWrapper<Data> {
        guard let application = supportedApps.first(where: { $0.chainId == chainId }) else {
            return CompoundOperationWrapper.createWithError(LedgerApplicationError.unsupportedApp(chainId: chainId))
        }

        let payloadChunkClosures: [LedgerPayloadClosure] = payload.chunked(
            by: LedgerConstants.chunkSize
        ).map { chunk in { chunk } }

        let chunks = [derivationPathClosure] + payloadChunkClosures

        return prepareSignatureWrapper(
            for: deviceId,
            cla: application.cla,
            cryptoScheme: LedgerConstants.defaultSubstrateCryptoScheme,
            chunks: chunks
        )
    }
}
