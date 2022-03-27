import Foundation

protocol TransferScanDelegate: AnyObject {
    func didReceiveRecepient(address: AccountAddress)
}
