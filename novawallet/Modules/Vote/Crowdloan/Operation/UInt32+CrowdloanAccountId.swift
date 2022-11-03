import Foundation
import SubstrateSdk

enum FundAccountIdError: Error {
    case invalidPrefix
}

extension UInt32 {
    func fundAccountId() throws -> AccountId {
        guard let fundAccountPrefix = "modlpy/cfund".data(using: .utf8) else {
            throw FundAccountIdError.invalidPrefix
        }

        let fundAccountSuffix = Data(repeating: 0, count: SubstrateConstants.accountIdLength)

        let bidderKeyData = try scaleEncoded()

        let fundAccountId = (fundAccountPrefix + bidderKeyData + fundAccountSuffix)
            .prefix(SubstrateConstants.accountIdLength)

        return fundAccountId
    }
}
