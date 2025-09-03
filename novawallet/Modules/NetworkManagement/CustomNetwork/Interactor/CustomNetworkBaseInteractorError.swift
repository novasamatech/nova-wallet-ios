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
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertAlreadyExistsTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertAlreadyExistsRemoteMessage(
                    chain.name
                )
            )
        case let .alreadyExistCustom(_, chain):
            .init(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertAlreadyExistsTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertAlreadyExistsCustomMessage(
                    chain.name
                )
            )
        case let .wrongCurrencySymbol(enteredSymbol, actualSymbol):
            .init(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertInvalidSymbolTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertInvalidSymbolMessage(
                    enteredSymbol,
                    actualSymbol
                )
            )
        case .invalidChainId:
            .init(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertInvalidChainIdTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertInvalidChainIdMessage()
            )
        case let .invalidNetworkType(selectedType):
            .init(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertInvalidNetworkTypeTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.networkAddAlertInvalidNetworkTypeMessage(
                    selectedType == .evm ? "Substrate" : "EVM"
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
