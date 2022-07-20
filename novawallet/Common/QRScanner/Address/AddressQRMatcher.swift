import Foundation
import CommonWallet
import SubstrateSdk

protocol AddressQRMatching {
    func match(code: String) -> AccountAddress?
}

final class AddressQRMatcher: AddressQRMatching {
    func match(code: String) -> AccountAddress? {
        guard let data = code.data(using: .utf8) else {
            return nil
        }

        do {
            if SubstrateQR.isSubstrateQR(data: data) {
                let substrateDecoder = SubstrateQRDecoder()
                return try substrateDecoder.decode(data: data).address
            } else if (try? code.toAccountId()) != nil {
                return code
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}
