import Foundation
import SoraFoundation

enum AccountImportContext: String {
    case sourceType
    case cryptoType
    case addressType
}

class BaseAccountImportPresenter {
    static let maxMnemonicLength: Int = 250
    static let maxMnemonicSize: Int = 24
    static let maxRawSeedLength: Int = 66
    static let maxKeystoreLength: Int = 4000

    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!

    private let selectedEthereumCryptoType: MultiassetCryptoType = .ethereumEcdsa

    private(set) var metadata: MetaAccountImportMetadata?

    private(set) var selectedSourceType: AccountImportSource?
    private(set) var selectedSubstrateCryptoType: MultiassetCryptoType?
    private(set) var selectedNetworkType: Chain?

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    private lazy var jsonDeserializer = JSONSerialization()

    private func applySourceType(_ value: String = "", preferredInfo: MetaAccountImportPreferredInfo? = nil) {
        guard let selectedSourceType = selectedSourceType, let metadata = metadata else {
            return
        }

        if let preferredInfo = preferredInfo {
            selectedSubstrateCryptoType = preferredInfo.cryptoType

            if let preferredNetwork = preferredInfo.networkType,
               metadata.availableNetworks.contains(preferredNetwork) {
                selectedNetworkType = preferredInfo.networkType
            } else {
                selectedNetworkType = metadata.defaultNetwork
            }

        } else {
            selectedSubstrateCryptoType = selectedSubstrateCryptoType ?? metadata.defaultCryptoType
            selectedNetworkType = selectedNetworkType ?? metadata.defaultNetwork
        }

        view?.setSource(type: selectedSourceType)

        applySourceTextViewModel(value)

        let username = preferredInfo?.username ?? ""
        applyUsernameViewModel(username)
        applyPasswordViewModel()
        applyAdvanced(preferredInfo)

        if let preferredInfo = preferredInfo {
            showUploadWarningIfNeeded(preferredInfo)
        }
    }

