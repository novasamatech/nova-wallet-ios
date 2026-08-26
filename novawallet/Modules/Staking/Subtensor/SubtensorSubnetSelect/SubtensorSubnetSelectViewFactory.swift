import Foundation
import Foundation_iOS

enum SubtensorSubnetSelectViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        delegateTake: UInt16?
    ) -> SubtensorSubnetSelectViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ) else {
            return nil
        }

        let interactor = SubtensorSubnetSelectInteractor(
            subnetsService: state.subnetsService,
            runtimeProvider: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let wireframe = SubtensorSubnetSelectWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = SubtensorSubnetSelectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SubtensorSubnetViewModelFactory(chainAsset: chainAsset),
            delegate: delegate,
            preferredTake: delegateTake,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = SubtensorSubnetSelectViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
