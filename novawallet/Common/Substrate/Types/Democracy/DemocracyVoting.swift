import Foundation
import SubstrateSdk

extension Democracy {
    enum Voting: Decodable {
        case direct(ConvictionVoting.Casting)
        case delegating(ConvictionVoting.Delegating)
        case unknown

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Direct":
                let voting = try container.decode(ConvictionVoting.Casting.self)
                self = .direct(voting)
            case "Delegating":
                let voting = try container.decode(ConvictionVoting.Delegating.self)
                self = .delegating(voting)
            default:
                self = .unknown
            }
        }
    }

    struct VotingOfKey: JSONListConvertible, Hashable {
        let accountId: AccountId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 1
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            accountId = try jsonList[0].map(to: AccountId.self, with: context)
        }
    }
}
