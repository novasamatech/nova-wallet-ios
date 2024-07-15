import Foundation

enum CustomNetworkBaseInteractorError: Error {
    case alreadyExistRemote(node: ChainNodeModel, chain: ChainModel)
    case alreadyExistCustom(node: ChainNodeModel, chain: ChainModel)
    case wrongCurrencySymbol(enteredSymbol: String, actualSymbol: String)
    case invalidPriceUrl
    case invalidChainId
    case invalidNetworkType(selectedType: ChainType)
    case connecting(innerError: NetworkNodeConnectingError)
    case common(innerError: CommonError)
}

extension CustomNetworkBaseInteractorError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case let .alreadyExistRemote(_, chain):
            .init(
                title: R.string.localizable.networkAddAlertAlreadyExistsTitle(
                    preferredLanguages: locale?.rLanguages
                ),
                message: R.string.localizable.networkAddAlertAlreadyExistsRemoteMessage(
                    chain.name,
                    preferredLanguages: locale?.rLanguages
                )
            )
        case let .alreadyExistCustom(_, chain):
            .init(
                title: R.string.localizable.networkAddAlertAlreadyExistsTitle(
                    preferredLanguages: locale?.rLanguages
                ),
                message: R.string.localizable.networkAddAlertAlreadyExistsCustomMessage(
                    chain.name,
                    preferredLanguages: locale?.rLanguages
                )
            )
        case let .wrongCurrencySymbol(enteredSymbol, actualSymbol):
            .init(
                title: R.string.localizable.networkAddAlertInvalidSymbolTitle(
                    preferredLanguages: locale?.rLanguages
                ),
                message: R.string.localizable.networkAddAlertInvalidSymbolMessage(
                    enteredSymbol,
                    actualSymbol,
                    preferredLanguages: locale?.rLanguages
                )
            )
        case .invalidChainId:
            .init(
                title: R.string.localizable.networkAddAlertInvalidChainIdTitle(
                    preferredLanguages: locale?.rLanguages
                ),
                message: R.string.localizable.networkAddAlertInvalidChainIdMessage(
                    preferredLanguages: locale?.rLanguages
                )
            )
        case let .invalidNetworkType(selectedType):
            .init(
                title: R.string.localizable.networkAddAlertInvalidNetworkTypeTitle(
                    preferredLanguages: locale?.rLanguages
                ),
                message: R.string.localizable.networkAddAlertInvalidNetworkTypeMessage(
                    selectedType == .evm ? "Substrate" : "EVM",
                    preferredLanguages: locale?.rLanguages
                )
            )
        case let .connecting(innerError):
            innerError.toErrorContent(for: locale)
        case let .common(innerError):
            innerError.toErrorContent(for: locale)
        default:
            CommonError.undefined.toErrorContent(for: locale)
        }
    }
}
