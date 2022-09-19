import Foundation
import SubstrateSdk
import BigInt

extension AutomationTime {
    typealias TaskId = Data
    typealias Seconds = UInt64
    typealias UnixTime = UInt64

    struct ActionAutoCompoundDelegatedStake: Decodable {
        @BytesCodable var delegator: AccountId
        @BytesCodable var collator: AccountId
        @StringCodable var accountMinimum: BigUInt
        @StringCodable var frequency: Seconds
    }

    enum Action: Decodable {
        case unknown
        case notify
        case nativeTransfer
        case xcmp
        case autoCompoundDelegatedStake(_ params: ActionAutoCompoundDelegatedStake)

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Notify":
                self = .notify
            case "NativeTransfer":
                self = .nativeTransfer
            case "XCMP":
                self = .xcmp
            case "AutoCompoundDelegatedStake":
                let params = try container.decode(ActionAutoCompoundDelegatedStake.self)
                self = .autoCompoundDelegatedStake(params)
            default:
                self = .unknown
            }
        }
    }

    struct Task: Decodable {
        let action: AutomationTime.Action

        var autocompoundStakeCollator: AccountId? {
            switch action {
            case .unknown, .notify, .nativeTransfer, .xcmp:
                return nil
            case let .autoCompoundDelegatedStake(params):
                return params.collator
            }
        }
    }

    struct AccountTaskKey: Hashable, JSONListConvertible {
        let accountId: AccountId
        let taskId: AutomationTime.TaskId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            accountId = try jsonList[0].map(to: AccountId.self, with: context)
            taskId = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        }
    }
}
