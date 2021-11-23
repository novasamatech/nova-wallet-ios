import Foundation
import SoraFoundation

final class ExportMnemonicPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportMnemonicWireframeProtocol!
    var interactor: ExportMnemonicInteractorInputProtocol!

    let localizationManager: LocalizationManager

    private(set) var exportData: ExportMnemonicData?

    init(localizationManager: LocalizationManager) {
        self.localizationManager = localizationManager
    }

    private func share() {
        guard let data = exportData else {
            return
        }

        let text: String

        let locale = localizationManager.selectedLocale

        if let derivationPath = exportData?.derivationPath {
            text = R.string.localizable
                .exportMnemonicWithDpTemplate(
                    data.chain.name,
                    data.mnemonic.toString(),
                    derivationPath,
                    preferredLanguages: locale.rLanguages
                )
        } else {
            text = R.string.localizable
                .exportMnemonicWithoutDpTemplate(
                    data.chain.name,
                    data.mnemonic.toString(),
                    preferredLanguages: locale.rLanguages
                )
        }

        wireframe.share(source: TextSharingSource(message: text), from: view) { [weak self] completed in
            if completed {
                self?.wireframe.close(view: self?.view)
            }
        }
    }
}

extension ExportMnemonicPresenter: ExportGenericPresenterProtocol {
    func setup() {
        interactor.fetchExportData()
    }

    func activateExport() {
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let exportTitle = R.string.localizable.accountExportAction(preferredLanguages: locale.rLanguages)
        let exportAction = AlertPresentableAction(title: exportTitle) { [weak self] in
            self?.share()
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction],
            closeAction: cancelTitle
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    func activateAccessoryOption() {
        guard let exportData = exportData else {
            return
        }

        wireframe.openConfirmationForMnemonic(exportData.mnemonic, from: view)
    }
}

extension ExportMnemonicPresenter: ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportData: ExportMnemonicData) {
        self.exportData = exportData

        guard let cryptoType = exportData.metaAccount.fetch(
            for: exportData.chain.accountRequest()
        )?.cryptoType else {
            didReceive(error: ChainAccountFetchingError.accountNotExists)
            return
        }

        let viewModel = ExportMnemonicViewModel(
            option: .mnemonic,
            chain: exportData.chain,
            derivationPath: exportData.derivationPath,
            cryptoType: cryptoType,
            mnemonic: exportData.mnemonic.allWords()
        )
        view?.set(viewModel: viewModel)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
