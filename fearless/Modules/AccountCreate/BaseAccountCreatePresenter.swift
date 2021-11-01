import UIKit
import IrohaCrypto
import SoraFoundation

class BaseAccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    internal var metadata: MetaAccountCreationMetadata?

    internal var selectedCryptoType: MultiassetCryptoType?

    internal var substrateDerivationPathViewModel: InputViewModelProtocol?
    internal var ethereumDerivationPathViewModel: InputViewModelProtocol?

    internal var displaySubstrate: Bool = true
    internal var displayEthereum: Bool = true

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
        guard displayEthereum == true else {
            view?.setEthereumDerivationPath(viewModel: nil)
            return
        }

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

        guard displaySubstrate == true else {
            view?.setSubstrateDerivationPath(viewModel: nil)
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

    internal func processProceed() {
        fatalError("This function should be overriden")
    }
}

// MARK: - AccountCreatePresenterProtocol

extension BaseAccountCreatePresenter: AccountCreatePresenterProtocol {
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
        processProceed()
    }
}

// MARK: - AccountCreateInteractorOutputProtocol

extension BaseAccountCreatePresenter: AccountCreateInteractorOutputProtocol {
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

extension BaseAccountCreatePresenter: ModalPickerViewControllerDelegate {
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

extension BaseAccountCreatePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyCryptoTypeViewModel()
        }
    }
}
