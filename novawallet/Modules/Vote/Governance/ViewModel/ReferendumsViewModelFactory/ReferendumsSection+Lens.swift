extension ReferendumsSection {
    enum Lens {
        static let referendums = GenericLens<ReferendumsSection, [ReferendumsCellViewModel]>(
            get: { whole in
                switch whole {
                case .personalActivities, .settings, .empty:
                    return []
                case let .active(_, activeReferendums):
                    return activeReferendums
                case let .completed(_, completedReferendums):
                    return completedReferendums
                }
            }, set: { part, whole in
                switch whole {
                case .personalActivities, .settings, .empty:
                    return whole
                case let .active(title, _):
                    return .active(title, part)
                case let .completed(title, _):
                    return .completed(title, part)
                }
            }
        )
    }
}
