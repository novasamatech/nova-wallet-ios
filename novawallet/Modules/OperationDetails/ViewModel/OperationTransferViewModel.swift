import Foundation

struct OperationTransferViewModel {
    let fee: BalanceViewModelProtocol?
    let isOutgoing: Bool
    let sender: DisplayAddressViewModel
    let recepient: DisplayAddressViewModel
    let transactionHash: String
}
