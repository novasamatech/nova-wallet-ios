import Foundation

final class VotePresenter {
    weak var view: VoteViewProtocol?

    let interactor: VoteInteractorInputProtocol
    let wireframe: VoteWireframeProtocol
    let childPresenterFactory: VoteChildPresenterFactoryProtocol

    private var childPresenter: VoteChildPresenterProtocol?
    private var wallet: MetaAccountModel?

    private lazy var walletSwitchViewModelFactory = WalletSwitchViewModelFactory()

    init(
        interactor: VoteInteractorInputProtocol,
        wireframe: VoteWireframeProtocol,
        childPresenterFactory: VoteChildPresenterFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.childPresenterFactory = childPresenterFactory
    }

    private func provideWalletViewModel() {
        guard let wallet = wallet else {
            return
        }

        let viewModel = walletSwitchViewModelFactory.createViewModel(from: wallet.walletIdenticonData(), walletType: wallet.type)
        view?.didSwitchWallet(with: viewModel)
    }
}

extension VotePresenter: VotePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func becomeOnline() {
        childPresenter?.becomeOnline()
    }

    func putOffline() {
        childPresenter?.putOffline()
    }

    func selectChain() {
        childPresenter?.selectChain()
    }

    func selectWallet() {
        wireframe.showWalletSwitch(from: view)
    }

    func switchToGovernance(_ view: ReferendumsViewProtocol) {
        guard let wallet = wallet else {
            return
        }

        childPresenter?.putOffline()
        childPresenter = childPresenterFactory.createGovernancePresenter(from: view, wallet: wallet)
        childPresenter?.setup()
    }

    func switchToCrowdloans(_ view: CrowdloansViewProtocol) {
        guard let wallet = wallet else {
            return
        }

        childPresenter?.putOffline()
        childPresenter = childPresenterFactory.createCrowdloanPresenter(from: view, wallet: wallet)
        childPresenter?.setup()
    }
}

extension VotePresenter: VoteInteractorOutputProtocol {
    func didReceiveWallet(_ wallet: MetaAccountModel) {
        self.wallet = wallet

        provideWalletViewModel()
    }
}
