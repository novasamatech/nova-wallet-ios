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
                    text: R.string.localizable.advancedExportCustomKeyHeaderTitle(
                        preferredLanguages: selectedLocale.rLanguages
                    )
                )
            )
        }

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
            ? R.string.localizable.secretTypeSeedTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            : R.string.localizable.secretTypePrivateKeyTitle(
                preferredLanguages: selectedLocale.rLanguages
            )

        if showSecret {
            blocks.append(
                .secret(model: .init(
                    blockLeftTitle: secretTitle,
                    blockRightTitle: R.string.localizable.accountImportSubstrateSeedPlaceholder_v2_2_0(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    hidden: true,
                    coverText: R.string.localizable.mnemonicCardCoverMessageTitle(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    onCoverTap: onTapSecret,
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
                    action: onTapExportJSON
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
