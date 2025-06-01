import Foundation

final class ChainAddressDetailsPresenter {
    weak var view: ChainAddressDetailsViewProtocol?
    let wireframe: ChainAddressDetailsWireframeProtocol

    let model: ChainAddressDetailsModel

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    init(
        wireframe: ChainAddressDetailsWireframeProtocol,
        model: ChainAddressDetailsModel
    ) {
        self.wireframe = wireframe
        self.model = model
    }
}

private extension ChainAddressDetailsPresenter {
    private func createTitleViewModel() -> ChainAddressDetailsViewModel.Title {
        switch model.title {
        case let .network(network):
            let viewModel = NetworkViewModel(
                name: network.chainName,
                icon: ImageViewModelFactory.createChainIconOrDefault(from: network.chainIcon)
            )

            return .network(viewModel)
        case let .text(text):
            return .text(text)
        }
    }

    private func provideViewModel() {
        let titleViewModel = createTitleViewModel()

        let actions = model.actions.map { action in
            ChainAddressDetailsViewModel.Action(
                title: action.title,
                icon: action.icon,
                indicator: action.indicator
            )
        }

        let addressViewModel = model.address.map { displayAddressFactory.createViewModel(from: $0) }

        let viewModel = ChainAddressDetailsViewModel(
            title: titleViewModel,
            address: addressViewModel,
            actions: actions
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension ChainAddressDetailsPresenter: ChainAddressDetailsPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func selectAction(at index: Int) {
        guard let view = view else {
            return
        }

        wireframe.complete(view: view, action: model.actions[index])
    }
}
