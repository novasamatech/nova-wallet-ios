import Foundation

extension ReferendumsPresenter: VoteChildPresenterProtocol {
    func setup() {
        provideLoadingViewModel()
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
