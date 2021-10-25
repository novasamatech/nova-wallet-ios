import SoraKeystore

struct MoonbeamFlowCoordinatorFactory {
    static func createCoordinator(
        previousView: (ControllerBackedProtocol & AlertPresentable)?,
        state: CrowdloanSharedState
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

        let service = MoonbeamBonusService(
            address: selectedAddress,
            signingWrapper: signingWrapper
        )

        return MoonbeamFlowCoordinator(
            service: service,
            operationManager: OperationManagerFacade.sharedManager,
            previousView: previousView
        )
    }
}
