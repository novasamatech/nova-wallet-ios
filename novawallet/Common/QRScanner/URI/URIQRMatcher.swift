import Foundation
import CommonWallet
import SubstrateSdk

protocol URIQRMatching {
    func match(code: String) -> String?
}

final class SchemeURIMatcher: URIQRMatching {
    let scheme: String

    init(scheme: String) {
        self.scheme = scheme
    }

    func match(code: String) -> String? {
        guard let url = URL(string: code), url.scheme == scheme else {
            return nil
        }

        return code
    }
}
