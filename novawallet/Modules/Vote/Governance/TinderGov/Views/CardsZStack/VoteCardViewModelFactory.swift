import Foundation
import SubstrateSdk

protocol VoteCardViewModelFactoryProtocol {
    func createVoteCardViewModels(
        from referendums: [ReferendumLocal],
        locale: Locale,
        onVote: @escaping (VoteResult, ReferendumIdLocal) -> Void,
        onBecomeTop: @escaping (ReferendumIdLocal) -> Void
    ) -> [VoteCardViewModel]
}

struct VoteCardViewModelFactory {
    private let cardGradientFactory = TinderGovGradientFactory()
    private let summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol
    private let chain: ChainModel
    private let currencyManager: CurrencyManagerProtocol
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol

    init(
        summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol,
        chain: ChainModel,
        currencyManager: CurrencyManagerProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    ) {
        self.summaryFetchOperationFactory = summaryFetchOperationFactory
        self.chain = chain
        self.currencyManager = currencyManager
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.balanceViewModelFactory = balanceViewModelFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
    }
}

extension VoteCardViewModelFactory: VoteCardViewModelFactoryProtocol {
    func createVoteCardViewModels(
        from referendums: [ReferendumLocal],
        locale: Locale,
        onVote: @escaping (VoteResult, ReferendumIdLocal) -> Void,
        onBecomeTop: @escaping (ReferendumIdLocal) -> Void
    ) -> [VoteCardViewModel] {
        referendums.enumerated().map { index, referendum in
            let gradientModel = cardGradientFactory.createCardGratient(for: index)

            return VoteCardViewModel(
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                summaryFetchOperationFactory: summaryFetchOperationFactory,
                actionDetailsOperationFactory: actionDetailsOperationFactory,
                priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
                balanceViewModelFactory: balanceViewModelFactory,
                connection: connection,
                runtimeProvider: runtimeProvider,
                chain: chain,
                referendum: referendum,
                currencyManager: currencyManager,
                gradient: gradientModel,
                locale: locale,
                onVote: onVote,
                onBecomeTop: onBecomeTop
            )
        }
    }
}
