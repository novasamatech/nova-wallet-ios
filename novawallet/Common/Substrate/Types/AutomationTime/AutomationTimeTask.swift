import Foundation
import SubstrateSdk

extension AutomationTime {
    typealias TaskId = Data

    struct ActionAutoCompoundDelegatedStake: Decodable {
        @BytesCodable var delegator: AccountId
        @BytesCodable var collator: AccountId
    }

    enum Action: Decodable {
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
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected type"
                )
            }
        }
    }

    struct Task: Decodable {
        let action: AutomationTime.Action

        var autocompoundStakeCollator: AccountId? {
            switch action {
            case .notify, .nativeTransfer, .xcmp:
                return nil
            case let .autoCompoundDelegatedStake(params):
                return params.collator
            }
        }
    }
}
