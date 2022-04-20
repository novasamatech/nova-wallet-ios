import Foundation
import SubstrateSdk

struct MetamaskMessage: Codable {
    // swiftlint:disable:next type_name
    typealias Id = UInt64

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case name
        case object
    }

    enum Method: String, Codable, CaseIterable {
        case signTransaction
        case requestAccounts
        case addEthereumChain
        case switchEthereumChain
        case signPersonalMessage
        case signTypedMessage
    }

    let identifier: Id
    let name: Method
    let object: JSON?
}
