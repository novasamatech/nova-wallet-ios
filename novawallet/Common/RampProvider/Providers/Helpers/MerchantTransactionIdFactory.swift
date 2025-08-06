import Foundation

protocol MerchantTransactionIdFactoryProtocol {
    func createTransactionId() -> String
}

final class UUIDMerchantTransactionIdFactory: MerchantTransactionIdFactoryProtocol {
    func createTransactionId() -> String {
        UUID().uuidString
    }
}
