import Foundation
import Operation_iOS

protocol FeatureSupportChecking {
    var featureSupportChecker: FeatureSupportCheckerProtocol { get }

    func checkingSupport(
        of feature: SupportCheckingFeatureType,
        for metaAccountModel: MetaAccountModel,
        sheetPresentingView: ControllerBackedProtocol?,
        onRefusal: ((OperationCheckCommonResult) -> Void)?,
        successClosure: @escaping () -> Void
    )
}

extension FeatureSupportChecking where Self: MessageSheetPresentable {
    var featureSupportChecker: FeatureSupportCheckerProtocol {
        FeatureSupportChecker(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            userStorageFacade: UserDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    func checkingSupport(
        of feature: SupportCheckingFeatureType,
        for metaAccountModel: MetaAccountModel,
        sheetPresentingView: ControllerBackedProtocol?,
        onRefusal: ((OperationCheckCommonResult) -> Void)? = nil,
        successClosure: @escaping () -> Void
    ) {
        guard let sheetPresentingView else { return }

        let completion: FeatureSupportCheckerClosure = { [weak self] result in
            if !result.isAvailable {
                onRefusal?(result)
            }

            self?.presentOperationCompletion(
                on: sheetPresentingView,
                by: result,
                successRouteClosure: successClosure
            )
        }

        switch feature {
        case let .ramp(type, chainAsset, all):
            featureSupportChecker.checkRampSupport(
                wallet: metaAccountModel,
                rampActions: all,
                rampType: type,
                chainAsset: chainAsset,
                completion: completion
            )
        case let .gift(chains):
            featureSupportChecker.checkGiftSupport(for: metaAccountModel, chains: chains, completion: completion)
        case let .subtensorStaking(chain):
            featureSupportChecker.checkSubtensorStakingSupport(
                for: metaAccountModel,
                chain: chain,
                completion: completion
            )
        }
    }
}
