import UIKit
import SubstrateSdk

final class ProxySignValidationInteractor {
    weak var presenter: ProxySignValidationInteractorOutputProtocol?
    
    let selectedAccount: MetaChainAccountResponse
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let calls: [JSON]
    
    init(
        selectedAccount: MetaChainAccountResponse,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        calls: [JSON]
    ) {
        self.selectedAccount = selectedAccount
        self.extrinsicService = extrinsicService
        self.runtimeProvider = runtimeProvider
        self.calls = calls
    }
}

extension ProxySignValidationInteractor: ProxySignValidationInteractorInputProtocol {
    func setup() {
        
    }
}
