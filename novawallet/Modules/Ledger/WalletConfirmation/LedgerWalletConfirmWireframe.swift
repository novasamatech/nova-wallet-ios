import Foundation

final class LedgerWalletConfirmWireframe: LedgerWalletConfirmWireframeProtocol, WalletCreationFlowCompleting {
    let flow: WalletCreationFlow

    init(flow: WalletCreationFlow) {
        self.flow = flow
    }

    func complete(on view: ControllerBackedProtocol?) {
        completeWalletCreation(on: view, flow: flow)
    }
}
