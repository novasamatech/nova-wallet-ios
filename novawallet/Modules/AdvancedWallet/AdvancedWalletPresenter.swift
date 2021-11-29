import Foundation
import SoraFoundation

final class AdvancedWalletPresenter {
    weak var view: AdvancedWalletViewProtocol?
    let wireframe: AdvancedWalletWireframeProtocol

    let secretSource: SecretSource
    let settings: AdvancedWalletSettings

    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    init(
        wireframe: AdvancedWalletWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings
    ) {
        self.wireframe = wireframe
        self.secretSource = secretSource
        self.settings = settings
        self.localizationManager = localizationManager
    }

    private func applyAdvanced() {
        applyCryptoTypeViewModel()
        applyDerivationPathViewModel()
    }

    private func applyCryptoTypeViewModel() {
        switch settings {
        case let .substrate(settings):
            applySubstrateCryptoType(for: settings.selectedCryptoType, availableCryptoTypes: settings.availableCryptoTypes)
        case .ethereum:
            applyEthereumCryptoType()
        case let .combined(substrateSettings, _):
            applySubstrateCryptoType(
                for: substrateSettings.selectedCryptoType,
                availableCryptoTypes: substrateSettings.availableCryptoTypes
            )

            applyEthereumCryptoType()
        }
    }

    private func applyDerivationPathViewModel() {
        switch settings {
        case let .substrate(settings):
            let path = substrateDerivationPathViewModel?.inputHandler.value ?? settings.derivationPath
            applySubstrateDerivationPathViewModel(for: path, cryptoType: settings.selectedCryptoType)
            applyDisabledEthereumDerivationPath()
        case let .ethereum(derivationPath):
            applyDisabledSubstrateDerivationPath()

            let path = ethereumDerivationPathViewModel?.inputHandler.value ?? derivationPath
            applyEthereumDerivationPathViewModel(path: path)
        case let .combined(substrateSettings, ethereumDerivationPath):
            let substratePath = substrateDerivationPathViewModel?.inputHandler.value ?? substrateSettings.derivationPath
            let ethereumPath = substrateDerivationPathViewModel?.inputHandler.value ?? ethereumDerivationPath

            applySubstrateDerivationPathViewModel(for: substratePath, cryptoType: substrateSettings.selectedCryptoType)
            applyEthereumDerivationPathViewModel(path: ethereumPath)
        }
    }

    private func applySubstrateCryptoType(
        for selectedCryptoType: MultiassetCryptoType,
        availableCryptoTypes: [MultiassetCryptoType]
    ) {
        let substrateViewModel = TitleWithSubtitleViewModel(
            title: selectedCryptoType.titleForLocale(selectedLocale),
            subtitle: selectedCryptoType.subtitleForLocale(selectedLocale)
        )

        let selectable = availableCryptoTypes.count > 1

        view?.setSubstrateCrypto(viewModel: SelectableViewModel(
            underlyingViewModel: substrateViewModel,
            selectable: selectable
        ))
    }

    private func applyDisabledSubstrateCryptoType() {
        view?.setSubstrateCrypto(viewModel: nil)
    }

    private func applyEthereumCryptoType() {
        let ethereumViewModel = TitleWithSubtitleViewModel(
            title: MultiassetCryptoType.ethereumEcdsa.titleForLocale(selectedLocale),
            subtitle: MultiassetCryptoType.ethereumEcdsa.subtitleForLocale(selectedLocale)
        )

        view?.setEthreumCrypto(viewModel: SelectableViewModel(
            underlyingViewModel: ethereumViewModel,
            selectable: false
        ))
    }

    private func applyDisabledEthereumCryptoType() {
        view?.setEthreumCrypto(viewModel: nil)
    }

    private func applySubstrateDerivationPathViewModel(for _: String?, cryptoType: MultiassetCryptoType) {
        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            if secretSource == .mnemonic {
                predicate = NSPredicate.deriviationPathHardSoftPassword
                placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
            } else {
                predicate = NSPredicate.deriviationPathHardSoft
                placeholder = DerivationPathConstants.hardSoftPlaceholder
            }
        } else {
            if secretSource == .mnemonic {
                predicate = NSPredicate.deriviationPathHardPassword
                placeholder = DerivationPathConstants.hardPasswordPlaceholder
            } else {
                predicate = NSPredicate.deriviationPathHard
                placeholder = DerivationPathConstants.hardPlaceholder
            }
        }

        let inputHandling = InputHandler(required: false, predicate: predicate)

        let viewModel = InputViewModel(
            inputHandler: inputHandling,
            placeholder: placeholder
        )

        substrateDerivationPathViewModel = viewModel

        view?.setSubstrateDerivationPath(viewModel: viewModel)
    }

    private func applyDisabledSubstrateDerivationPath() {
        substrateDerivationPathViewModel = nil
        view?.setSubstrateDerivationPath(viewModel: nil)
    }

    private func applyEthereumDerivationPathViewModel(path: String?) {
        let predicate = NSPredicate.deriviationPathHardSoftNumericPassword
        let placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder

        let inputHandling = InputHandler(value: path ?? "", required: false, predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: placeholder)

        ethereumDerivationPathViewModel = viewModel

        view?.setEthereumDerivationPath(viewModel: viewModel)
    }

    private func applyDisabledEthereumDerivationPath() {
        ethereumDerivationPathViewModel = nil
        view?.setEthereumDerivationPath(viewModel: nil)
    }
}

extension AdvancedWalletPresenter: AdvancedWalletPresenterProtocol {
    func setup() {
        applyAdvanced()
    }

    func selectSubstrateCryptoType() {}

    func selectEthereumCryptoType() {}

    func apply() {}
}

extension AdvancedWalletPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyAdvanced()
        }
    }
}
