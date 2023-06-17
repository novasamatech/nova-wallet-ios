import Foundation
import SubstrateSdk
import BigInt

extension Staking {
    enum Bond {
        struct V1: Codable {
            var controller: MultiAddress
            @StringCodable var value: BigUInt
            var payee: RewardDestinationArg
        }

        struct V2: Codable {
            @StringCodable var value: BigUInt
            var payee: RewardDestinationArg
        }

        static let path = CallCodingPath(moduleName: Staking.module, callName: "bond")

        static func appendCall(
            for controller: MultiAddress,
            value: BigUInt,
            payee: RewardDestinationArg,
            codingFactory: RuntimeCoderFactoryProtocol
        ) throws -> ExtrinsicBuilderClosure {
            guard let callMetadata = codingFactory.getCall(for: path) else {
                throw CommonError.dataCorruption
            }

            return { builder in
                if callMetadata.hasArgument(named: "controller") {
                    let call = V1(
                        controller: controller,
                        value: value,
                        payee: payee
                    )

                    return try builder.adding(
                        call: RuntimeCall(moduleName: path.moduleName, callName: path.callName, args: call)
                    )
                } else {
                    let call = V2(value: value, payee: payee)

                    return try builder.adding(
                        call: RuntimeCall(moduleName: path.moduleName, callName: path.callName, args: call)
                    )
                }
            }
        }
    }

    enum RewardDestinationArg: Equatable, Codable {
        static let stakedField = "Staked"
        static let stashField = "Stash"
        static let controllerField = "Controller"
        static let accountField = "Account"

        case staked
        case stash
        case controller
        case account(_ accountId: Data)

        init(rewardDestination: RewardDestination<String>) throws {
            switch rewardDestination {
            case .restake:
                self = .staked
            case let .payout(address):
                let accountId = try address.toAccountId()
                self = .account(accountId)
            }
        }

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case Self.stakedField:
                self = .staked
            case Self.stashField:
                self = .stash
            case Self.controllerField:
                self = .controller
            case Self.accountField:
                let data = try container.decode(Data.self)
                self = .account(data)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected type"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .staked:
                try container.encode(Self.stakedField)
                try container.encodeNil()
            case .stash:
                try container.encode(Self.stashField)
                try container.encodeNil()
            case .controller:
                try container.encode(Self.controllerField)
                try container.encodeNil()
            case let .account(data):
                try container.encode(Self.accountField)
                try container.encode(data)
            }
        }
    }
}
