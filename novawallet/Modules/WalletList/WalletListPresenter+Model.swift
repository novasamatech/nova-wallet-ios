import Foundation
import RobinHood

extension WalletListPresenter {
    static func createNftDiffCalculator() -> ListDifferenceCalculator<NftModel> {
        let sortingBlock: (NftModel, NftModel) -> Bool = { model1, model2 in
            guard let createdAt1 = model1.createdAt, let createdAt2 = model2.createdAt else {
                return true
            }

            return createdAt1.compare(createdAt2) == .orderedDescending
        }

        return ListDifferenceCalculator(initialItems: [], sortBlock: sortingBlock)
    }
}
