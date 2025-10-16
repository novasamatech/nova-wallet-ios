import Foundation
import Foundation_iOS

final class NetworkManageNodePresenter {
    weak var view: NetworkManageNodeViewProtocol?
    var wireframe: NetworkManageNodeWireframeProtocol

    var onNodeEdit: () -> Void
    var onNodeDelete: () -> Void

    let node: ChainNodeModel

    init(
        wireframe: NetworkManageNodeWireframeProtocol,
        node: ChainNodeModel,
        localizationManager: LocalizationManagerProtocol,
        onNodeEdit: @escaping () -> Void,
        onNodeDelete: @escaping () -> Void
    ) {
        self.wireframe = wireframe
        self.node = node

        self.onNodeEdit = onNodeEdit
        self.onNodeDelete = onNodeDelete

        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let actions: [NetworkManageNodeViewModel.Action] = [
            .init(
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.networkManageNodeEdit(),
                icon: R.image.iconPencil(),
                negative: false,
                onSelection: { [weak self] in
                    guard let self else { return }

                    onNodeEdit()
                    wireframe.dismiss(view)
                }
            ),
            .init(
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.networkManageNodeDelete(),
                icon: R.image.iconDelete(),
                negative: true,
                onSelection: { [weak self] in
                    guard let self else { return }

                    onNodeDelete()
                    wireframe.dismiss(view)
                }
            )
        ]

        let viewModel = NetworkManageNodeViewModel(
            title: R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.networkManageNodeManageAddedNode(),
            nodeName: node.name,
            actions: actions
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: NetworkManageNodePresenterProtocol

extension NetworkManageNodePresenter: NetworkManageNodePresenterProtocol {
    func setup() {
        provideViewModel()
    }
}

// MARK: Localizable

extension NetworkManageNodePresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel()
    }
}
