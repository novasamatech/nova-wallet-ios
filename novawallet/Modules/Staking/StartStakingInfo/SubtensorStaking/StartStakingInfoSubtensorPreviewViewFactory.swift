import Foundation_iOS
import Operation_iOS

enum StartStakingInfoSubtensorPreviewViewFactory {
    static func createView() -> StartStakingInfoSubtensorViewProtocol {
        let dataSource = SubtensorStakingStrategiesMockDataSource()
        let interactor = StartStakingInfoSubtensorPreviewInteractor(
            dataSource: dataSource,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = StartStakingInfoSubtensorPreviewWireframe(dataSource: dataSource)
        let localizationManager = LocalizationManager.shared
        let presenter = StartStakingInfoSubtensorPreviewPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: StartStakingInfoSubtensorViewModelFactory(),
            localizationManager: localizationManager
        )
        let view = StartStakingInfoSubtensorViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
