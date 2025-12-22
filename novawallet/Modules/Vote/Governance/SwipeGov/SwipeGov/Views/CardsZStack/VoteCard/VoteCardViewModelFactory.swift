import Foundation
import SubstrateSdk

protocol VoteCardViewModelFactoryProtocol {
    func createCardsStackViewModel(
        from model: SwipeGovModelBuilder.Result.Model,
        currentViewModel: CardsZStackViewModel?,
        locale: Locale,
        cardActions: VoteCardViewModel.Actions,
        stackActions: CardsZStack.Actions
    ) -> CardsZStackViewModel
}

struct VoteCardViewModelFactory {
    private let cardGradientFactory = SwipeGovGradientFactory()
    private let summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol
    private let chain: ChainModel
    private let currencyManager: CurrencyManagerProtocol
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol
    private let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    private let spendingAmountExtractor: GovSpendingExtracting

    init(
        summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol,
        chain: ChainModel,
        currencyManager: CurrencyManagerProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        spendingAmountExtractor: GovSpendingExtracting
    ) {
        self.summaryFetchOperationFactory = summaryFetchOperationFactory
        self.chain = chain
        self.currencyManager = currencyManager
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.balanceViewModelFacade = balanceViewModelFacade
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.spendingAmountExtractor = spendingAmountExtractor
    }
}

extension VoteCardViewModelFactory: VoteCardViewModelFactoryProtocol {
    func createCardsStackViewModel(
        from model: SwipeGovModelBuilder.Result.Model,
        currentViewModel: CardsZStackViewModel?,
        locale: Locale,
        cardActions: VoteCardViewModel.Actions,
        stackActions: CardsZStack.Actions
    ) -> CardsZStackViewModel {
        let changes = createStackChangesModel(
            from: model.referendumsChanges,
            using: currentViewModel,
            locale: locale,
            actions: cardActions
        )

        let allCards: [VoteCardId: VoteCardViewModel] = createAllCards(
            using: currentViewModel,
            changes: changes
        )

        let emptyViewModel = createEmptyViewModel(
            model: model,
            locale: locale,
            emptyViewAction: stackActions.emptyViewAction
        )

        let viewModel = CardsZStackViewModel(
            allCards: allCards,
            changeModel: changes,
            emptyViewModel: emptyViewModel,
            validationAction: stackActions.validationClosure
        )

        return viewModel
    }

    private func createEmptyViewModel(
        model: SwipeGovModelBuilder.Result.Model,
        locale: Locale,
        emptyViewAction: @escaping () -> Void
    ) -> SwipeGovEmptyStateViewModel {
        if model.votingList.isEmpty {
            .empty(
                text: R.string(preferredLanguages: locale.rLanguages).localizable.swipeGovEmptyViewText()
            )
        } else {
            .votings(
                .init(
                    text: R.string(preferredLanguages: locale.rLanguages).localizable.swipeGovEmptyViewVotedText(),
                    buttonText: R.string(preferredLanguages: locale.rLanguages).localizable.swipeGovEmptyViewButton(),
                    action: emptyViewAction
                )
            )
        }
    }

    private func createAllCards(
        using currentViewModel: CardsZStackViewModel?,
        changes: CardsZStackChangeModel
    ) -> [VoteCardId: VoteCardViewModel] {
        if let currentViewModel {
            var current = currentViewModel.allCards

            changes.inserts.forEach { current[$0.id] = $0 }
            changes.updates.forEach { current[$0.key] = $0.value }
            changes.deletes.forEach { current[$0] = nil }

            return current
        } else {
            return changes.inserts.reduce(into: [:]) { $0[$1.id] = $1 }
        }
    }

    private func createVoteCardViewModel(
        for referendum: ReferendumLocal,
        locale: Locale,
        actions: VoteCardViewModel.Actions
    ) -> VoteCardViewModel {
        let gradientModel = cardGradientFactory.createCardGradient()
        let requestedAmountFactory = ReferendumAmountOperationFactory(
            referendum: referendum,
            connection: connection,
            runtimeProvider: runtimeProvider,
            actionDetailsOperationFactory: actionDetailsOperationFactory,
            spendAmountExtractor: spendingAmountExtractor
        )

        return VoteCardViewModel(
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            summaryFetchOperationFactory: summaryFetchOperationFactory,
            amountOperationFactory: requestedAmountFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            balanceViewModelFacade: balanceViewModelFacade,
            chain: chain,
            referendum: referendum,
            currencyManager: currencyManager,
            gradient: gradientModel,
            locale: locale,
            actions: actions
        )
    }

    private func createStackChangesModel(
        from changesModel: SwipeGovModelBuilder.Result.ReferendumsListChanges,
        using currentViewModel: CardsZStackViewModel?,
        locale: Locale,
        actions: VoteCardViewModel.Actions
    ) -> CardsZStackChangeModel {
        var inserts: [VoteCardViewModel] = []
        var updates: [VoteCardId: VoteCardViewModel] = [:]

        changesModel.inserts.forEach { referendum in
            inserts.append(
                createVoteCardViewModel(
                    for: referendum,
                    locale: locale,
                    actions: actions
                )
            )
        }

        changesModel.updates.forEach { referendum in
            let viewModel = createVoteCardViewModel(
                for: referendum,
                locale: locale,
                actions: actions
            )

            if currentViewModel?.allCards[viewModel.id] == nil {
                inserts.append(viewModel)
            } else {
                updates[viewModel.id] = viewModel
            }
        }

        return CardsZStackChangeModel(
            inserts: inserts,
            updates: updates,
            deletes: Set(changesModel.deletes)
        )
    }
}
