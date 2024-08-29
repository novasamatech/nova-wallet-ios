import Foundation

extension ReferendumsPresenter: VoteChildPresenterProtocol {
    func setup() {
        view?.update(model: .init(sections: viewModelFactory.createLoadingViewModel()))
        interactor.setup()
    }

    func becomeOnline() {
        interactor.becomeOnline()
    }

    func putOffline() {
        interactor.putOffline()
    }

    func selectChain() {
        wireframe.selectChain(
            from: view,
            delegate: self,
            chainId: chain?.chainId,
            governanceType: governanceType
        )
    }
}
