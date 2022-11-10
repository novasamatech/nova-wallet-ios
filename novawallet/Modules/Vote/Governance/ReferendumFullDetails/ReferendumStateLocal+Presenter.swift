import Foundation
import BigInt

extension ReferendumStateLocal {
    func functionInfo(locale: Locale) -> ReferendumFullDetailsViewModel.FunctionInfo? {
        switch voting {
        case let .supportAndVotes(model):
            guard let supportCurve = model.supportFunction?.curve,
                  let approvalCurve = model.approvalFunction?.curve else {
                return nil
            }
            return .supportAndVotes(
                approveCurve: approvalCurve.displayName(for: locale),
                supportCurve: supportCurve.displayName(for: locale)
            )
        case let .threshold(model):
            let thresholdTypeName = model.thresholdFunction.thresholdType.displayName(for: locale)
            return .threshold(function: thresholdTypeName)
        case .none:
            return nil
        }
    }

    var electorate: BigUInt? {
        switch voting {
        case let .supportAndVotes(model):
            return model.totalIssuance
        case let .threshold(model):
            return model.electorate
        case .none:
            return nil
        }
    }

    var turnout: BigUInt? {
        switch voting {
        case let .supportAndVotes(model):
            return model.support
        case let .threshold(model):
            return model.turnout
        case .none:
            return nil
        }
    }

    var callHash: String? {
        switch proposal {
        case let .lookup(lookup):
            return lookup.hash.toHex(includePrefix: true)
        case let .legacy(hash):
            return hash.toHex(includePrefix: true)
        case .inline, .unknown, .none:
            return nil
        }
    }

    var voting: Voting? {
        switch self {
        case let .preparing(model):
            return model.voting
        case let .deciding(model):
            return model.voting
        case .approved,
             .rejected,
             .cancelled,
             .timedOut,
             .killed,
             .executed:
            return nil
        }
    }
}

extension Referenda.Curve {
    func displayName(for locale: Locale) -> String {
        switch self {
        case .linearDecreasing:
            return R.string.localizable.govLinearDecreasing(preferredLanguages: locale.rLanguages)
        case .reciprocal:
            return R.string.localizable.govReciprocal(preferredLanguages: locale.rLanguages)
        case .steppedDecreasing:
            return R.string.localizable.govSteppedDecreasing(preferredLanguages: locale.rLanguages)
        case .unknown:
            return R.string.localizable.govUnknown(preferredLanguages: locale.rLanguages)
        }
    }
}

extension Democracy.VoteThreshold {
    func displayName(for locale: Locale) -> String {
        switch self {
        case .simpleMajority:
            return R.string.localizable.govVoteTresholdFunctionSimpleMajority(preferredLanguages: locale.rLanguages)
        case .superMajorityAgainst:
            return R.string.localizable.govVoteTresholdFunctionSuperMajorityAgainst(
                preferredLanguages: locale.rLanguages)
        case .superMajorityApprove:
            return R.string.localizable.govVoteTresholdFunctionSuperMajorityApprove(
                preferredLanguages: locale.rLanguages)
        case .unknown:
            return R.string.localizable.govUnknown(
                preferredLanguages: locale.rLanguages)
        }
    }
}
