import Foundation
import SubstrateSdk

protocol VoteCardViewModelFactoryProtocol {
    func createCardsStackViewModel(
        from model: SwipeGovModelBuilder.Result.Model,
        currentViewModel: CardsZStackViewModel?,
        locale: Locale,
        actions: VoteCardViewModel.Actions,
        emptyViewAction: @escaping () -> Void,
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
        currentViewModel: CardsZStackViewModel?,
        locale: Locale,
        actions: VoteCardViewModel.Actions,
        emptyViewAction: @escaping () -> Void,
        validationClosure: @escaping (VoteCardViewModel?) -> Bool
    ) -> CardsZStackViewModel {
        let changes = createStackChangesModel(
            from: model.referendumsChanges,
            using: currentViewModel,
            locale: locale,
            actions: actions
        )

        let allCards: [VoteCardId: VoteCardViewModel] = createAllCards(
            using: currentViewModel,
            changes: changes
        )

        let emptyViewModel = createEmptyViewModel(
            model: model,
            locale: locale,
            emptyViewAction: emptyViewAction
        )

        let viewModel = CardsZStackViewModel(
            allCards: allCards,
            changeModel: changes,
            emptyViewModel: emptyViewModel,
            validationAction: validationClosure
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
                text: R.string.localizable.swipeGovEmptyViewText(
                    preferredLanguages: locale.rLanguages
                )
            )
        } else {
            .votings(
                .init(
                    text: R.string.localizable.swipeGovEmptyViewVotedText(
                        preferredLanguages: locale.rLanguages
                    ),
                    buttonText: R.string.localizable.swipeGovEmptyViewButton(
                        preferredLanguages: locale.rLanguages
                    ),
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
        for index: Int,
        referendum: ReferendumLocal,
        locale: Locale,
        actions: VoteCardViewModel.Actions
    ) -> VoteCardViewModel {
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

    private func createStackChangesModel(
        from changesModel: SwipeGovModelBuilder.Result.ReferendumsListChanges,
        using currentViewModel: CardsZStackViewModel?,
        locale: Locale,
        actions: VoteCardViewModel.Actions
    ) -> CardsZStackChangeModel {
        var inserts: [VoteCardViewModel] = []
        var updates: [VoteCardId: VoteCardViewModel] = [:]

        changesModel.inserts.enumerated().forEach { index, referendum in
            inserts.append(
                createVoteCardViewModel(
                    for: index,
                    referendum: referendum,
                    locale: locale,
                    actions: actions
                )
            )
        }

        changesModel.updates.enumerated().forEach { index, referendum in
            let viewModel = createVoteCardViewModel(
                for: index,
                referendum: referendum,
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
