import Foundation
import Operation_iOS

protocol FeatureSupportChecking {
    var featureSupportChecker: FeatureSupportCheckerProtocol { get }

    func checkingSupport(
        of feature: SupportCheckingFeatureType,
        for metaAccountModel: MetaAccountModel,
        sheetPresentingView: ControllerBackedProtocol?,
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
        successClosure: @escaping () -> Void
    ) {
        guard let sheetPresentingView else { return }

        switch feature {
        case let .ramp(type, chainAsset, all):
            featureSupportChecker.checkRampSupport(
                wallet: metaAccountModel,
                rampActions: all,
                rampType: type,
                chainAsset: chainAsset
            ) { [weak self] result in
                self?.presentOperationCompletion(
                    on: sheetPresentingView,
                    by: result,
                    successRouteClosure: successClosure
                )
            }
        case .card:
            featureSupportChecker.checkCardSupport(
                for: metaAccountModel
            ) { [weak self] result in
                self?.presentOperationCompletion(
                    on: sheetPresentingView,
                    by: result,
                    successRouteClosure: successClosure
                )
            }
        case let .gift(chains):
            featureSupportChecker.checkGiftSupport(
                for: metaAccountModel,
                chains: chains
            ) { [weak self] result in
                self?.presentOperationCompletion(
                    on: sheetPresentingView,
                    by: result,
                    successRouteClosure: successClosure
                )
            }
        }
    }
}
