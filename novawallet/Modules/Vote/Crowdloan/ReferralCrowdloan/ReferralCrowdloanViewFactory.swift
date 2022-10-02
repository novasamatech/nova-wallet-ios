import Foundation
import SoraKeystore
import SoraFoundation

struct ReferralCrowdloanViewFactory {
    static func createAcalaView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> ReferralCrowdloanViewProtocol? {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let chain = state.settings.value,
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()),
            let selectedAddress = try? accountResponse.accountId.toAddress(
                using: chain.chainFormat
            ) else {
            return nil
        }

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

        guard let accountAddress = accountAddressDependingOnChain else {
            return nil
        }

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService as? AcalaBonusService {
                return service
            } else {
                let signingWrapper = SigningWrapper(
                    keystore: Keychain(),
                    metaId: selectedAccount.metaId,
                    accountResponse: accountResponse
                )
                return AcalaBonusService(
                    address: accountAddress,
                    signingWrapper: signingWrapper,
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

        guard let defaultReferralCode = bonusService.defaultReferralCode else { return nil }
        return createView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: defaultReferralCode,
            state: state
        )
    }

    static func createKaruraView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> ReferralCrowdloanViewProtocol? {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let chain = state.settings.value,
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()),
            let selectedAddress = try? accountResponse.accountId.toAddress(
                using: chain.chainFormat
            ) else {
            return nil
        }

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService as? KaruraBonusService {
                return service
            } else {
                let signingWrapper = SigningWrapper(
                    keystore: Keychain(),
                    metaId: selectedAccount.metaId,
                    accountResponse: accountResponse
                )
                return KaruraBonusService(
                    address: selectedAddress,
                    signingWrapper: signingWrapper,
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

        guard let defaultReferralCode = bonusService.defaultReferralCode else { return nil }
        return createView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: defaultReferralCode,
            state: state
        )
    }

    static func createBifrostView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> ReferralCrowdloanViewProtocol? {
        guard let paraId = ParaId(displayInfo.paraid) else {
            return nil
        }

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService as? BifrostBonusService {
                return service
            } else {
                return BifrostBonusService(
                    paraId: paraId,
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

        guard let defaultReferralCode = bonusService.defaultReferralCode else { return nil }
        return createView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: defaultReferralCode,
            state: state
        )
    }

    static func createAstarView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> ReferralCrowdloanViewProtocol? {
        guard let paraId = ParaId(displayInfo.paraid) else {
            return nil
        }

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService as? AstarBonusService {
                return service
            } else {
                return AstarBonusService(
                    paraId: paraId,
                    chainFormat: state.settings.value.chainFormat,
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

        guard let defaultReferralCode = bonusService.defaultReferralCode else { return nil }
        return createView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: defaultReferralCode,
            state: state
        )
    }

    private static func createView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol,
        defaultReferralCode: String,
        state: CrowdloanSharedState
    ) -> ReferralCrowdloanViewProtocol? {
        guard
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first else {
            return nil
        }

        let wireframe = ReferralCrowdloanWireframe()

        let assetInfo = asset.displayInfo(with: chain.icon)
        let viewModelFactory = CrowdloanContributionViewModelFactory(
            assetInfo: assetInfo,
            chainDateCalculator: ChainDateCalculator()
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ReferralCrowdloanPresenter(
            wireframe: wireframe,
            bonusService: bonusService,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            crowdloanDelegate: delegate,
            crowdloanViewModelFactory: viewModelFactory,
            defaultReferralCode: defaultReferralCode,
            localizationManager: localizationManager
        )

        let view = ReferralCrowdloanViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view

        return view
    }
}
