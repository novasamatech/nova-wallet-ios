import Foundation
import SoraFoundation

final class AdvancedExportPresenter {
    weak var view: AdvancedExportViewProtocol?
    let wireframe: AdvancedExportWireframeProtocol
    let interactor: AdvancedExportInteractorInputProtocol

    private let logger: LoggerProtocol
    private let localizationManager: LocalizationManagerProtocol

    private let metaAccount: MetaAccountModel
    private var chain: ChainModel?

    init(
        interactor: AdvancedExportInteractorInputProtocol,
        wireframe: AdvancedExportWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol,
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.metaAccount = metaAccount
        self.chain = chain
        self.localizationManager = localizationManager
    }
}

extension AdvancedExportPresenter: AdvancedExportPresenterProtocol {
    func setup() {
        interactor.requestExportOptions(
            metaAccount: metaAccount,
            chain: chain
        )
    }
}

extension AdvancedExportPresenter: AdvancedExportInteractorOutputProtocol {
    func didReceive(exportData: AdvancedExportData) {
        let viewModel = createViewModel(for: exportData)

        view?.update(with: viewModel)
    }

    func didReceive(
        seed: Data,
        for chainName: String
    ) {
        view?.showSecret(
            seed.toHexWithPrefix(),
            for: chainName
        )
    }

    func didReceive(_ error: Error) {
        logger.error("Did receive error: \(error)")

        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.dataCorruption,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}

// MARK: Private

private extension AdvancedExportPresenter {
    func createViewModel(for exportData: AdvancedExportData) -> AdvancedExportViewLayout.Model {
        var sections: [AdvancedExportViewLayout.Section] = []

        sections.append(
            .headerMessage(
                text: R.string.localizable.advancedExportHeaderMessage(
                    preferredLanguages: selectedLocale.rLanguages
                )
            )
        )

        exportData.chains.forEach { chain in
            switch chain {
            case let .substrate(model):
                sections.append(
                    .network(model: createViewModelForSubstrate(with: model))
                )
            case let .ethereum(model):
                guard model.availableOptions.contains(where: { $0 == .keystore }) else { return }

                sections.append(
                    .network(model: createViewModelForEthereum(with: model))
                )
            }
        }

        return .init(
            sections: sections
        )
    }

    func createViewModelForSubstrate(with model: AdvancedExportChainData) -> AdvancedExportViewLayout.NetworkModel {
        var blocks: [AdvancedExportViewLayout.NetworkModel.Block] = []

        let showSeed = model.availableOptions.contains(where: { $0 == .seed })
        let showJSONExport = model.availableOptions.contains(where: { $0 == .keystore })

        if showSeed {
            blocks.append(
                .secret(model: .init(
                    blockLeftTitle: R.string.localizable.secretTypeSeedTitle(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    blockRightTitle: R.string.localizable.accountImportSubstrateSeedPlaceholder_v2_2_0(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    hidden: true,
                    coverText: R.string.localizable.mnemonicCardCoverMessageTitle(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    onCoverTap: { [weak self] in self?.didTapSubstrateSecretCover() },
                    secret: nil,
                    chainName: model.name
                ))
            )
        }

        if showJSONExport {
            blocks.append(
                .jsonExport(model: .init(
                    blockLeftTitle: R.string.localizable.importRecoveryJson(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    buttonTitle: R.string.localizable.advancedExportJsonButtonTitle(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    action: { [weak self] in
                        self?.wireframe.showExportRestoreJSON(from: view)
                    }
                ))
            )
        }

        blocks.append(
            .cryptoType(model: .init(
                blockLeftTitle: R.string.localizable.commonCryptoType(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                contentMainText: model.cryptoType.titleForLocale(selectedLocale),
                contentSecondaryText: model.cryptoType.subtitleForLocale(selectedLocale)
            ))
        )

        if let derivationPath = model.derivationPath {
            blocks.append(
                .derivationPath(model: .init(
                    blockLeftTitle: R.string.localizable.commonSecretDerivationPath(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    content: model.derivationPath
                ))
            )
        }

        return .init(
            name: model.name,
            blocks: blocks
        )
    }

    func createViewModelForEthereum(with model: AdvancedExportChainData) -> AdvancedExportViewLayout.NetworkModel {
        var blocks: [AdvancedExportViewLayout.NetworkModel.Block] = [
            .secret(model: .init(
                blockLeftTitle: R.string.localizable.secretTypePrivateKeyTitle(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                blockRightTitle: R.string.localizable.accountImportSubstrateSeedPlaceholder_v2_2_0(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                hidden: true,
                coverText: R.string.localizable.mnemonicCardCoverMessageTitle(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                onCoverTap: { [weak self] in self?.didTapEthereumSecretCover() },
                secret: nil,
                chainName: model.name
            )),

            .cryptoType(model: .init(
                blockLeftTitle: R.string.localizable.commonCryptoType(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                contentMainText: R.string.localizable.ecdsaSelectionTitle(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                contentSecondaryText: R.string.localizable.ecdsaSelectionSubtitle(
                    preferredLanguages: selectedLocale.rLanguages
                )
            ))
        ]

        if let derivationPath = model.derivationPath {
            blocks.append(
                .derivationPath(model: .init(
                    blockLeftTitle: R.string.localizable.commonSecretDerivationPath(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    content: model.derivationPath
                ))
            )
        }

        return .init(
            name: model.name,
            blocks: blocks
        )
    }

    func didTapSubstrateSecretCover() {
        interactor.requestSeedForSubstrate(
            metaAccount: metaAccount,
            chain: chain
        )
    }

    func didTapEthereumSecretCover() {
        interactor.requestKeyForEthereum(
            metaAccount: metaAccount,
            chain: chain
        )
    }
}

// MARK: Localizable

extension AdvancedExportPresenter: Localizable {
    func applyLocalization() {}
}
