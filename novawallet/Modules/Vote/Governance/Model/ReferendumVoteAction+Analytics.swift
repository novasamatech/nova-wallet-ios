import Foundation
import NovaAnalytics

extension ReferendumVoteAction {
    var analyticsDirection: VoteDirection {
        switch self {
        case .aye:
            .aye
        case .nay:
            .nay
        case .abstain:
            .abstain
        }
    }

    var analyticsConviction: ConvictionLevel? {
        switch self {
        case .aye, .nay:
            conviction().analyticsLevel
        case .abstain:
            nil
        }
    }
}

private extension ConvictionVoting.Conviction {
    var analyticsLevel: ConvictionLevel? {
        switch self {
        case .none:
            .noLockup
        case .locked1x:
            .locked1x
        case .locked2x:
            .locked2x
        case .locked3x:
            .locked3x
        case .locked4x:
            .locked4x
        case .locked5x:
            .locked5x
        case .locked6x:
            .locked6x
        case .unknown:
            nil
        }
    }
}
