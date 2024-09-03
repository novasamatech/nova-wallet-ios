import Foundation

final class TinderGovViewModel {
    weak var view: TinderGovViewProtocol?
    let wireframe: TinderGovWireframeProtocol

    private let referendums: [ReferendumLocal] = []
    private let cardGradientFactory = TinderGovGradientFactory()

    init(wireframe: TinderGovWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension TinderGovViewModel: TinderGovViewModelProtocol {
    func bind() {}

    func actionBack() {
        wireframe.back(from: view)
    }

    // TODO: Change to binding model
    func getCardsModel() -> [VoteCardViewModel] {
        (0 ..< 10).map { index in
            let gradientModel = cardGradientFactory.createCardGratient(for: index)

            return VoteCardViewModel(
                referendum: .init(index: 0, state: .executed, proposer: .empty),
                gradient: gradientModel
            )
        }
    }
}
