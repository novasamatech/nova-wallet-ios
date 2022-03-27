import Foundation
import CommonWallet
import SubstrateSdk

protocol AddressQRMatching {
    func match(code: String) -> AccountAddress?
}

final class AddressQRMatcher: AddressQRMatching {
    let chainFormat: ChainFormat

    init(chainFormat: ChainFormat) {
        self.chainFormat = chainFormat
    }

    func match(code: String) -> AccountAddress? {
        guard let data = code.data(using: .utf8) else {
            return nil
        }

        do {
            if SubstrateQR.isSubstrateQR(data: data) {
                let substrateDecoder = SubstrateQRDecoder(
                    addressFormat: chainFormat.substrateQRAddressFormat
                )

                return try substrateDecoder.decode(data: data).address
            } else {
                let addressDecoder = AddressQRDecoder(
                    addressFormat: chainFormat.substrateQRAddressFormat
                )

                return try addressDecoder.decode(data: data)
            }
        } catch {
            return nil
        }
    }
}
