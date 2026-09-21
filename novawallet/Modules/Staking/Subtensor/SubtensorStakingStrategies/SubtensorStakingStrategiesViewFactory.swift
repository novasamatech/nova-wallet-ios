import Foundation_iOS
import Operation_iOS

enum SubtensorStakingStrategiesViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        dataSource: SubtensorStakingStrategiesDataSourceProtocol
    ) -> SubtensorStakingStrategiesViewProtocol {
        createView(
            dataSource: dataSource,
            wireframe: SubtensorStakingStrategiesWireframe(state: state)
        )
    }

    static func createPreviewView(
        dataSource: SubtensorStakingStrategiesDataSourceProtocol
    ) -> SubtensorStakingStrategiesViewProtocol {
        createView(
            dataSource: dataSource,
            wireframe: SubtensorStakingStrategiesPreviewWireframe()
        )
    }

    private static func createView(
        dataSource: SubtensorStakingStrategiesDataSourceProtocol,
        wireframe: SubtensorStakingStrategiesWireframeProtocol
    ) -> SubtensorStakingStrategiesViewProtocol {
        let interactor = SubtensorStakingStrategiesInteractor(
            dataSource: dataSource,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let localizationManager = LocalizationManager.shared
        let presenter = SubtensorStakingStrategiesPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SubtensorStakingStrategiesViewModelFactory(),
            localizationManager: localizationManager
        )
        let view = SubtensorStakingStrategiesViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