    private func applySourceTextViewModel(_ value: String = "") {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

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
            let placeholder = R.string.localizable
                .accountImportRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(
                value: value,
                maxLength: Self.maxRawSeedLength,
                predicate: NSPredicate.seed
            )
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
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            passwordViewModel = nil
        case .keystore:
            let viewModel = InputViewModel(inputHandler: InputHandler(required: false))
            passwordViewModel = viewModel

            view?.setPassword(viewModel: viewModel)
        }
    }

    private func showUploadWarningIfNeeded(_ preferredInfo: MetaAccountImportPreferredInfo) {
        guard let metadata = metadata else {
            return
        }

        if preferredInfo.networkType == nil {
            let locale = localizationManager?.selectedLocale
            let message = R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
            view?.setUploadWarning(message: message)
            return
        }

        if let preferredNetwork = preferredInfo.networkType,
           !metadata.availableNetworks.contains(preferredNetwork) {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let message = R.string.localizable
                .accountImportWrongNetwork(
                    preferredNetwork.titleForLocale(locale),
                    metadata.defaultNetwork.titleForLocale(locale)
                )
            view?.setUploadWarning(message: message)
            return
        }
    }

    private func applyAdvanced(_ preferredInfo: MetaAccountImportPreferredInfo?) {
        guard let selectedSourceType = selectedSourceType else {
            let locale = localizationManager?.selectedLocale
            let warning = R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
            view?.setUploadWarning(message: warning)
            return
        }

        switch selectedSourceType {
        case .mnemonic:
            applyCryptoTypeViewModel(preferredInfo)
            applySubstrateDerivationPathViewModel()
            applyEthereumDerivationPathViewModel()
            applyNetworkTypeViewModel(preferredInfo)

        case .seed:
            applyCryptoTypeViewModel(preferredInfo)
            applySubstrateDerivationPathViewModel()
            ethereumDerivationPathViewModel = nil
            applyNetworkTypeViewModel(preferredInfo)

        case .keystore:
            applyCryptoTypeViewModel(preferredInfo)
            substrateDerivationPathViewModel = nil
            ethereumDerivationPathViewModel = nil
            applyNetworkTypeViewModel(preferredInfo)
        }
    }

    private func applyCryptoTypeViewModel(_ preferredInfo: MetaAccountImportPreferredInfo?) {
        guard let cryptoType = selectedSubstrateCryptoType else { return }

        let substrateViewModel = TitleWithSubtitleViewModel(
            title: cryptoType.titleForLocale(selectedLocale),
            subtitle: cryptoType.subtitleForLocale(selectedLocale)
        )

        let ethereumViewModel = TitleWithSubtitleViewModel(
            title: selectedEthereumCryptoType.titleForLocale(selectedLocale),
            subtitle: selectedEthereumCryptoType.subtitleForLocale(selectedLocale)
        )

        let selectable: Bool

        if preferredInfo?.cryptoType != nil {
            selectable = false
        } else {
            selectable = (metadata?.availableCryptoTypes.count ?? 0) > 1
        }

        view?.setSelectedSubstrateCrypto(model: SelectableViewModel(
            underlyingViewModel: substrateViewModel,
            selectable: selectable
        ))

        view?.setSelectedEthereumCrypto(model: SelectableViewModel(
            underlyingViewModel: ethereumViewModel,
            selectable: false
        ))
    }

    private func applyNetworkTypeViewModel(_ preferredInfo: MetaAccountImportPreferredInfo?) {
        guard let networkType = selectedNetworkType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let contentViewModel = IconWithTitleViewModel(
            icon: networkType.icon,
            title: networkType.titleForLocale(locale)
        )

        let selectable: Bool

        if let preferredInfo = preferredInfo, preferredInfo.networkType != nil {
            selectable = !preferredInfo.networkTypeConfirmed
        } else {
            selectable = (metadata?.availableNetworks.count ?? 0) > 1
        }

        let selectedViewModel = SelectableViewModel(
            underlyingViewModel: contentViewModel,
            selectable: selectable
        )
    }

    private func applySubstrateDerivationPathViewModel() {
        guard let cryptoType = selectedSubstrateCryptoType else {
            return
        }

        guard let sourceType = selectedSourceType else {
            return
        }

        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            if sourceType == .mnemonic {
                predicate = NSPredicate.deriviationPathHardSoftPassword
                placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
            } else {
                predicate = NSPredicate.deriviationPathHardSoft
                placeholder = DerivationPathConstants.hardSoftPlaceholder
            }
        } else {
            if sourceType == .mnemonic {
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
        view?.didValidateSubstrateDerivationPath(.none)
    }

    private func applyEthereumDerivationPathViewModel() {
        let predicate = NSPredicate.deriviationPathHardSoftNumericPassword
        let placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder

        let inputHandling = InputHandler(required: false, predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: placeholder)

        ethereumDerivationPathViewModel = viewModel

        view?.setEthereumDerivationPath(viewModel: viewModel)
        view?.didValidateEthereumDerivationPath(.none)
    }

    internal func presentDerivationPathError(
        sourceType: AccountImportSource,
        cryptoType: MultiassetCryptoType
    ) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let error: AccountCreationError

        switch cryptoType {
        case .sr25519:
            error = sourceType == .mnemonic ?
                .invalidDerivationHardSoftPassword : .invalidDerivationHardSoft

        case .ed25519, .substrateEcdsa:
            error = sourceType == .mnemonic ?
                .invalidDerivationHardPassword : .invalidDerivationHard

        case .ethereumEcdsa:
            error = sourceType == .mnemonic ?
                .invalidDerivationHardSoftNumericPassword : .invalidDerivationHardSoftNumeric
        }

        _ = wireframe.present(error: error, from: view, locale: locale)
    }

    internal func validateSourceViewModel() -> Error? {
        guard let viewModel = sourceViewModel, let selectedSourceType = selectedSourceType else {
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

    internal func getVisibilitySettings() -> AccountImportVisibility {
        fatalError("This function should be overriden")
    }

    internal func processProceed() {
        fatalError("This function should be overriden")
    }

    internal func setViewTitle() {
        fatalError("This function should be overriden")
    }
}

extension BaseAccountImportPresenter: AccountImportPresenterProtocol {
    func setup() {
        setViewTitle()
        interactor.setup()
    }

    func updateTitle() {
        setViewTitle()
    }

    func provideVisibilitySettings() -> AccountImportVisibility {
        getVisibilitySettings()
    }

    func selectSourceType() {
        if let metadata = metadata {
            let context = AccountImportContext.sourceType.rawValue as NSString
            let selectedSourceType = self.selectedSourceType ?? metadata.defaultSource

            wireframe.presentSourceTypeSelection(
                from: view,
                availableSources: metadata.availableSources,
                selectedSource: selectedSourceType,
                delegate: self,
                context: context
            )
        }
    }

    func selectCryptoType() {
        if let metadata = metadata {
            let context = AccountImportContext.cryptoType.rawValue as NSString
            let selectedType = selectedSubstrateCryptoType ?? metadata.defaultCryptoType
            wireframe.presentCryptoTypeSelection(
                from: view,
                availableTypes: metadata.availableCryptoTypes,
                selectedType: selectedType,
                delegate: self,
                context: context
            )
        }
    }

    // TODO: Remove
    func selectNetworkType() {
        if let metadata = metadata {
            let context = AccountImportContext.addressType.rawValue as NSString
            let selectedType = selectedNetworkType ?? metadata.defaultNetwork
            wireframe.presentNetworkTypeSelection(
                from: view,
                availableTypes: metadata.availableNetworks,
                selectedType: selectedType,
                delegate: self,
                context: context
            )
        }
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

    private func validateSubstrate() {
        guard let viewModel = substrateDerivationPathViewModel,
              let cryptoType = selectedSubstrateCryptoType,
              let sourceType = selectedSourceType
        else { return }

        if viewModel.inputHandler.completed {
            view?.didValidateSubstrateDerivationPath(.valid)
        } else {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(sourceType: sourceType, cryptoType: cryptoType)
        }
    }

    private func validateEthereum() {
        guard let viewModel = ethereumDerivationPathViewModel,
              let sourceType = selectedSourceType
        else { return }

        if viewModel.inputHandler.completed {
            view?.didValidateEthereumDerivationPath(.valid)
        } else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(sourceType: sourceType, cryptoType: .ethereumEcdsa)
        }
    }

    func validateDerivationPath() {
        validateSubstrate()
        validateEthereum()
    }

    func proceed() {
        processProceed()
    }
}

extension BaseAccountImportPresenter: AccountImportInteractorOutputProtocol {
    func didReceiveAccountImport(metadata: MetaAccountImportMetadata) {
        self.metadata = metadata

        selectedSourceType = metadata.defaultSource
        selectedSubstrateCryptoType = metadata.defaultCryptoType
        selectedNetworkType = metadata.defaultNetwork

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

extension BaseAccountImportPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AccountImportContext(rawValue: context as String) {
            switch selectionContext {
            case .sourceType:
                selectedSourceType = metadata?.availableSources[index]

                selectedNetworkType = metadata?.defaultNetwork
                selectedSubstrateCryptoType = metadata?.defaultCryptoType

                applySourceType()

                view?.didCompleteSourceTypeSelection()

            case .cryptoType:
                selectedSubstrateCryptoType = metadata?.availableCryptoTypes[index]

                applyCryptoTypeViewModel(nil)
                applySubstrateDerivationPathViewModel()

                view?.didCompleteCryptoTypeSelection()

            case .addressType:
                selectedNetworkType = metadata?.availableNetworks[index]

                applyNetworkTypeViewModel(nil)
                view?.didCompleteAddressTypeSelection()
            }
        }
    }

    func modalPickerDidCancel(context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AccountImportContext(rawValue: context as String) {
            switch selectionContext {
            case .sourceType:
                view?.didCompleteSourceTypeSelection()
            case .cryptoType:
                view?.didCompleteCryptoTypeSelection()
            case .addressType:
                view?.didCompleteAddressTypeSelection()
            }
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
