import Foundation

final class SwapTokenSelectNetworksPresenter {
    weak var view: SwapTokenSelectNetworksViewProtocol?
    let wireframe: SwapTokenSelectNetworksWireframeProtocol
    let completion: ([ChainModel.Id]) -> Void

    private var viewModels: [SwapTokenSelectNetworkViewModel]

    init(
        wireframe: SwapTokenSelectNetworksWireframeProtocol,
        viewModels: [SwapTokenSelectNetworkViewModel],
        completion: @escaping ([ChainModel.Id]) -> Void
    ) {
        self.wireframe = wireframe
        self.viewModels = viewModels
        self.completion = completion
    }
}

// MARK: SwapTokenSelectNetworksPresenterProtocol

extension SwapTokenSelectNetworksPresenter: SwapTokenSelectNetworksPresenterProtocol {
    func setup() {
        view?.didReceive(viewModels: viewModels)
    }

    func toggleNetwork(at index: Int) {
        guard viewModels.indices.contains(index) else {
            return
        }

        let viewModel = viewModels[index]

        viewModels[index] = SwapTokenSelectNetworkViewModel(
            chainId: viewModel.chainId,
            network: viewModel.network,
            isSelected: !viewModel.isSelected
        )

        view?.didReceive(viewModels: viewModels)
    }

    func confirm() {
        let chainIds = viewModels.filter(\.isSelected).map(\.chainId)

        completion(chainIds)
        wireframe.close(view: view)
    }
}
