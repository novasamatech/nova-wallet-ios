import Foundation

struct DAppNetworksViewModel {
    let network: NetworkViewModel?
    let supported: Int
    let unsupported: Int

    var totalNetworks: Int {
        supported + unsupported
    }
}
