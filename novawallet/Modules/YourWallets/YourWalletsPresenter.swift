import Foundation
import SubstrateSdk
import SoraFoundation

final class YourWalletsPresenter {
    weak var view: YourWalletsViewProtocol?
    weak var delegate: YourWalletsDelegate?

    let metaAccounts: [MetaAccountChainResponse]
    let accountIconGenerator: IconGenerating
    let chainIconGenerator: IconGenerating
    private(set) var selectedAddress: AccountAddress?
    private(set) var sections: [YourWalletsViewSectionModel] = []

    init(
        localizationManager: LocalizationManagerProtocol,
        accountIconGenerator: IconGenerating,
        chainIconGenerator: IconGenerating,
        metaAccounts: [MetaAccountChainResponse],
        selectedAddress: AccountAddress?,
        delegate: YourWalletsDelegate
    ) {
        self.accountIconGenerator = accountIconGenerator
        self.metaAccounts = metaAccounts
        self.selectedAddress = selectedAddress
        self.chainIconGenerator = chainIconGenerator
        self.delegate = delegate
        self.localizationManager = localizationManager
    }

    private func updateView() {
        var createdSections: [MetaAccountModelType: Int] = [:]

        for metaAccount in metaAccounts {
            if let existsSectionIndex = createdSections[metaAccount.metaAccount.type] {
                sections[existsSectionIndex].cells.append(cell(response: metaAccount))
            } else {
                sections.append(.init(
                    header: header(response: metaAccount),
                    cells: [cell(response: metaAccount)]
                ))
                createdSections[metaAccount.metaAccount.type] = createdSections.count
            }
        }

        let title = R.string.localizable.assetsSelectSendYourWallets(preferredLanguages: selectedLocale.rLanguages)
        view?.update(viewModel: sections)
        view?.update(header: title)
    }

    private func updateSelectedCell() {
        sections.updateCells { cell in
            guard case var .common(model) = cell else {
                return
            }
            model.isSelected = selectedAddress == model.displayAddress.address
            cell = .common(model)
        }

        view?.update(viewModel: sections)
    }

    private func header(response: MetaAccountChainResponse) -> YourWalletsViewSectionModel.HeaderViewModel? {
        switch response.metaAccount.type {
        case .watchOnly, .secrets:
            return nil
        case .paritySigner:
            return .init(
                title: R.string.localizable.commonParitySigner(preferredLanguages: selectedLocale.rLanguages),
                icon: R.image.iconParitySigner()
            )
        }
    }

    private func cell(response: MetaAccountChainResponse) -> YourWalletsCellViewModel {
        let name = response.metaAccount.name
        let imageViewModel = icon(
            generator: accountIconGenerator,
            from: response.metaAccount.substrateAccountId
        )
        guard let chainAccountResponse = response.chainAccountResponse,
              let displayAddress = try? chainAccountResponse.chainAccount.toDisplayAddress() else {
            let message = R.string.localizable.accountNotFoundCaption(preferredLanguages: selectedLocale.rLanguages)
            return .warning(.init(accountName: name, warning: message, imageViewModel: imageViewModel))
        }

        let chainAccountIcon = icon(
            generator: chainIconGenerator,
            from: chainAccountResponse.chainAccount.accountId
        )
        return .common(.init(
            displayAddress: displayAddress,
            imageViewModel: imageViewModel,
            chainIcon: chainAccountIcon,
            isSelected: selectedAddress == displayAddress.address
        ))
    }

    private func icon(generator: IconGenerating, from imageData: Data?) -> DrawableIconViewModel? {
        guard let data = imageData,
              let icon = try? generator.generateFromAccountId(data) else {
            return nil
        }

        return DrawableIconViewModel(icon: icon)
    }

    var contentHeight: CGFloat {
        let sections = Dictionary(grouping: metaAccounts) { $0.metaAccount.type }.count
        return view?.calculateEstimatedHeight(
            sections: sections,
            items: metaAccounts.count
        ) ?? 0
    }
}

// MARK: - YourWalletsPresenterProtocol

extension YourWalletsPresenter: YourWalletsPresenterProtocol {
    func setup() {
        updateView()
    }

    func didSelect(viewModel: YourWalletsCellViewModel.CommonModel) {
        selectedAddress = viewModel.displayAddress.address
        updateSelectedCell()
        delegate?.didSelectYourWallet(address: viewModel.displayAddress.address)
    }

    func viewWillDisappear() {
        delegate?.didCloseYourWalletSelection()
    }
}

// MARK: - Localizable

extension YourWalletsPresenter: Localizable {
    func applyLocalization() {
        guard let view = view, view.isSetup else {
            return
        }
        updateView()
    }
}
