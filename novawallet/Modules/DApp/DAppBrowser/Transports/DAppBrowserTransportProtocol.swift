import Foundation
import RobinHood

protocol DAppBrowserTransportProtocol: AnyObject {
    var name: String { get }

    var delegate: DAppBrowserTransportDelegate? { get set }

    func createBridgeScriptOperation() -> BaseOperation<DAppBrowserScript>
    func createSubscriptionScript(for dataSource: DAppBrowserStateDataSource) -> DAppBrowserScript?

    func start(with dataSource: DAppBrowserStateDataSource)
    func isIdle() -> Bool
    func bringPhishingDetectedStateIfNeeded() -> Bool
    func process(message: Any, host: String)
    func processConfirmation(response: DAppOperationResponse)
    func processAuth(response: DAppAuthResponse)
    func stop()
}

protocol DAppBrowserTransportDelegate: AnyObject {
    func dAppTransport(
        _ transport: DAppBrowserTransportProtocol,
        didReceiveResponse response: DAppScriptResponse
    )

    func dAppTransport(_ transport: DAppBrowserTransportProtocol, didReceiveAuth request: DAppAuthRequest)

    func dAppTransport(
        _ transport: DAppBrowserTransportProtocol,
        didReceiveConfirmation request: DAppOperationRequest,
        of type: DAppSigningType
    )

    func dAppTransport(_ transport: DAppBrowserTransportProtocol, didReceive error: Error)

    func dAppTransportAsksPopMessage(_ transport: DAppBrowserTransportProtocol)

    func dAppAskReload(
        _ transport: DAppBrowserTransportProtocol,
        postExecutionScript: DAppScriptResponse
    )
}
