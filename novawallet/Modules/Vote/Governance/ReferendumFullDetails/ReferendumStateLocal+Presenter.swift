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
            return String(data: lookup.hash, encoding: .utf8)
        case let .legacy(hash):
            return String(data: hash, encoding: .utf8)
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
    // TODO: localize?
    var displayName: String {
        switch self {
        case .linearDecreasing:
            return "Linear Decreasing"
        case .reciprocal:
            return "Reciprocal"
        case .steppedDecreasing:
            return "Stepped Decreasing"
        case .unknown:
            return "Unknown"
        }
    }
}
