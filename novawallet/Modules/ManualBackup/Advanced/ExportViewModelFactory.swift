import Foundation

final class ExportViewModelFactory {
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(networkViewModelFactory: NetworkViewModelFactoryProtocol) {
        self.networkViewModelFactory = networkViewModelFactory
    }

    func createViewModel(
        for exportData: ExportData,
        chain: ChainModel?,
        selectedLocale: Locale,
        onTapSubstrateSecret: @escaping () -> Void,
        onTapEthereumSecret: @escaping () -> Void,
        onTapExportJSON: @escaping () -> Void
    ) -> ExportViewLayout.Model {
        var sections: [ExportViewLayout.Section] = []

        if let chain {
            sections.append(
                .networkView(
                    networkViewModelFactory.createViewModel(from: chain)
                )
            )

            sections.append(
                .headerTitle(
                    text: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.manualBackupCustomKey()
                )
            )
        }

        sections.append(
            .headerMessage(
                text: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.advancedExportHeaderMessage()
            )
        )

        exportData.chains.forEach { chain in
            switch chain {
            case let .substrate(model):
                sections.append(
                    .network(model: createViewModelForNetwork(
                        with: model,
                        selectedLocale: selectedLocale,
                        showSecret: model.availableOptions.contains(where: { $0 == .seed }),
                        secretType: .seed,
                        showJSONExport: model.availableOptions.contains(where: { $0 == .keystore }),
                        onTapSecret: onTapSubstrateSecret,
                        onTapExportJSON: onTapExportJSON
                    ))
                )
            case let .ethereum(model):
                let showSecret = model.availableOptions.contains(where: { $0 == .keystore })

                guard showSecret else { return }

                sections.append(
                    .network(model: createViewModelForNetwork(
                        with: model,
                        selectedLocale: selectedLocale,
                        showSecret: showSecret,
                        secretType: .keystore,
                        showJSONExport: false,
                        onTapSecret: onTapEthereumSecret,
                        onTapExportJSON: onTapExportJSON
                    ))
                )
            }
        }

        return .init(
            sections: sections
        )
    }

    // swiftlint:disable function_body_length
    func createViewModelForNetwork(
        with model: ExportChainData,
        selectedLocale: Locale,
        showSecret: Bool,
        secretType: SecretSource,
        showJSONExport: Bool,
        onTapSecret: @escaping () -> Void,
        onTapExportJSON: @escaping () -> Void
    ) -> ExportViewLayout.NetworkModel {
        var blocks: [ExportViewLayout.NetworkModel.Block] = []

        let secretTitle = secretType == .seed
            ? R.string(preferredLanguages: selectedLocale.rLanguages).localizable.secretTypeSeedTitle()
            : R.string(preferredLanguages: selectedLocale.rLanguages).localizable.secretTypePrivateKeyTitle()

        if showSecret {
            blocks.append(
                .secret(model: .init(
                    blockLeftTitle: secretTitle,
                    blockRightTitle: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.accountImportSubstrateSeedPlaceholder_v2_2_0(),
                    hidden: true,
                    coverText: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.mnemonicCardCoverMessageTitle(),
                    onCoverTap: onTapSecret,
                    secret: nil,
                    chainName: model.name
                ))
            )
        }

        if showJSONExport {
            blocks.append(
                .jsonExport(model: .init(
                    blockLeftTitle: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.importRecoveryJson(),
                    buttonTitle: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.advancedExportJsonButtonTitle(),
                    action: onTapExportJSON
                ))
            )
        }

        blocks.append(
            .cryptoType(model: .init(
                blockLeftTitle: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonCryptoType(),
                contentMainText: model.cryptoType.titleForLocale(selectedLocale),
                contentSecondaryText: model.cryptoType.subtitleForLocale(selectedLocale)
            ))
        )

        if let derivationPath = model.derivationPath {
            blocks.append(
                .derivationPath(model: .init(
                    blockLeftTitle: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.commonSecretDerivationPath(),
                    content: derivationPath
                ))
            )
        }

        return .init(
            name: model.name,
            blocks: blocks
        )
    }
}
