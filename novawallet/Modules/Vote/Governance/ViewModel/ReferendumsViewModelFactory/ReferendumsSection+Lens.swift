extension ReferendumsSection {
    enum Lens {
        static let referendums = GenericLens<ReferendumsSection, [ReferendumsCellViewModel]>(
            get: { whole in
                switch whole {
                case .personalActivities, .swipeGov, .settings, .empty:
                    []
                case let .active(viewModel), let .completed(viewModel):
                    viewModel.cells
                }
            }, set: { part, whole in
                switch whole {
                case .personalActivities, .swipeGov, .settings, .empty:
                    whole
                case let .active(viewModel):
                    .active(
                        ReferendumsCellsSectionViewModel(
                            titleText: viewModel.titleText,
                            countText: viewModel.countText,
                            cells: part
                        )
                    )
                case let .completed(viewModel):
                    .completed(
                        ReferendumsCellsSectionViewModel(
                            titleText: viewModel.titleText,
                            countText: viewModel.countText,
                            cells: part
                        )
                    )
                }
            }
        )
    }
}
