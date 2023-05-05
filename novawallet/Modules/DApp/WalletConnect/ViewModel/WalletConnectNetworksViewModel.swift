import Foundation

struct WalletConnectNetworksViewModel {
    let network: NetworkViewModel?
    let supported: Int
    let unsupported: Int

    var totalNetworks: Int {
        supported + unsupported
    }
}
