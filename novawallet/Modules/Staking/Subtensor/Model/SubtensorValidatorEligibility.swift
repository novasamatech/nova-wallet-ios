import Foundation

enum SubtensorValidatorEligibility: Equatable {
    case unlisted
    case inactive
    case selectable
}

extension SubtensorValidatorEligibility {
    static func eligibility(
        of item: SubtensorValidatorDirectoryItem,
        isRoot: Bool,
        gates: SubtensorClientGates
    ) -> SubtensorValidatorEligibility {
        guard
            let status = item.status,
            isRoot || status.hasPermit == true,
            let take = item.take,
            let maxTake = gates.maxTake.decimalValue,
            take <= maxTake else {
            return .unlisted
        }

        return isRoot || status.isActive == true ? .selectable : .inactive
    }

    static func preselectedHotkey(
        _ current: AccountId?,
        in directory: SubtensorValidatorDirectory,
        isRoot: Bool,
        gates: SubtensorClientGates
    ) -> AccountId? {
        selectableItem(for: current, in: directory, isRoot: isRoot, gates: gates)?.hotkey
    }

    static func selectableItem(
        for hotkey: AccountId?,
        in directory: SubtensorValidatorDirectory?,
        isRoot: Bool,
        gates: SubtensorClientGates
    ) -> SubtensorValidatorDirectoryItem? {
        directory?.items.first { item in
            item.hotkey == hotkey && eligibility(of: item, isRoot: isRoot, gates: gates) == .selectable
        }
    }
}
