// swiftlint:disable:next type_name
final class DAppOperationGenericConfirmViewModelFactory: DAppOperationBaseConfirmViewModelFactory {
    override func createNetworkViewModel() -> DAppOperationConfirmViewModel.Network? {
        let networkIcon: ImageViewModelProtocol?

        if let networkIconUrl = chain.networkIcon {
            networkIcon = RemoteImageViewModel(url: networkIconUrl)
        } else {
            networkIcon = nil
        }

        return .init(
            name: chain.networkName,
            iconViewModel: networkIcon
        )
    }
}
