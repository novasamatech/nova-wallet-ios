import Foundation
import UIKit
import Foundation_iOS

enum SubtensorStakingViewFactory {
    /// Assembles the TAO staking dashboard VIPER module.
    ///
    /// - Parameters:
    ///   - chainAsset: Bittensor chain + asset (needed for fee and amount formatting).
    ///   - coldkey: The user's account ID (coldkey in Bittensor terminology).
    ///   - entryNetuid: Which netuid the user tapped on the multistaking
    ///     dashboard (root or a subnet). The detail screen scopes its
    ///     "Your stake" total and validator list to this netuid.
    static func createView(
        chainAsset: ChainAsset,
        coldkey: AccountId,
        entryNetuid: UInt16 = SubtensorStakingConstants.rootNetuid
    ) -> SubtensorStakingViewController {
        let delegatesClient = BittensorDelegatesClient()

        let dataSource: SubtensorValidatorDataSourceProtocol = {
            if let key = TaoStatsKeyProvider.loadKey() {
                return TaoStatsValidatorDataSource(apiKey: key, session: .shared)
            } else {
                return StubSubtensorValidatorDataSource()
            }
        }()

        let validatorProvider = SubtensorValidatorProvider(
            delegatesClient: delegatesClient,
            dataSource: dataSource
        )

        // Pull the chain's preferred RPC node so dev / staging configs
        // don't silently fall back to mainnet. Mirrors the resolution
        // already used by `SubtensorMultistakingUpdateService`.
        let rpcURL = chainAsset.chain.nodes
            .compactMap { URL(string: $0.url) }
            .first { $0.scheme == "https" || $0.scheme == "http" }
            ?? URL(string: "https://entrypoint-finney.opentensor.ai")!

        let service = SubtensorStakingService(
            validatorProvider: validatorProvider,
            selectedColdkey: coldkey,
            rpcURL: rpcURL
        )

        let localizationManager = LocalizationManager.shared

        let interactor = SubtensorStakingInteractor(service: service)
        let wireframe = SubtensorStakingWireframe(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        )
        let presenter = SubtensorStakingPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            entryNetuid: entryNetuid
        )
        let view = SubtensorStakingViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
