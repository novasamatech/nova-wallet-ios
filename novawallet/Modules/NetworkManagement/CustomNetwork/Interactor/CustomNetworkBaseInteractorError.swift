import Foundation

enum CustomNetworkBaseInteractorError: Error {
    case alreadyExistRemote(node: ChainNodeModel, chain: ChainModel)
    case alreadyExistCustom(node: ChainNodeModel, chain: ChainModel)
    case wrongCurrencySymbol(enteredSymbol: String, actualSymbol: String)
    case invalidPriceUrl
    case invalidChainId
    case invalidNetworkType(selectedType: CustomNetworkType)
    case connecting(innerError: NetworkNodeConnectingError)
    case common(innerError: CommonError)

    init(from error: Error) {
        self = switch error {
        case let NetworkNodeConnectingError.alreadyExists(existingNode, existingChain)
            where existingChain.source == .user:
            .alreadyExistCustom(
                node: existingNode,
                chain: existingChain
            )
        case let NetworkNodeConnectingError.alreadyExists(existingNode, existingChain)
            where existingChain.source == .remote:
            .alreadyExistRemote(
                node: existingNode,
                chain: existingChain
            )
        case is NetworkNodeCorrespondingError:
            .invalidChainId
        case NetworkNodeConnectingError.wrongFormat:
            .connecting(innerError: .wrongFormat)
        case let CustomNetworkSetupError.wrongCurrencySymbol(enteredSymbol, actualSymbol):
            .wrongCurrencySymbol(enteredSymbol: enteredSymbol, actualSymbol: actualSymbol)
        case let CustomNetworkSetupError.chainIdObtainFailed(ethereumBased):
            .invalidNetworkType(selectedType: ethereumBased ? .evm : .substrate)
        case CustomNetworkSetupError.decimalsNotFound:
            .common(innerError: .noDataRetrieved)
        default:
            .common(innerError: .undefined)
        }
    }
}

extension CustomNetworkBaseInteractorError: ErrorContentConvertible {
    // swiftlint:disable function_body_length
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
