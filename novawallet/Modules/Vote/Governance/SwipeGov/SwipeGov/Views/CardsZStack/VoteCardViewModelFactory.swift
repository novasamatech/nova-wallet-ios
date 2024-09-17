import Foundation
import SubstrateSdk

protocol VoteCardViewModelFactoryProtocol {
    func createCardsStackViewModel(
        from model: SwipeGovModelBuilder.Result.Model,
        locale: Locale,
        actions: VoteCardViewModel.Actions,
        validationClosure: @escaping (VoteCardViewModel?) -> Bool
    ) -> CardsZStackViewModel
}

struct VoteCardViewModelFactory {
    private let cardGradientFactory = SwipeGovGradientFactory()
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
    func createCardsStackViewModel(
        from model: SwipeGovModelBuilder.Result.Model,
        locale: Locale,
        actions: VoteCardViewModel.Actions,
        validationClosure: @escaping (VoteCardViewModel?) -> Bool
    ) -> CardsZStackViewModel {
        let inserts = createVoteCardViewModels(
            from: model.referendumsChanges.inserts,
            locale: locale,
            actions: actions
        )

        let updates = createVoteCardViewModels(
            from: model.referendumsChanges.updates,
            locale: locale,
            actions: actions
        ).reduce(into: [:]) { $0[$1.id] = $1 }

        let deletes = Set(model.referendumsChanges.deletes)

        let stackChangeModel = CardsZStackChangeModel(
            inserts: inserts,
            updates: updates,
            deletes: deletes
        )

        let viewModel = CardsZStackViewModel(
            changeModel: stackChangeModel,
            validationAction: validationClosure
        )

        return viewModel
    }

    private func createVoteCardViewModels(
        from referendums: [ReferendumLocal],
        locale: Locale,
        actions: VoteCardViewModel.Actions
    ) -> [VoteCardViewModel] {
        referendums.enumerated().map { index, referendum in
            let gradientModel = cardGradientFactory.createCardGradient(for: index)
            let requestedAmountFactory = ReferendumAmountOperationFactory(
                referendum: referendum,
                connection: connection,
                runtimeProvider: runtimeProvider,
                actionDetailsOperationFactory: actionDetailsOperationFactory
            )

            return VoteCardViewModel(
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                summaryFetchOperationFactory: summaryFetchOperationFactory,
                amountOperationFactory: requestedAmountFactory,
                priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
                balanceViewModelFactory: balanceViewModelFactory,
                chain: chain,
                referendum: referendum,
                currencyManager: currencyManager,
                gradient: gradientModel,
                locale: locale,
                actions: actions
            )
        }
    }
}
