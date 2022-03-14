import Foundation

protocol NetworkViewModelFactoryProtocol {
    func createViewModel(from chain: ChainModel) -> NetworkViewModel
}

final class NetworkViewModelFactory: NetworkViewModelFactoryProtocol {
    private lazy var gradientFactory = CSSGradientFactory()

    func createViewModel(from chain: ChainModel) -> NetworkViewModel {
        let color: GradientModel

        if
            let colorString = chain.color,
            let colorModel = gradientFactory.createFromString(colorString) {
            color = colorModel
        } else {
            color = GradientModel.defaultGradient
        }

        let imageViewModel = RemoteImageViewModel(url: chain.icon)

        return NetworkViewModel(
            name: chain.name,
            icon: imageViewModel,
            gradient: color
        )
    }
}
