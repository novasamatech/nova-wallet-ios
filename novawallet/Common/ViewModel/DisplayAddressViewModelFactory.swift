import Foundation
import SubstrateSdk

protocol DisplayAddressViewModelFactoryProtocol {
    func createViewModel(from model: DisplayAddress) -> DisplayAddressViewModel
    func createViewModel(from address: AccountAddress, name: String?, iconUrl: URL?) -> DisplayAddressViewModel
}

extension DisplayAddressViewModelFactoryProtocol {
    func createViewModel(from address: AccountAddress) -> DisplayAddressViewModel {
        createViewModel(from: address, name: nil, iconUrl: nil)
    }
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

    func createViewModel(from address: AccountAddress, name: String?, iconUrl: URL?) -> DisplayAddressViewModel {
        let imageViewModel: ImageViewModelProtocol?

        if let icon = iconUrl {
            imageViewModel = RemoteImageViewModel(url: icon)
        } else if
            let accountId = try? address.toAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            imageViewModel = DrawableIconViewModel(icon: icon)
        } else {
            imageViewModel = nil
        }

        return DisplayAddressViewModel(
            address: address,
            name: name,
            imageViewModel: imageViewModel
        )
    }
}
