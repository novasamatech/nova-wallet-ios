import Foundation

struct TinderGovViewFactory {
    static func createView() -> TinderGovViewProtocol? {
        let wireframe = TinderGovWireframe()
        let viewModel = TinderGovViewModel(wireframe: wireframe)
        let view = TinderGovViewController(viewModel: viewModel)

        viewModel.view = view

        return view
    }
}
