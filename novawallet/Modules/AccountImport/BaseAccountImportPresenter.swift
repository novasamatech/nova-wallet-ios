import Foundation
import SoraFoundation

enum AccountImportContext: String {
    case sourceType
    case cryptoType
}

class BaseAccountImportPresenter {
    static let maxMnemonicLength: Int = 250
    static let maxMnemonicSize: Int = 24
    static let maxSubstrateRawSeedLength: Int = 66
    static let maxEthereumRawSeedLength: Int = 130
    static let maxKeystoreLength: Int = 4000

    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!

    private(set) var selectedSourceType: SecretSource

    private(set) var metadata: MetaAccountImportMetadata?

    private(set) var selectedCryptoType: MultiassetCryptoType?

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var substrateDerivationPath: String?
    private(set) var ethereumDerivationPath: String? = DerivationPathConstants.defaultEthereum

    init(secretSource: SecretSource) {
        selectedSourceType = secretSource
    }

    private func applySourceType(
        _ value: String = "",
        preferredInfo: MetaAccountImportPreferredInfo? = nil
    ) {
        if let preferredInfo = preferredInfo {
            selectedCryptoType = preferredInfo.cryptoType
        } else {
            selectedCryptoType = selectedCryptoType ?? metadata?.defaultCryptoType
        }

        view?.setSource(type: selectedSourceType)

        applySourceTextViewModel(value)

        let username = preferredInfo?.username ?? ""
        applyUsernameViewModel(username)
        applyPasswordViewModel()

        if let preferredInfo = preferredInfo {
            showUploadWarningIfNeeded(preferredInfo)
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            view?.setShouldShowAdvancedSettings(true)
        case .keystore:
            let shouldShowReadonlySettings = preferredInfo != nil
            view?.setShouldShowAdvancedSettings(shouldShowReadonlySettings)
        }
    }

    private func applySourceTextViewModel(_ value: String = "") {
        let viewModel: InputViewModelProtocol

        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch selectedSourceType {
        case .mnemonic:
            let placeholder = R.string.localizable
                .importMnemonic(preferredLanguages: locale.rLanguages)
            let normalizer = MnemonicTextNormalizer()
            let inputHandler = InputHandler(
                value: value,
                maxLength: AccountImportPresenter.maxMnemonicLength,
                validCharacterSet: CharacterSet.englishMnemonic,
                predicate: NSPredicate.notEmpty,
                normalizer: normalizer
            )
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)

        case .seed:
            let inputHandler: InputHandler
            let placeholder: String

            if shouldUseEthereumSeed() {
                inputHandler = InputHandler(
                    value: value,
                    maxLength: Self.maxEthereumRawSeedLength,
                    predicate: NSPredicate.ethereumSeed
                )

                placeholder = R.string.localizable
                    .accountImportEthereumSeedPlaceholder_v2_2_0(preferredLanguages: locale.rLanguages)
            } else {
                inputHandler = InputHandler(
                    value: value,
                    maxLength: Self.maxSubstrateRawSeedLength,
                    predicate: NSPredicate.substrateSeed
                )
                placeholder = R.string.localizable
                    .accountImportSubstrateSeedPlaceholder_v2_2_0(preferredLanguages: locale.rLanguages)
            }

            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)

