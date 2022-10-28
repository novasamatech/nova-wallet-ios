import Foundation

extension ReferendumStateLocal {
    var approvalCurve: Referenda.Curve? {
        switch voting {
        case let .supportAndVotes(model):
            return model.approvalFunction?.curve
        case .none:
            return nil
        }
    }

    var supportCurve: Referenda.Curve? {
        switch voting {
        case let .supportAndVotes(model):
            return model.supportFunction?.curve
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
