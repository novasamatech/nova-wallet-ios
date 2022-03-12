import Foundation
import SubstrateSdk

protocol DisplayAddressViewModelFactoryProtocol {
    func createViewModel(from model: DisplayAddress) -> DisplayAddressViewModel
}

final class DisplayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(from model: DisplayAddress) -> DisplayAddressViewModel {
        let imageViewModel: ImageViewModelProtocol?

        if
            let accountId = try? model.address.toAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            imageViewModel = DrawableIconViewModel(icon: icon)
        } else {
            imageViewModel = nil
        }

        let name = model.username.isEmpty ? nil : model.username

        return DisplayAddressViewModel(
            address: model.address,
            name: name,
            imageViewModel: imageViewModel
        )
    }
}
