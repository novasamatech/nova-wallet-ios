import Foundation
import SoraFoundation

final class AdvancedWalletPresenter {
    weak var view: AdvancedWalletViewProtocol?
    let wireframe: AdvancedWalletWireframeProtocol

    let secretSource: SecretSource
    private(set) var settings: AdvancedWalletSettings

    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    weak var delegate: AdvancedWalletSettingsDelegate?

    private var substrateCryptoType: MultiassetCryptoType? {
        switch settings {
        case let .substrate(settings):
            return settings.selectedCryptoType
        case .ethereum:
            return nil
        case let .combined(substrateSettings, _):
            return substrateSettings.selectedCryptoType
        }
    }

    init(
        wireframe: AdvancedWalletWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings,
        delegate: AdvancedWalletSettingsDelegate?
    ) {
        self.wireframe = wireframe
        self.secretSource = secretSource
        self.settings = settings
        self.delegate = delegate
        self.localizationManager = localizationManager
    }

    private func applyAdvanced() {
        applyCryptoTypeViewModel()
        applyDerivationPathViewModel()
    }

    private func applyCryptoTypeViewModel() {
        switch settings {
        case let .substrate(settings):
            applySubstrateCryptoType(
                for: settings.selectedCryptoType,
                availableCryptoTypes: settings.availableCryptoTypes
            )
            applyDisabledEthereumCryptoType()
        case .ethereum:
            applyDisabledSubstrateCryptoType()
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
            let ethereumPath = ethereumDerivationPathViewModel?.inputHandler.value ?? ethereumDerivationPath

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

    private func applySubstrateDerivationPathViewModel(for path: String?, cryptoType: MultiassetCryptoType) {
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

        let inputHandling = InputHandler(value: path ?? "", required: false, predicate: predicate)

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

    private func validate() -> Bool {
        if !validateSubstrate() {
            return false
        }

        return validateEthereum()
    }

    private func validateSubstrate() -> Bool {
        guard let viewModel = substrateDerivationPathViewModel, let cryptoType = substrateCryptoType else {
            return true
        }

        if !viewModel.inputHandler.completed {
            presentDerivationPathError(cryptoType)
            return false
        } else {
            return true
        }
    }

    private func validateEthereum() -> Bool {
        guard let viewModel = ethereumDerivationPathViewModel else { return true }

        if !viewModel.inputHandler.completed {
            presentDerivationPathError(.ethereumEcdsa)
            return false
        } else {
            return true
        }
    }

    internal func presentDerivationPathError(_ cryptoType: MultiassetCryptoType) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let error: AccountCreationError

        switch cryptoType {
        case .sr25519:
            error = .invalidDerivationHardSoftPassword
        case .ed25519, .substrateEcdsa:
            error = .invalidDerivationHardPassword
        case .ethereumEcdsa:
            error = .invalidDerivationHardSoftNumericPassword
        }

        _ = wireframe.present(error: error, from: view, locale: locale)
    }
}

extension AdvancedWalletPresenter: AdvancedWalletPresenterProtocol {
    func setup() {
        applyAdvanced()
    }

    func selectSubstrateCryptoType() {
        switch settings {
        case let .substrate(settings):
            wireframe.presentCryptoTypeSelection(
                from: view,
                availableTypes: settings.availableCryptoTypes,
                selectedType: settings.selectedCryptoType,
                delegate: self
            )
        case .ethereum:
            break
        case let .combined(substrateSettings, _):
            wireframe.presentCryptoTypeSelection(
                from: view,
                availableTypes: substrateSettings.availableCryptoTypes,
                selectedType: substrateSettings.selectedCryptoType,
                delegate: self
            )
        }
    }

    func selectEthereumCryptoType() {
        // the current model supports only single crypto type for eth but view already supports selected
    }

    func apply() {
        if validate() {
            let newSettings: AdvancedWalletSettings

            switch settings {
            case let .substrate(settings):
                let newNetworkSettings = AdvancedNetworkTypeSettings(
                    availableCryptoTypes: settings.availableCryptoTypes,
                    selectedCryptoType: settings.selectedCryptoType,
                    derivationPath: substrateDerivationPathViewModel?.inputHandler.value
                )

                newSettings = .substrate(settings: newNetworkSettings)

            case let .ethereum(ethereumDerivationPath):
                let derivationPath = ethereumDerivationPathViewModel?.inputHandler.value ??
                    ethereumDerivationPath
                newSettings = .ethereum(derivationPath: derivationPath)

            case let .combined(substrateSettings, ethereumDerivationPath):
                let newSubstrateSettings = AdvancedNetworkTypeSettings(
                    availableCryptoTypes: substrateSettings.availableCryptoTypes,
                    selectedCryptoType: substrateSettings.selectedCryptoType,
                    derivationPath: substrateDerivationPathViewModel?.inputHandler.value
                )

                newSettings = .combined(
                    substrateSettings: newSubstrateSettings,
                    ethereumDerivationPath: ethereumDerivationPathViewModel?.inputHandler.value ??
                        ethereumDerivationPath
                )
            }

            delegate?.didReceiveNewAdvanced(walletSettings: newSettings)

            wireframe.complete(from: view)
        }
    }
}

extension AdvancedWalletPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyAdvanced()
        }
    }
}

extension AdvancedWalletPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        let maybeNewSettings: AdvancedWalletSettings?

        switch settings {
        case let .substrate(settings):
            let newNetworkSettings = AdvancedNetworkTypeSettings(
                availableCryptoTypes: settings.availableCryptoTypes,
                selectedCryptoType: settings.availableCryptoTypes[index],
                derivationPath: substrateDerivationPathViewModel?.inputHandler.value
            )

            maybeNewSettings = .substrate(settings: newNetworkSettings)
        case .ethereum:
            maybeNewSettings = nil
        case let .combined(substrateSettings, ethereumDerivationPath):
            let newSubstrateSettings = AdvancedNetworkTypeSettings(
                availableCryptoTypes: substrateSettings.availableCryptoTypes,
                selectedCryptoType: substrateSettings.availableCryptoTypes[index],
                derivationPath: substrateDerivationPathViewModel?.inputHandler.value
            )

            maybeNewSettings = .combined(
                substrateSettings: newSubstrateSettings,
                ethereumDerivationPath: ethereumDerivationPathViewModel?.inputHandler.value ??
                    ethereumDerivationPath
            )
        }

        guard let newSettings = maybeNewSettings else {
            return
        }

        settings = newSettings

        applyAdvanced()

        view?.didCompleteCryptoTypeSelection()
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        view?.didCompleteCryptoTypeSelection()
    }
}
