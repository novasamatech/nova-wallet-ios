import Foundation
import SubstrateSdk

final class YourWalletsPresenter {
    weak var view: YourWalletsViewProtocol?
    let wireframe: YourWalletsWireframeProtocol
    let interactor: YourWalletsInteractorInputProtocol
    weak var delegate: YourWalletsDelegate?
    let metaAccounts: [PossibleMetaAccountChainResponse]
    private lazy var walletIconGenerator = NovaIconGenerator()

    init(
        interactor: YourWalletsInteractorInputProtocol,
        wireframe: YourWalletsWireframeProtocol,
        metaAccounts: [PossibleMetaAccountChainResponse],
        delegate: YourWalletsDelegate
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.metaAccounts = metaAccounts
        self.delegate = delegate
    }

    private func updateView() throws {
        let viewModel: [YourWalletsViewModel] =
            try metaAccounts.map {
                if let displayAddress = try $0.chainAccountResponse?.toWalletDisplayAddress() {
                    return .common(
                        .init(
                            address: displayAddress.address,
                            name: displayAddress.walletName,
                            imageViewModel: try? icon(from: displayAddress.walletIconData)
                        ),
                        isSelected: false
                    )
                } else {
                    return .notFound(.init(
                        address: "",
                        name: $0.metaAccount.name,
                        imageViewModel: try? icon(from: $0.metaAccount.substrateAccountId)
                    ))
                }
            }
        view?.update(viewModel: viewModel)
    }

    private func icon(from imageData: Data?) throws -> DrawableIconViewModel? {
        try imageData.map { data in
            let icon = try walletIconGenerator.generateFromAccountId(data)
            return DrawableIconViewModel(icon: icon)
        }
    }
}

extension YourWalletsPresenter: YourWalletsPresenterProtocol {
    func setup() {
        try? updateView()
    }

    func didSelect(viewModel: DisplayAddressViewModel) {
        delegate?.selectWallet(address: viewModel.address)
        view?.controller.dismiss(animated: true)
    }
}

extension YourWalletsPresenter: YourWalletsInteractorOutputProtocol {}
