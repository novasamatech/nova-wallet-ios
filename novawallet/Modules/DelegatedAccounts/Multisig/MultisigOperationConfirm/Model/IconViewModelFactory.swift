import Foundation
import SubstrateSdk

protocol IconViewModelFactoryProtocol {
    func createDrawableIconViewModel(from identiconData: Data?) -> DrawableIconViewModel?

    func createIdentifiableDrawableIconViewModel(
        from identiconData: Data?,
        identifier: String
    ) -> IdentifiableDrawableIconViewModel?

    func createIdentifiableDrawableIconViewModel(
        from accountId: AccountId,
        chainFormat: ChainFormat
    ) -> IdentifiableDrawableIconViewModel?
}

final class IconViewModelFactory {
    private let addressIconGenerator: IconGenerating
    private let walletIconGenerator: IconGenerating

    init(
        addressIconGenerator: IconGenerating = PolkadotIconGenerator(),
        walletIconGenerator: IconGenerating = NovaIconGenerator()
    ) {
        self.addressIconGenerator = addressIconGenerator
        self.walletIconGenerator = walletIconGenerator
    }
}

// MARK: - IconViewModelFactoryProtocol

extension IconViewModelFactory: IconViewModelFactoryProtocol {
    func createDrawableIconViewModel(from identiconData: Data?) -> DrawableIconViewModel? {
        guard
            let identiconData,
            let icon = try? walletIconGenerator.generateFromAccountId(identiconData)
        else { return nil }

        return DrawableIconViewModel(icon: icon)
    }

    func createIdentifiableDrawableIconViewModel(
        from identiconData: Data?,
        identifier: String
    ) -> IdentifiableDrawableIconViewModel? {
        guard let drawableIconViewModel = createDrawableIconViewModel(from: identiconData) else {
            return nil
        }

        return IdentifiableDrawableIconViewModel(drawableIconViewModel, identifier: identifier)
    }

    func createIdentifiableDrawableIconViewModel(
        from accountId: AccountId,
        chainFormat: ChainFormat
    ) -> IdentifiableDrawableIconViewModel? {
        guard
            let icon = try? addressIconGenerator.generateFromAccountId(accountId),
            let address = try? accountId.toAddress(using: chainFormat)
        else { return nil }

        let drawableIconViewModel = DrawableIconViewModel(icon: icon)

        return IdentifiableDrawableIconViewModel(drawableIconViewModel, identifier: address)
    }
}
