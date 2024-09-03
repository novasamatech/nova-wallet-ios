import Foundation

struct TinderGovViewFactory {
    static func createView(with referendums: [ReferendumLocal]) -> TinderGovViewProtocol? {
        let wireframe = TinderGovWireframe()

        let viewModel = TinderGovViewModel(
            wireframe: wireframe,
            viewModelFactory: TinderGovViewModelFactory(),
            referendums: referendums
        )

        let view = TinderGovViewController(viewModel: viewModel)

        return view
    }
}
