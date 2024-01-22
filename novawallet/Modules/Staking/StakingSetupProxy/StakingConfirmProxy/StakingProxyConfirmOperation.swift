import SubstrateSdk
import SoraFoundation

enum StakingProxyConfirmOperation {
    case add
    case remove

    func builderClosure(
        callFactory: SubstrateCallFactoryProtocol,
        accountId: AccountId
    ) -> ExtrinsicBuilderClosure {
        switch self {
        case .add:
            let call = callFactory.addProxy(
                accountId: accountId,
                type: .staking
            )
            return { builder in
                try builder.adding(call: call)
            }
        case .remove:
            let call = callFactory.removeProxy(
                accountId: accountId,
                type: .staking
            )
            return { builder in
                try builder.adding(call: call)
            }
        }
    }

    var title: LocalizableResource<String> {
        switch self {
        case .add:
            return .init {
                R.string.localizable.delegationsAddTitle(
                    preferredLanguages: $0.rLanguages
                )
            }
        case .remove:
            return .init {
                R.string.localizable.stakingProxyManagementRevokeAccess(
                    preferredLanguages: $0.rLanguages
                )
            }
        }
    }

    func validationFactory(dataValidatingFactory: ProxyDataValidatorFactoryProtocol) -> ProxyConfirmValidationsFactoryProtocol {
        switch self {
        case .add:
            return AddProxyValidationsFactory(dataValidatingFactory: dataValidatingFactory)
        case .remove:
            return RemoveProxyValidationsFactory(dataValidatingFactory: dataValidatingFactory)
        }
    }
}
