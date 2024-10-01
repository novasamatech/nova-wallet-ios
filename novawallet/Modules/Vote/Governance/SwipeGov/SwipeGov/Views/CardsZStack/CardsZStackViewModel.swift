typealias VoteCardValidationClosure = (VoteCardViewModel, VoteResult) -> Bool

struct CardsZStackViewModel {
    let allCards: [VoteCardId: VoteCardViewModel]
    let changeModel: CardsZStackChangeModel
    let emptyViewModel: SwipeGovEmptyStateViewModel
    let validationAction: VoteCardValidationClosure?

    var stackIsEmpty: Bool {
        allCards.isEmpty
    }
}

struct CardsZStackChangeModel {
    let inserts: [VoteCardViewModel]
    let updates: [VoteCardId: VoteCardViewModel]
    let deletes: Set<VoteCardId>
}