        case .keystore:
            let placeholder = R.string.localizable
                .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(
                value: value,
                maxLength: Self.maxKeystoreLength,
                predicate: NSPredicate.notEmpty
            )
            viewModel = InputViewModel(
                inputHandler: inputHandler,
                placeholder: placeholder
            )
        }

        sourceViewModel = viewModel

        view?.setSource(viewModel: viewModel)
    }

    internal func applyUsernameViewModel(_ username: String = "") {
        let processor = ByteLengthProcessor.username
        let processedUsername = processor.process(text: username)

        let inputHandler = InputHandler(
            value: processedUsername,
            predicate: NSPredicate.notEmpty,
            processor: processor
        )

        let viewModel = InputViewModel(inputHandler: inputHandler)
        usernameViewModel = viewModel

        view?.setName(viewModel: viewModel)
    }

    private func applyPasswordViewModel() {
        switch selectedSourceType {
        case .mnemonic, .seed:
            passwordViewModel = nil
        case .keystore:
            let viewModel = InputViewModel(inputHandler: InputHandler(required: false))
            passwordViewModel = viewModel

            view?.setPassword(viewModel: viewModel)
        }
    }

    internal func validateSourceViewModel() -> Error? {
        guard let viewModel = sourceViewModel else {
            return nil
        }

        switch selectedSourceType {
        case .mnemonic:
            return validateMnemonic(value: viewModel.inputHandler.normalizedValue)
        case .seed:
            return viewModel.inputHandler.completed ? nil : AccountCreateError.invalidSeed
        case .keystore:
            return validateKeystore(value: viewModel.inputHandler.value)
        }
    }

    private func validateMnemonic(value: String) -> Error? {
        let mnemonicSize = value.components(separatedBy: CharacterSet.whitespaces).count
        return mnemonicSize > AccountImportPresenter.maxMnemonicSize ?
            AccountCreateError.invalidMnemonicSize : nil
    }

    private func validateKeystore(value: String) -> Error? {
        guard let data = value.data(using: .utf8) else {
            return AccountCreateError.invalidKeystore
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return nil
        } catch {
            return AccountCreateError.invalidKeystore
        }
    }

    internal func processProceed() {
        fatalError("This function should be overriden")
    }

    internal func showUploadWarningIfNeeded(_: MetaAccountImportPreferredInfo) {
        fatalError("This function should be overriden")
    }

    internal func shouldUseEthereumSeed() -> Bool {
        fatalError("This function should be overriden")
    }

    internal func getAdvancedSettings() -> AdvancedWalletSettings? {
        fatalError("This function should be overriden")
    }
}

extension BaseAccountImportPresenter: AccountImportPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateUpload() {
        let locale = localizationManager?.selectedLocale

        let pasteTitle = R.string.localizable
            .accountImportRecoveryJsonPlaceholder(preferredLanguages: locale?.rLanguages)
        let pasteAction = AlertPresentableAction(title: pasteTitle) { [weak self] in
            if let json = UIPasteboard.general.string {
                self?.interactor.deriveMetadataFromKeystore(json)
            }
        }

        let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [pasteAction],
            closeAction: closeTitle
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }

    func activateAdvancedSettings() {
        guard let settings = getAdvancedSettings() else {
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            wireframe.showModifiableAdvancedSettings(
                from: view,
                secretSource: selectedSourceType,
                settings: settings,
                delegate: self
            )
        case .keystore:
            wireframe.showReadonlyAdvancedSettings(
                from: view,
                secretSource: selectedSourceType,
                settings: settings
            )
        }
    }

    func proceed() {
        processProceed()
    }
}

extension BaseAccountImportPresenter: AccountImportInteractorOutputProtocol {
    func didReceiveAccountImport(metadata: MetaAccountImportMetadata) {
        self.metadata = metadata

        applySourceType()
    }

    func didCompleteAccountImport() {
        wireframe.proceed(from: view)
    }

    func didReceiveAccountImport(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(
            error: CommonError.undefined,
            from: view,
            locale: locale
        )
    }

    func didSuggestKeystore(text: String, preferredInfo: MetaAccountImportPreferredInfo?) {
        selectedSourceType = .keystore

        applySourceType(text, preferredInfo: preferredInfo)
    }
}

extension BaseAccountImportPresenter: AdvancedWalletSettingsDelegate {
    func didReceiveNewAdvanced(walletSettings: AdvancedWalletSettings) {
        switch walletSettings {
        case let .substrate(settings):
            selectedCryptoType = settings.selectedCryptoType
            substrateDerivationPath = settings.derivationPath
        case let .ethereum(derivationPath):
            ethereumDerivationPath = derivationPath
        case let .combined(substrateSettings, ethereumDerivationPath):
            selectedCryptoType = substrateSettings.selectedCryptoType
            substrateDerivationPath = substrateSettings.derivationPath
            self.ethereumDerivationPath = ethereumDerivationPath
        }
    }
}

extension BaseAccountImportPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applySourceType()
        }
    }
}
