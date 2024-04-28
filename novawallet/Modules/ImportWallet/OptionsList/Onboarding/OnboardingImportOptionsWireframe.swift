import Foundation

final class OnboardingImportOptionsWireframe: OnboardingImportOptionsWireframeProtocol {
    func showCloudImport(from _: WalletImportOptionsViewProtocol?) {}

    func showPassphraseImport(from _: WalletImportOptionsViewProtocol?) {}

    func showHardwareImport(from _: WalletImportOptionsViewProtocol?) {}

    func showWatchOnlyImport(from _: WalletImportOptionsViewProtocol?) {}

    func showSeedImport(from _: WalletImportOptionsViewProtocol?) {}

    func showRestoreJsonImport(from _: WalletImportOptionsViewProtocol?) {}
}
