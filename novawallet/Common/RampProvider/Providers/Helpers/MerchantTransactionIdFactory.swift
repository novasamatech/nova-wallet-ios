import Foundation

protocol MerchantTransactionIdFactory {
    func createTransactionId() -> String
}

final class UUIDMerchantTransactionIdFactory: MerchantTransactionIdFactory {
    func createTransactionId() -> String {
        UUID().uuidString
    }
}
