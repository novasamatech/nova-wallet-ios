import Foundation

protocol AddressScanDelegate: AnyObject {
    func addressScanDidReceiveRecepient(address: AccountAddress, context: AnyObject?)
}
