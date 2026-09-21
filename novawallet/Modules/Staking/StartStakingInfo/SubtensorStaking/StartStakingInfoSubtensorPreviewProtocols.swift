import Foundation

protocol StartStakingInfoSubtensorPreviewInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol StartStakingInfoSubtensorPreviewInteractorOutputProtocol: AnyObject {
    func didReceive(previewData: SubtensorStakingPreviewData)
    func didReceivePreview(error: Error)
}

protocol StartStakingInfoSubtensorPreviewWireframeProtocol: AnyObject {
    func showStrategies(from view: ControllerBackedProtocol?)
    func showManualStaking(from view: ControllerBackedProtocol?)
    func presentLoadError(
        from view: ControllerBackedProtocol?,
        retryAction: @escaping () -> Void
    )
}
