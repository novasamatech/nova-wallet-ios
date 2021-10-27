import SoraKeystore
import SoraFoundation

struct MoonbeamFlowCoordinatorFactory {
    static func createCoordinator(
        previousView: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?,
        state: CrowdloanSharedState,
        paraId: ParaId,
        displayInfo: CrowdloanDisplayInfo,
        contrubution: CrowdloanContribution?
    ) -> Coordinator? {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let chain = state.settings.value,
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()),
            let selectedAddress = try? accountResponse.accountId.toAddress(
                using: chain.chainFormat
            ) else {
            return nil
        }

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: selectedAccount.metaId,
            accountResponse: accountResponse
        )

        let operationManager = OperationManagerFacade.sharedManager
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let ethereumAddress: String? = {
            if
                let chainId = displayInfo.chainId,
                let moonbeamChain = chainRegistry.getChain(for: chainId),
                let accountResponse = selectedAccount.fetch(for: moonbeamChain.accountRequest()),
                let moonbeamAddress = try? accountResponse.accountId.toAddress(using: moonbeamChain.chainFormat) {
                return moonbeamAddress
            } else {
                return nil
            }
        }()

        let service = MoonbeamBonusService(
            paraId: paraId,
            address: selectedAddress,
            contrubution: contrubution,
            ethereumAddress: ethereumAddress,
            signingWrapper: signingWrapper,
            operationManager: operationManager
        )

        return MoonbeamFlowCoordinator(
            state: state,
            paraId: paraId,
            service: service,
            operationManager: operationManager,
            previousView: previousView,
            localizationManager: LocalizationManager.shared
        )
    }
}
