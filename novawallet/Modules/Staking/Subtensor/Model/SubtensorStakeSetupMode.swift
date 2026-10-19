import Foundation

enum SubtensorStakeSetupMode: Equatable {
    case quickPick(SubtensorQuickPickOrder)
    case rootDetails
    case subnetPick(target: SubtensorStakeTarget, validator: SubtensorValidatorDirectoryItem?)
    case addStake(position: SubtensorPosition)
    case buyMore(position: SubtensorPosition)
}

extension SubtensorStakeSetupMode {
    var origin: SubtensorOperationOrigin {
        switch self {
        case .quickPick, .rootDetails, .subnetPick:
            return .newPosition
        case .addStake:
            return .addStake
        case .buyMore:
            return .buyMore
        }
    }

    var netuid: UInt16? {
        switch self {
        case .quickPick: return nil
        case .rootDetails:
            return SubtensorPallet.rootNetuid
        case let .subnetPick(target, _):
            return target.netuid
        case let .addStake(position), let .buyMore(position):
            return position.netuid
        }
    }

    var isRootLane: Bool {
        netuid == SubtensorPallet.rootNetuid
    }

    var lockedHotkey: AccountId? {
        switch self {
        case .quickPick, .rootDetails, .subnetPick:
            return nil
        case let .addStake(position), let .buyMore(position):
            return position.hotkey
        }
    }

    var isLocked: Bool {
        lockedHotkey != nil
    }

    var hasSettings: Bool {
        switch self {
        case .quickPick, .subnetPick:
            return true
        case .rootDetails, .addStake, .buyMore:
            return false
        }
    }

    var initialTarget: SubtensorStakeTarget? {
        switch self {
        case .rootDetails, .addStake:
            return .root
        case let .subnetPick(target, _):
            return target
        case .quickPick, .buyMore:
            return nil
        }
    }

    var pickedValidator: SubtensorValidatorDirectoryItem? {
        if case let .subnetPick(_, validator) = self {
            return validator
        }

        return nil
    }
}
