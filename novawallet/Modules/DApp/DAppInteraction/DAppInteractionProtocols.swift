import Foundation
import Operation_iOS

protocol DAppTransportProtocol: AnyObject {
    var name: String { get }

    func isIdle() -> Bool
    func bringPhishingDetectedStateIfNeeded() -> Bool
    func process(message: Any, host: String?)
    func processConfirmation(response: DAppOperationResponse)
    func processAuth(response: DAppAuthResponse)
    func processChainsChanges()

    func start()
    func stop()
}

protocol DAppInteractionMediating: AnyObject, ApplicationServiceProtocol {
    var chainsStore: ChainsStoreProtocol { get }
    var settingsRepository: AnyDataProviderRepository<DAppSettings> { get }
    var operationQueue: OperationQueue { get }

    var children: [DAppInteractionChildProtocol] { get }

    func register(transport: DAppTransportProtocol)
    func unregister(transport: DAppTransportProtocol)

    func process(message: Any, host: String?, transport name: String)
    func process(authRequest: DAppAuthRequest)
    func process(signingRequest: DAppOperationRequest, type: DAppSigningType)
    func processMessageQueue()
}

protocol DAppInteractionInputProtocol: AnyObject {
    func processConfirmation(response: DAppOperationResponse, forTransport name: String)
    func processAuth(response: DAppAuthResponse, forTransport name: String)
    func completePhishingStateHandling()
}

protocol DAppInteractionOutputProtocol: AnyObject {
    func didReceiveConfirmation(request: DAppOperationRequest, type: DAppSigningType)
    func didReceiveAuth(request: DAppAuthRequest)
    func didDetectPhishing(host: String)
    func didReceive(error: DAppInteractionError)
}

protocol DAppInteractionChildProtocol: ApplicationServiceProtocol {
    var mediator: DAppInteractionMediating? { get set }

    func completePhishingStateHandling()
}
