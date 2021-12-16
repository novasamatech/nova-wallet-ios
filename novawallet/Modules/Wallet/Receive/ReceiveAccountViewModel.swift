import Foundation
import SoraKeystore

protocol ReceiveAccountViewModelProtocol {
    var displayName: String { get }
    var address: String { get }
}

struct ReceiveAccountViewModel: ReceiveAccountViewModelProtocol {
    let displayName: String
    let address: String

    init(displayName: String, address: String) {
        self.displayName = displayName
        self.address = address
    }
}
