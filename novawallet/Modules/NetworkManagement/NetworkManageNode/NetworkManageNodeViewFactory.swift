import Foundation
import Foundation_iOS

struct NetworkManageNodeViewFactory {
    static func createView(
        node: ChainNodeModel,
        onNodeEdit: @escaping () -> Void,
        onNodeDelete: @escaping () -> Void
    ) -> NetworkManageNodeViewProtocol? {
        let wireframe = NetworkManageNodeWireframe()
        let presenter = NetworkManageNodePresenter(
            wireframe: wireframe,
            node: node,
            localizationManager: LocalizationManager.shared,
            onNodeEdit: onNodeEdit,
            onNodeDelete: onNodeDelete
        )

        let view = NetworkManageNodeViewController(presenter: presenter)

        let preferredHeight = NetworkManageNodeMeasurement.measurePreferredHeight(
            for: [onNodeEdit, onNodeDelete].count
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: preferredHeight)

        presenter.view = view

        return view
    }
}
