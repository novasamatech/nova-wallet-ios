import Foundation
import SubstrateSdk

final class YourWalletsPresenter {
    weak var view: YourWalletsViewProtocol?
    weak var delegate: YourWalletsDelegate?

    let wireframe: YourWalletsWireframeProtocol
    let metaAccounts: [PossibleMetaAccountChainResponse]
    let iconGenerator: IconGenerating
    private(set) var selectedAddress: AccountAddress?

    init(
        wireframe: YourWalletsWireframeProtocol,
        iconGenerator: IconGenerating,
        metaAccounts: [PossibleMetaAccountChainResponse],
        selectedAddress: AccountAddress?,
        delegate: YourWalletsDelegate
    ) {
        self.wireframe = wireframe
        self.iconGenerator = iconGenerator
        self.metaAccounts = metaAccounts
        self.selectedAddress = selectedAddress
        self.delegate = delegate
    }

    private func updateView() {
        var createdSections: [MetaAccountModelType: Int] = [:]
        var sections: [YourWalletsViewSectionModel] = []

        for metaAccount in metaAccounts {
            if let existsSectionIndex = createdSections[metaAccount.metaAccount.type] {
                sections[existsSectionIndex].cells.append(cell(response: metaAccount))
            } else {
                sections.append(.init(
                    header: header(response: metaAccount),
                    cells: .init()
                ))
                createdSections[metaAccount.metaAccount.type] = createdSections.count
            }
        }

        view?.update(viewModel: sections)
    }

    private func header(response: PossibleMetaAccountChainResponse) -> YourWalletsViewSectionModel.HeaderModel? {
        switch response.metaAccount.type {
        case .watchOnly, .secrets:
            return nil
        case .paritySigner:
            return .init(
                title: "Parity Signer",
                icon: R.image.iconParitySigner()
            )
        }
    }

    private func cell(response: PossibleMetaAccountChainResponse) -> YourWalletsViewModelCell {
        let name = response.metaAccount.name
        let imageViewModel = icon(from: response.metaAccount.substrateAccountId)

        guard let displayAddress = try? response.chainAccountResponse?.chainAccount.toDisplayAddress() else {
            return .notFound(.init(name: name, imageViewModel: imageViewModel))
        }

        return .common(.init(
            displayAddress: displayAddress,
            imageViewModel: imageViewModel,
            isSelected: selectedAddress == displayAddress.address
        ))
    }

    private func icon(from imageData: Data?) -> DrawableIconViewModel? {
        guard let data = imageData else {
            return nil
        }
        guard let icon = try? iconGenerator.generateFromAccountId(data) else {
            return nil
        }

        return DrawableIconViewModel(icon: icon)
    }
}

extension YourWalletsPresenter: YourWalletsPresenterProtocol {
    func setup() {
        updateView()
    }

    func didSelect(viewModel: YourWalletsViewModelCell.CommonModel) {
        selectedAddress = viewModel.displayAddress.address
        delegate?.selectWallet(address: viewModel.displayAddress.address)
    }
}
