import Foundation

struct OperationTransferViewModel {
    let fee: String
    let isOutgoing: Bool
    let sender: DisplayAddressViewModel
    let recepient: DisplayAddressViewModel
    let transactionHash: String
}
