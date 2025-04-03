import Foundation
import Keystore_iOS

class CrowdloanContributionSetupWireframe: CrowdloanContributionSetupWireframeProtocol {
    let state: CrowdloanSharedState
    let settingsManager: SettingsManagerProtocol

    init(state: CrowdloanSharedState, settingsManager: SettingsManagerProtocol) {
        self.state = state
        self.settingsManager = settingsManager
    }

    func showConfirmation(
        from view: CrowdloanContributionSetupViewProtocol?,
        paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?
    ) {
        guard let confirmationView = CrowdloanContributionConfirmViewFactory.createView(
            with: paraId,
            inputAmount: inputAmount,
            bonusService: bonusService,
            state: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }

    func showAdditionalBonus(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard
            let customFlowString = displayInfo.customFlow,
            let customFlow = CrowdloanFlow(rawValue: customFlowString) else {
            return
        }

        switch customFlow {
        case .karura:
            showKaruraCustomFlow(
                from: view,
                for: displayInfo,
                inputAmount: inputAmount,
                delegate: delegate,
                existingService: existingService
            )
        case .acala:
            showAcalaCustomFlow(
                from: view,
                for: displayInfo,
                inputAmount: inputAmount,
                delegate: delegate,
                existingService: existingService
            )
        case .bifrost:
            showBifrostCustomFlow(
                from: view,
                for: displayInfo,
                inputAmount: inputAmount,
                delegate: delegate,
                existingService: existingService
            )
        case .astar:
            showAstarCustomFlow(
                from: view,
                for: displayInfo,
                inputAmount: inputAmount,
                delegate: delegate,
                existingService: existingService
            )
        case .moonbeam:
            break
        }
    }

    private func showAcalaCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let acalaView = ReferralCrowdloanViewFactory.createAcalaView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            existingService: existingService,
            state: state,
            settingsManager: settingsManager
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: acalaView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }

    private func showKaruraCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let karuraView = ReferralCrowdloanViewFactory.createKaruraView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            existingService: existingService,
            state: state,
            settingsManager: settingsManager
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: karuraView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }

    private func showBifrostCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let bifrostView = ReferralCrowdloanViewFactory.createBifrostView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            existingService: existingService,
            state: state
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: bifrostView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }

    private func showAstarCustomFlow(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    ) {
        guard let astarView = ReferralCrowdloanViewFactory.createAstarView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            existingService: existingService,
            state: state
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: astarView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
