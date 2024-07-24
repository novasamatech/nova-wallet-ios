import Foundation

protocol ReferendumsSorting {
    func compare(referendum1: ReferendumLocal, referendum2: ReferendumLocal) -> Bool
}

final class ReferendumsTimeSortingProvider {
    private func getGroup(for referendum: ReferendumLocal) -> UInt32 {
        referendum.state.completed ? 1 : 0
    }

    private func getPositionForOngoing(referendum: ReferendumLocal) -> UInt32 {
        switch referendum.state {
        case let .preparing(model):
            return model.timeoutAt
        case let .deciding(model):
            if let confirmation = model.confirmationUntil {
                return confirmation
            } else {
                return model.rejectedAt
            }
        default:
            return UInt32.max
        }
    }

    private func getPositionForCompleted(referendum: ReferendumLocal) -> UInt32 {
        switch referendum.state {
        case let .approved(model):
            if let executeAt = model.whenEnactment {
                return executeAt
            } else {
                return UInt32.max
            }
        default:
            return UInt32.max
        }
    }
}

extension ReferendumsTimeSortingProvider: ReferendumsSorting {
    func compare(referendum1: ReferendumLocal, referendum2: ReferendumLocal) -> Bool {
        let group1 = getGroup(for: referendum1)
        let group2 = getGroup(for: referendum2)

        guard group1 == group2 else {
            return group1 < group2
        }

        let pos1: UInt32
        let pos2: UInt32

        if referendum1.state.completed {
            pos1 = getPositionForCompleted(referendum: referendum1)
            pos2 = getPositionForCompleted(referendum: referendum2)
        } else {
            pos1 = getPositionForOngoing(referendum: referendum1)
            pos2 = getPositionForOngoing(referendum: referendum2)
        }

        guard pos1 != pos2 else {
            return referendum1.index > referendum2.index
        }

        return pos1 < pos2
    }
}
