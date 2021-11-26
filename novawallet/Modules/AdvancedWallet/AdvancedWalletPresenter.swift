import Foundation
import SoraFoundation

final class AdvancedWalletPresenter {
    weak var view: AdvancedWalletViewProtocol?
    let wireframe: AdvancedWalletWireframeProtocol

    let settings: AdvancedWalletSettings

    private(set) var substrateDerivationPathViewModel: InputViewModelProtocol?
    private(set) var ethereumDerivationPathViewModel: InputViewModelProtocol?

    init(
        wireframe: AdvancedWalletWireframeProtocol,
        settings: AdvancedWalletSettings
    ) {
        self.wireframe = wireframe
        self.settings = settings
    }

    private func applyAdvanced(_ preferredInfo: MetaAccountImportPreferredInfo?) {
        applyCryptoTypeViewModel(preferredInfo)
        applySubstrateDerivationPathViewModel()
        applyEthereumDerivationPathViewModel()
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
}

extension AdvancedWalletPresenter: AdvancedWalletPresenterProtocol {
    func setup() {}
}

extension AdvancedWalletPresenter: Localizable {
    func applyLocalization() {
        
    }
}
