import Foundation

enum SubtensorStakingSetupMode: Equatable {
    case rootDetails
    case subnetPick(target: SubtensorStakeTarget, validator: SubtensorValidatorDirectoryItem?)
    case addStake(position: SubtensorStakingPosition)
    case buyMore(position: SubtensorStakingPosition)
}

extension SubtensorStakingSetupMode {
    var origin: SubtensorOperationOrigin {
        switch self {
        case .rootDetails, .subnetPick:
            return .newPosition
        case .addStake:
            return .addStake
        case .buyMore:
            return .buyMore
        }
    }

    var netuid: UInt16 {
        switch self {
        case .rootDetails:
            return SubtensorStakingPallet.rootNetuid
        case let .subnetPick(target, _):
            return target.netuid
        case let .addStake(position), let .buyMore(position):
            return position.netuid
        }
    }

    var isRootLane: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    var lockedHotkey: AccountId? {
        switch self {
        case .rootDetails, .subnetPick:
            return nil
        case let .addStake(position), let .buyMore(position):
            return position.hotkey
        }
    }

    var isLocked: Bool {
        lockedHotkey != nil
    }

    var hasSettings: Bool {
        if case .subnetPick = self {
            return true
        }

        return false
    }

    var initialTarget: SubtensorStakeTarget? {
        switch self {
        case .rootDetails, .addStake:
            return .root
        case let .subnetPick(target, _):
            return target
        case .buyMore:
            return nil
        }
    }

    var pickedValidator: SubtensorValidatorDirectoryItem? {
        if case let .subnetPick(_, validator) = self {
            return validator
        }

        return nil
    }

    static func mode(for position: SubtensorStakingPosition) -> SubtensorStakingSetupMode {
        position.netuid == SubtensorStakingPallet.rootNetuid ? .addStake(position: position) :
            .buyMore(position: position)
    }
}
