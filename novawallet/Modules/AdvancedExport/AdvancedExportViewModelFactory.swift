import Foundation

final class AdvancedExportViewModelFactory {
    func createViewModel(
        for exportData: AdvancedExportData,
        selectedLocale: Locale,
        onTapSubstrateSecret: @escaping () -> Void,
        onTapEthereumSecret: @escaping () -> Void,
        onTapExportJSON: @escaping () -> Void
    ) -> AdvancedExportViewLayout.Model {
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
                    .network(model: createViewModelForSubstrate(
                        with: model,
                        selectedLocale: selectedLocale,
                        onTapSecret: onTapSubstrateSecret,
                        onTapExportJSON: onTapExportJSON
                    ))
                )
            case let .ethereum(model):
                guard model.availableOptions.contains(where: { $0 == .keystore }) else { return }

                sections.append(
                    .network(model: createViewModelForEthereum(
                        with: model,
                        selectedLocale: selectedLocale,
                        onTapSecret: onTapEthereumSecret
                    ))
                )
            }
        }

        return .init(
            sections: sections
        )
    }

    // swiftlint:disable function_body_length
    func createViewModelForSubstrate(
        with model: AdvancedExportChainData,
        selectedLocale: Locale,
        onTapSecret: @escaping () -> Void,
        onTapExportJSON: @escaping () -> Void
    ) -> AdvancedExportViewLayout.NetworkModel {
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
                    content: model.derivationPath
                ))
            )
        }

        return .init(
            name: model.name,
            blocks: blocks
        )
    }

    func createViewModelForEthereum(
        with model: AdvancedExportChainData,
        selectedLocale: Locale,
        onTapSecret: @escaping () -> Void
    ) -> AdvancedExportViewLayout.NetworkModel {
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
                onCoverTap: onTapSecret,
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
}
