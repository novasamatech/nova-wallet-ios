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

// MARK: - Multisig check

private extension FeatureSupportChecking where Self: MessageSheetPresentable {
    func handleHasSupport(
        _ hasSupport: Bool,
        wallet: MetaAccountModel,
        feature: SupportCheckingFeatureType,
        sheetPresentingView: ControllerBackedProtocol,
        successClosure: @escaping () -> Void
    ) {
        guard !hasSupport else {
            successClosure()
            return
        }

        presentFeatureUnsupportedView(
            from: sheetPresentingView,
            type: feature,
            walletType: .init(walletType: wallet.type),
            completion: {}
        )
    }
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
        case let .sell(chainAsset):
            featureSupportChecker.checkSellSupport(
                for: metaAccountModel,
                chainAsset: chainAsset
            ) { [weak self] hasSupport in
                self?.handleHasSupport(
                    hasSupport,
                    wallet: metaAccountModel,
                    feature: feature,
                    sheetPresentingView: sheetPresentingView,
                    successClosure: successClosure
                )
            }
        case .card:
            featureSupportChecker.checkCardSupport(
                for: metaAccountModel
            ) { [weak self] hasSupport in
                self?.handleHasSupport(
                    hasSupport,
                    wallet: metaAccountModel,
                    feature: feature,
                    sheetPresentingView: sheetPresentingView,
                    successClosure: successClosure
                )
            }
        }
    }
}
