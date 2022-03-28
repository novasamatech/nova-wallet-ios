import Foundation

protocol TransferScanDelegate: AnyObject {
    func transferScanDidReceiveRecepient(address: AccountAddress)
}
