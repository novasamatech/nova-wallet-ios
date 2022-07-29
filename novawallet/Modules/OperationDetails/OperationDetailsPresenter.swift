import Foundation
import SoraFoundation

final class OperationDetailsPresenter {
    weak var view: OperationDetailsViewProtocol?
    let wireframe: OperationDetailsWireframeProtocol
    let interactor: OperationDetailsInteractorInputProtocol
    let viewModelFactory: OperationDetailsViewModelFactoryProtocol

    let chainAsset: ChainAsset

    private(set) var model: OperationDetailsModel?

    init(
        interactor: OperationDetailsInteractorInputProtocol,
        wireframe: OperationDetailsWireframeProtocol,
        viewModelFactory: OperationDetailsViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let model = model else {
            return
        }

        let viewModel = viewModelFactory.createViewModel(
            from: model,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func presentAddressOptions(_ address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: chainAsset.chain.explorers,
            locale: selectedLocale
        )
    }

    private func presentTransactionHashOptions(_ transactionHash: String) {
        guard let view = view else {
            return
        }

        wireframe.presentTransactionHashOptions(
            from: view,
            transactionHash: transactionHash,
            explorers: chainAsset.chain.explorers,
            locale: selectedLocale
        )
    }

    private func presentEventIdOptions(_ eventId: String) {
        guard let view = view else {
            return
        }

        wireframe.presentEventIdOptions(
            from: view,
            eventId: eventId,
            explorers: chainAsset.chain.explorers,
            locale: selectedLocale
        )
    }
}

extension OperationDetailsPresenter: OperationDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func showSenderActions() {
        switch model?.operation {
        case let .transfer(transferModel):
            presentAddressOptions(transferModel.sender.address)
        case let .extrinsic(extrinsicModel):
            presentAddressOptions(extrinsicModel.sender.address)
        case let .reward(internalModel):
            if let validator = internalModel.validator {
                presentAddressOptions(validator.address)
            }
        case let .slash(internalModel):
            if let validator = internalModel.validator {
                presentAddressOptions(validator.address)
            }
        case .none:
            break
        }
    }

    func showRecepientActions() {
        if case let .transfer(transferModel) = model?.operation {
            presentAddressOptions(transferModel.receiver.address)
        }
    }

    func showOperationActions() {
        switch model?.operation {
        case let .transfer(transferModel):
            presentTransactionHashOptions(transferModel.txHash)
        case let .extrinsic(extrinsicModel):
            presentTransactionHashOptions(extrinsicModel.txHash)
        case let .reward(rewardModel):
            presentEventIdOptions(rewardModel.eventId)
        case let .slash(slashModel):
            presentEventIdOptions(slashModel.eventId)
        case .none:
            break
        }
    }

    func send() {
        if case let .transfer(transferModel) = model?.operation {
            let peer = transferModel.outgoing ? transferModel.receiver : transferModel.sender

            wireframe.showSend(
                from: view,
                displayAddress: peer,
                chainAsset: chainAsset
            )
        }
    }
}

extension OperationDetailsPresenter: OperationDetailsInteractorOutputProtocol {
    func didReceiveDetails(result: Result<OperationDetailsModel, Error>) {
        switch result {
        case let .success(model):
            self.model = model
            updateView()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

extension OperationDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
