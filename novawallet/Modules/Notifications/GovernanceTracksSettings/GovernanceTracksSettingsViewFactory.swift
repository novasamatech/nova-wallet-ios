import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS

typealias GovernanceTracksCount = Int
typealias SelectTracksClosure = (Set<TrackIdLocal>, GovernanceTracksCount) -> Void

enum GovernanceTracksSettingsViewFactory {
    static func createView(
        selectedTracks: Set<TrackIdLocal>?,
        chain: ChainModel,
        completion: @escaping SelectTracksClosure
    ) -> GovernanceTracksSettingsViewProtocol? {
        guard let runtimeProvider = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let operationFactory = Gov2OperationFactory(
            requestFactory: requestFactory,
            commonOperationFactory: GovCommonOperationFactory(),
            operationQueue: operationQueue
        )

        let interactor = GovernanceTracksSettingsInteractor(
            fetchOperationFactory: operationFactory,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        let wireframe = GovernanceTracksSettingsWireframe(completion: completion)

        let presenter = GovernanceTracksSettingsPresenter(
            initialSelectedTracks: selectedTracks,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            chain: chain,
            logger: Logger.shared
        )

        let view = GovernanceTracksSettingsViewController(
            basePresenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
