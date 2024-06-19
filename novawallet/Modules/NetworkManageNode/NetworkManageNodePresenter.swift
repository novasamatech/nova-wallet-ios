import Foundation
import SoraFoundation

final class NetworkManageNodePresenter {
    weak var view: NetworkManageNodeViewProtocol?
    
    var onNodeEdit: () -> Void
    var onNodeDelete: () -> Void
    
    let node: ChainNodeModel

    init(
        node: ChainNodeModel,
        localizationManager: LocalizationManagerProtocol,
        onNodeEdit: @escaping () -> Void,
        onNodeDelete: @escaping () -> Void
    ) {
        self.node = node
        
        self.onNodeEdit = onNodeEdit
        self.onNodeDelete = onNodeDelete
        
        self.localizationManager = localizationManager
    }
    
    private func provideViewModel() {
        let actions: [NetworkManageNodeViewModel.Action] = [
            .init(
                title: R.string.localizable.networkManageNodeEdit(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                icon: R.image.iconPencilEdit(),
                onSelection: onNodeEdit,
                negative: false
            ),
            .init(
                title: R.string.localizable.networkManageNodeDelete(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                icon: R.image.iconDelete(),
                onSelection: onNodeDelete,
                negative: true
            )
        ]

        let viewModel = NetworkManageNodeViewModel(
            title: R.string.localizable.networkManageNodeManageAddedNode(
                preferredLanguages: selectedLocale.rLanguages
            ),
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
