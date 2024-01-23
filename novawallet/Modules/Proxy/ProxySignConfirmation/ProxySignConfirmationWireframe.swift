import Foundation

final class ProxySignConfirmationWireframe: ProxySignConfirmationWireframeProtocol {
    let proxiedId: MetaAccountModel.Id
    let proxyName: String

    init(proxiedId: MetaAccountModel.Id, proxyName: String) {
        self.proxiedId = proxiedId
        self.proxyName = proxyName
    }

    func showConfirmation(
        from view: ControllerBackedProtocol,
        completionClosure: @escaping ProxySignConfirmationCompletion
    ) {
        guard let proxyConfirmationView = ProxyMessageSheetViewFactory.createSigningView(
            proxiedId: proxiedId,
            proxyName: proxyName,
            completionClosure: { completionClosure(true) },
            cancelClosure: { completionClosure(false) }
        ) else {
            completionClosure(false)
            return
        }

        view.controller.present(proxyConfirmationView.controller, animated: true)
    }
}
