import UIKit
import IrohaCrypto
import SoraFoundation

final class AccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    let usernameSetup: UsernameSetupModel

    private var metadata: MetaAccountCreationMetadata?

    private var selectedCryptoType: MultiassetCryptoType?

    private var substrateDerivationPathViewModel: InputViewModelProtocol?
    private var ethereumDerivationPathViewModel: InputViewModelProtocol?

    init(usernameSetup: UsernameSetupModel) {
        self.usernameSetup = usernameSetup
    }

    private func applyCryptoTypeViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = TitleWithSubtitleViewModel(
            title: cryptoType.titleForLocale(locale),
            subtitle: cryptoType.subtitleForLocale(locale)
        )

        view?.setSelectedCrypto(model: viewModel)
    }

    private func applyEthereumDerivationPathViewModel() {
        let predicate = NSPredicate.deriviationPathHardSoftNumericPassword
        let placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder

        let inputHandling = InputHandler(predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: placeholder)

        ethereumDerivationPathViewModel = viewModel

        view?.setEthereumDerivationPath(viewModel: viewModel)
        view?.didValidateEthereumDerivationPath(.none)
    }

    private func applySubstrateDerivationPathViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            predicate = NSPredicate.deriviationPathHardSoftPassword
            placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
        } else {
            predicate = NSPredicate.deriviationPathHardPassword
            placeholder = DerivationPathConstants.hardPasswordPlaceholder
        }

        let inputHandling = InputHandler(predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: placeholder)

        substrateDerivationPathViewModel = viewModel

        view?.setSubstrateDerivationPath(viewModel: viewModel)
        view?.didValidateSubstrateDerivationPath(.none)
    }

    private func presentDerivationPathError(_ cryptoType: MultiassetCryptoType) {
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

    private func validateSubstrate() {
        guard let viewModel = substrateDerivationPathViewModel, let cryptoType = selectedCryptoType else {
            return
        }

        if viewModel.inputHandler.completed {
            view?.didValidateSubstrateDerivationPath(.valid)
        } else {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(cryptoType)
        }
    }

    private func validateEthereum() {
        guard let viewModel = ethereumDerivationPathViewModel else { return }

        if viewModel.inputHandler.completed {
            view?.didValidateEthereumDerivationPath(.valid)
        } else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(.ethereumEcdsa)
        }
    }
}

// MARK: - AccountCreatePresenterProtocol

extension AccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateInfo() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let message = R.string.localizable.accountCreationInfo(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.commonInfo(preferredLanguages: locale.rLanguages)
        wireframe.present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }

    func validate() {
        validateSubstrate()
        validateEthereum()
    }

    func selectCryptoType() {
        if let metadata = metadata {
            let selectedType = selectedCryptoType ?? metadata.defaultCryptoType
            wireframe.presentCryptoTypeSelection(
                from: view,
                availableTypes: metadata.availableCryptoTypes,
                selectedType: selectedType,
                delegate: self,
                context: nil
            )
        }
    }

    func proceed() {
        guard
            let cryptoType = selectedCryptoType,
            let substrateViewModel = substrateDerivationPathViewModel,
            let ethereumViewModel = ethereumDerivationPathViewModel,
            let metadata = metadata
        else {
            return
        }

        guard substrateViewModel.inputHandler.completed else {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(cryptoType)
            return
        }

        guard ethereumViewModel.inputHandler.completed else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(.ethereumEcdsa)
            return
        }

        let substrateDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ?? ""

        let ethereumDerivationPath = ethereumViewModel.inputHandler.value.isEmpty ?
            DerivationPathConstants.defaultEthereum : substrateViewModel.inputHandler.value

        let request = MetaAccountCreationRequest(
            username: usernameSetup.username,
            derivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethereumDerivationPath,
            cryptoType: cryptoType
        )

        wireframe.confirm(from: view, request: request, metadata: metadata)
    }
}

// MARK: - AccountCreateInteractorOutputProtocol

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata: MetaAccountCreationMetadata) {
        self.metadata = metadata

        selectedCryptoType = metadata.defaultCryptoType

        view?.set(mnemonic: metadata.mnemonic)

        applyCryptoTypeViewModel()
        applySubstrateDerivationPathViewModel()
        applyEthereumDerivationPathViewModel()
    }

    func didReceiveMnemonicGeneration(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
    }
}

// MARK: - ModalPickerViewControllerDelegate

extension AccountCreatePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        selectedCryptoType = metadata?.availableCryptoTypes[index]

        applyCryptoTypeViewModel()
        applySubstrateDerivationPathViewModel()

        view?.didCompleteCryptoTypeSelection()
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        view?.didCompleteCryptoTypeSelection()
    }
}

// MARK: - Localizable

extension AccountCreatePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyCryptoTypeViewModel()
        }
    }
}
