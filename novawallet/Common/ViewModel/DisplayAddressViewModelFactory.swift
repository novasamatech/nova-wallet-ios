import Foundation
import SubstrateSdk

protocol DisplayAddressViewModelFactoryProtocol {
    func createViewModel(from model: DisplayAddress) -> DisplayAddressViewModel

    func createViewModel(from model: DisplayAddress, using chainFormat: ChainFormat) -> DisplayAddressViewModel

    func createViewModel(from address: AccountAddress, name: String?, iconUrl: URL?) -> DisplayAddressViewModel

    func createViewModel(
        from pool: NominationPools.SelectedPool,
        chainAsset: ChainAsset
    ) -> DisplayAddressViewModel

    func createViewModel(
        from formattedCallAccount: FormattedCall.Account,
        chain: ChainModel
    ) throws -> DisplayAddressViewModel
}

extension DisplayAddressViewModelFactoryProtocol {
    func createViewModel(from address: AccountAddress) -> DisplayAddressViewModel {
        createViewModel(from: address, name: nil, iconUrl: nil)
    }
}

final class DisplayAddressViewModelFactory {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var poolIconFactory = NominationPoolsIconFactory()
    private lazy var accountIconFactory = IconViewModelFactory()

    private func createViewModel(
        from model: DisplayAddress,
        chainFormat: ChainFormat?
    ) -> DisplayAddressViewModel {
        let imageViewModel: ImageViewModelProtocol?
        let accountId: AccountId?
        if let chainFormat = chainFormat {
            accountId = try? model.address.toAccountId(using: chainFormat)
        } else {
            accountId = try? model.address.toAccountId()
        }

        if
            let accountId = accountId,
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

// MARK: - DisplayAddressViewModelFactoryProtocol

extension DisplayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol {
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

    func createViewModel(
        from pool: NominationPools.SelectedPool,
        chainAsset: ChainAsset
    ) -> DisplayAddressViewModel {
        let poolIcon = poolIconFactory.createIconViewModel(
            for: chainAsset,
            poolId: pool.poolId,
            bondedAccountId: pool.bondedAccountId
        )

        let address = pool.bondedAddress(for: chainAsset.chain.chainFormat)

        return .init(
            address: address ?? "",
            name: pool.name,
            imageViewModel: poolIcon
        )
    }

    func createViewModel(from model: DisplayAddress) -> DisplayAddressViewModel {
        createViewModel(from: model, chainFormat: nil)
    }

    func createViewModel(from model: DisplayAddress, using chainFormat: ChainFormat) -> DisplayAddressViewModel {
        createViewModel(from: model, chainFormat: chainFormat)
    }

    func createViewModel(
        from formattedCallAccount: FormattedCall.Account,
        chain: ChainModel
    ) throws -> DisplayAddressViewModel {
        let accountAddress = try formattedCallAccount.accountId.toAddress(using: chain.chainFormat)

        let name: String?
        let imageViewModel: ImageViewModelProtocol?

        switch formattedCallAccount {
        case let .local(localAccount):
            imageViewModel = accountIconFactory.createDrawableIconViewModel(
                from: localAccount.walletIdenticonData
            )
            name = localAccount.chainAccount.name
        case let .remote(accountId):
            imageViewModel = accountIconFactory.createIdentifiableDrawableIconViewModel(
                from: accountId,
                chainFormat: chain.chainFormat
            )
            name = nil
        }

        return DisplayAddressViewModel(
            address: accountAddress,
            name: name,
            imageViewModel: imageViewModel
        )
    }
}
