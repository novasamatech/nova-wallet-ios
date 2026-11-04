import Foundation
import Foundation_iOS

final class GetTokenOptionsPresenter {
    weak var view: GetTokenOptionsViewProtocol?
    let interactor: GetTokenOptionsInteractorInputProtocol
    let wireframe: GetTokenOptionsWireframeProtocol
    let destinationChainAsset: ChainAsset

    let allOperations: [GetTokenOperation]

    private var model: GetTokenOptionsModel?

    init(
        interactor: GetTokenOptionsInteractorInputProtocol,
        wireframe: GetTokenOptionsWireframeProtocol,
        destinationChainAsset: ChainAsset,
        allOperations: [GetTokenOperation]
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.destinationChainAsset = destinationChainAsset
        self.allOperations = allOperations
    }

    private func isOperationAvailable(_ operation: GetTokenOperation) -> Bool {
        guard let model = model else {
            return false
        }

        switch operation {
        case .crosschain:
            return !model.availableXcmOrigins.isEmpty
        case .receive:
            return model.receiveAccount != nil
        case .buy:
            return !model.buyOptions.isEmpty
        case .changeNow:
            return model.changeNowUrl != nil
        }
    }

    private func provideViewModel() {
        let viewModels = allOperations.map { operation in
            let isActive = isOperationAvailable(operation)
            let token = destinationChainAsset.asset.symbol

            return LocalizableResource { locale in
                TokenOperationTableViewCell.Model(
                    content: .init(
                        title: operation.titleForLocale(locale),
                        subtitle: operation.subtitleForLocale(locale, token: token),
                        icon: operation.icon
                    ),
                    chip: operation.chipForLocale(locale),
                    isActive: isActive
                )
            }
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension GetTokenOptionsPresenter: GetTokenOptionsPresenterProtocol {
    func setup() {
        provideViewModel()

        interactor.setup()
    }

    func selectOption(at index: Int) {
        guard let model = model else {
            return
        }

        switch allOperations[index] {
        case .crosschain:
            if let xcmTransfers = model.xcmTransfers {
                wireframe.complete(
                    on: view,
                    result: .crosschains(model.availableXcmOrigins, xcmTransfers)
                )
            }
        case .receive:
            if let account = model.receiveAccount {
                wireframe.complete(on: view, result: .receive(account))
            }
        case .buy:
            wireframe.complete(on: view, result: .buy(model.buyOptions))
        case .changeNow:
            if let url = model.changeNowUrl {
                wireframe.complete(on: view, result: .changeNow(url))
            }
        }
    }
}

extension GetTokenOptionsPresenter: GetTokenOptionsInteractorOutputProtocol {
    func didReceive(model: GetTokenOptionsModel) {
        self.model = model
        provideViewModel()
    }
}
