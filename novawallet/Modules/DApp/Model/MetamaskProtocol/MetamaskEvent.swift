import Foundation

enum MetamaskEvent {
    case chainChanged(chainId: String)
    case accountsChanged(addresses: [AccountAddress])
    case connect(chainId: String)
}
