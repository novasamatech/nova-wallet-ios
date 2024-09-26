import Foundation
import SubstrateSdk

protocol VoteCardViewModelFactoryProtocol {
    func createCardsStackViewModel(
        from model: SwipeGovModelBuilder.Result.Model,
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
    private let spendingAmountExtractor: GovSpendingExtracting

    init(
        summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol,
        chain: ChainModel,
        currencyManager: CurrencyManagerProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        spendingAmountExtractor: GovSpendingExtracting
    ) {
        self.summaryFetchOperationFactory = summaryFetchOperationFactory
        self.chain = chain
        self.currencyManager = currencyManager
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.balanceViewModelFactory = balanceViewModelFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.spendingAmountExtractor = spendingAmountExtractor
    }
}

extension VoteCardViewModelFactory: VoteCardViewModelFactoryProtocol {
    func createCardsStackViewModel(
        from model: SwipeGovModelBuilder.Result.Model,
        locale: Locale,
        actions: VoteCardViewModel.Actions,
        emptyViewAction: @escaping () -> Void,
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

        let emptyViewModel = createEmptyViewModel(
            model: model,
            locale: locale,
            emptyViewAction: emptyViewAction
        )

        // we use <= instead of == to cover the case where there might be no
        // loaded referendums yet, but we have voting items persisted
        let stackIsEmpty = (model.referendums.count - model.votingList.count) <= 0

        let viewModel = CardsZStackViewModel(
            changeModel: stackChangeModel,
            emptyViewModel: emptyViewModel,
            validationAction: validationClosure,
            stackIsEmpty: stackIsEmpty
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
                actionDetailsOperationFactory: actionDetailsOperationFactory,
                spendAmountExtractor: spendingAmountExtractor
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
