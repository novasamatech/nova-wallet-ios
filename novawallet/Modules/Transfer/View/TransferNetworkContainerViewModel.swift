import Foundation

struct TransferNetworkContainerViewModel {
    enum Mode {
        case onchain(NetworkViewModel)
        case selectableOrigin(NetworkViewModel, NetworkViewModel)
        case selectableDestination(NetworkViewModel, NetworkViewModel)
    }

    let assetSymbol: String
    let mode: Mode

    var isCrosschain: Bool {
        switch mode {
        case .onchain:
            return false
        case .selectableDestination, .selectableOrigin:
            return true
        }
    }
}
