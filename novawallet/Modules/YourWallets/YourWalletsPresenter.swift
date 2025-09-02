import Foundation
import SubstrateSdk
import Foundation_iOS

final class YourWalletsPresenter {
    weak var view: YourWalletsViewProtocol?
    weak var delegate: YourWalletsDelegate?

    let metaAccounts: [MetaAccountChainResponse]
    let accountIconGenerator: IconGenerating
    let chainIconGenerator: IconGenerating
    let sectionTypes: [MetaAccountModelType] = [
        .secrets,
        .polkadotVault,
        .paritySigner,
        .genericLedger,
        .ledger,
        .proxied,
        .multisig,
        .watchOnly
    ]

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
        let metaAccountsGroups = Dictionary(grouping: metaAccounts) {
            $0.metaAccount.type
        }

        sections = sectionTypes.compactMap {
            guard let accounts = metaAccountsGroups[$0] else {
                return nil
            }
            return .init(
                header: header(metaAccountType: $0),
                cells: accounts.map(cell)
            )
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

    private func header(metaAccountType: MetaAccountModelType) -> YourWalletsViewSectionModel.HeaderViewModel? {
        switch metaAccountType {
        case .watchOnly, .secrets:
            return nil
        case .paritySigner:
            let type = ParitySignerType.legacy
            return .init(title: type.getName(for: selectedLocale).uppercased(), icon: type.icon)
        case .polkadotVault:
            let type = ParitySignerType.vault
            return .init(title: type.getName(for: selectedLocale).uppercased(), icon: type.icon)
        case .ledger:
            return .init(
                title: R.string.localizable.commonLedgerLegacy(
                    preferredLanguages: selectedLocale.rLanguages
                ).uppercased(),
                icon: R.image.iconLedgerWarning()
            )
        case .proxied:
            return .init(
                title: R.string.localizable.commonProxieds(
                    preferredLanguages: selectedLocale.rLanguages
                ).uppercased(),
                icon: R.image.iconProxy()
            )
        case .multisig:
            return .init(
                title: R.string.localizable.commonMultisig(
                    preferredLanguages: selectedLocale.rLanguages
                ).uppercased(),
                icon: R.image.iconMultisig()
            )
        case .genericLedger:
            return .init(
                title: R.string.localizable.commonLedger(
                    preferredLanguages: selectedLocale.rLanguages
                ).uppercased(),
                icon: R.image.iconLedger()
            )
        }
    }

    private func cell(response: MetaAccountChainResponse) -> YourWalletsCellViewModel {
        let name = response.metaAccount.name
        let imageViewModel = icon(
            generator: accountIconGenerator,
            from: response.metaAccount.walletIdenticonData()
        )
        let metaId = response.metaAccount.metaId
        guard let chainAccountResponse = response.chainAccountResponse,
              let displayAddress = try? chainAccountResponse.chainAccount.toDisplayAddress() else {
            let message = R.string.localizable.accountNotFoundCaption(preferredLanguages: selectedLocale.rLanguages)
            return .warning(.init(metaId: metaId, accountName: name, warning: message, imageViewModel: imageViewModel))
        }

        let chainAccountIcon = icon(
            generator: chainIconGenerator,
            from: chainAccountResponse.chainAccount.accountId
        )
        return .common(.init(
            metaId: metaId,
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
        let sections = Dictionary(grouping: metaAccounts) { $0.metaAccount.type }
            .keys
            .compactMap(header)
            .count
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

        if let view {
            delegate?.yourWallets(
                selectionView: view,
                didSelect: viewModel.displayAddress.address
            )
        }
    }

    func viewWillDisappear() {
        if let view {
            delegate?.yourWalletsDidClose(selectionView: view)
        }
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
