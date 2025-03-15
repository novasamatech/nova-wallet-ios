import Foundation
import SubstrateSdk

enum DryRun {
    static let apiName = "DryRunApi"
    
    enum Origin: Encodable {
        case system(SystemOrigin)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .system(model):
                try container.encode("System")
                try container.encode(model)
            }
        }
    }

    enum SystemOrigin: Encodable {
        case root
        case signed(AccountId)
        case none

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .root:
                try container.encode("Root")
                try container.encode(JSON.null)
            case let .signed(accountId):
                try container.encode("Signed")
                try container.encode(BytesCodable(wrappedValue: accountId))
            case .none:
                try container.encode("None")
                try container.encode(JSON.null)
            }
        }
    }
}
