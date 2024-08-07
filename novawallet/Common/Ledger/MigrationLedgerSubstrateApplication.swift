import Foundation
import Operation_iOS

final class MigrationLedgerSubstrateApplication: NewSubstrateLedgerApplication {
    let chainRegistry: ChainRegistryProtocol
    let supportedApps: [SupportedLedgerApp]

    init(
        connectionManager: LedgerConnectionManagerProtocol,
        chainRegistry: ChainRegistryProtocol,
        supportedApps: [SupportedLedgerApp]
    ) {
        self.chainRegistry = chainRegistry
        self.supportedApps = supportedApps

        super.init(connectionManager: connectionManager)
    }
}

extension MigrationLedgerSubstrateApplication: NewSubstrateLedgerSigningProtocol {}

extension MigrationLedgerSubstrateApplication: LedgerAccountRetrievable {
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let application = supportedApps.first(where: { $0.chainId == chainId }) else {
            return CompoundOperationWrapper.createWithError(LedgerApplicationError.unsupportedApp(chainId: chainId))
        }

        return getAccountWrapper(
            for: deviceId,
            coin: application.coin,
            index: index,
            addressPrefix: chain.addressPrefix.toSubstrateFormat(),
            displayVerificationDialog: displayVerificationDialog
        )
    }
}
