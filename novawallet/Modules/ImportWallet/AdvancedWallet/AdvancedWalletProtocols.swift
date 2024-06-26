import Foundation
import SoraFoundation

protocol AdvancedWalletViewProtocol: ControllerBackedProtocol {
    func setSubstrateCrypto(viewModel: SelectableViewModel<TitleWithSubtitleViewModel>?)
    func setEthreumCrypto(viewModel: SelectableViewModel<TitleWithSubtitleViewModel>?)
    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol?)
    func setEthereumDerivationPath(viewModel: InputViewModelProtocol?)

    func didCompleteCryptoTypeSelection()
}

protocol AdvancedWalletPresenterProtocol: AnyObject {
    func setup()
    func selectSubstrateCryptoType()
    func selectEthereumCryptoType()
    func apply()
}

protocol AdvancedWalletWireframeProtocol: AlertPresentable, ErrorPresentable {
    func presentCryptoTypeSelection(
        from view: AdvancedWalletViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?
    )

    func complete(from view: AdvancedWalletViewProtocol?)
}

protocol AdvancedWalletSettingsDelegate: AnyObject {
    func didReceiveNewAdvanced(walletSettings: AdvancedWalletSettings)
}
