import Foundation
import RobinHood
import SoraKeystore

protocol ExternalContributionSourceProtocol {
    func supports(chain: ChainModel) -> Bool
    func getContributions(accountId: AccountId, chain: ChainModel) -> BaseOperation<[ExternalContribution]>
}

enum ExternalContributionSourcesFactory {
    static func createExternalSources(
        sharedState: CrowdloanSharedState
    ) -> [ExternalContributionSourceProtocol] {
        guard
            let chain = sharedState.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value,
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()),
            let selectedAddress = try? accountResponse.accountId.toAddress(
                using: chain.chainFormat
            )
        else { return [] }

        let accountAddressDependingOnChain: String? = {
            switch chain.chainId {
            case Chain.rococo.genesisHash:
                // requires polkadot address even in rococo testnet
                return try? accountResponse.accountId.toAddress(
                    using: ChainFormat.substrate(UInt16(SNAddressType.polkadotMain.rawValue))
                )
            default:
                return selectedAddress
            }
        }()
        guard let address = accountAddressDependingOnChain else { return [] }

        let operationManager = OperationManagerFacade.sharedManager
        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: selectedAccount.metaId,
            accountResponse: accountResponse
        )

        let acalaService = AcalaBonusService(
            address: address,
            signingWrapper: signingWrapper,
            operationManager: operationManager
        )
        let parallelSource = ParallelContributionSource()

        return [acalaService, parallelSource]
    }
}
