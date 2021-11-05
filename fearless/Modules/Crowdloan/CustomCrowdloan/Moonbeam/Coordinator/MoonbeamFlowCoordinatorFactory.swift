import SoraKeystore
import SoraFoundation
import SubstrateSdk

struct MoonbeamFlowCoordinatorFactory {
    static func createCoordinator(
        previousView: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?,
        state: CrowdloanSharedState,
        crowdloan: Crowdloan,
        displayInfo: CrowdloanDisplayInfo
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

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )

        let service = MoonbeamBonusService(
            crowdloan: crowdloan,
            chainId: chain.chainId,
            address: selectedAddress,
            operationFactory: crowdloanOperationFactory,
            chainRegistry: chainRegistry,
            ethereumAddress: ethereumAddress,
            signingWrapper: signingWrapper,
            operationManager: operationManager
        )

        guard let crowdloanChainId = displayInfo.chainId else { return nil }

        return MoonbeamFlowCoordinator(
            state: state,
            paraId: crowdloan.paraId,
            metaAccount: selectedAccount,
            service: service,
            operationManager: operationManager,
            previousView: previousView,
            accountManagementWireframe: AccountManagementWireframe(),
            crowdloanDisplayName: displayInfo.name,
            crowdloanChainId: crowdloanChainId,
            localizationManager: LocalizationManager.shared
        )
    }
}
