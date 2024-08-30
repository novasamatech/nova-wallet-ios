import UIKit

final class TinderGovViewController: UIViewController, ViewHolder {
    typealias RootViewType = TinderGovViewLayout

    let presenter: TinderGovPresenterProtocol

    init(presenter: TinderGovPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TinderGovViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupActions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let cardModels: [VoteCardView.ViewModel] = [
            .init(title: "First"),
            .init(title: "Second"),
            .init(title: "Third"),
            .init(title: "Fourth"),
            .init(title: "Fifth"),
            .init(title: "Sixth"),
            .init(title: "Seventh"),
            .init(title: "Eighth")
        ]

        cardModels.forEach { viewModel in
            rootView.addCard(model: .init(viewModel: viewModel))
        }

        rootView.finishedAddingCards()
    }

    func setupActions() {
        rootView.nayButton.addTarget(
            self,
            action: #selector(actionVoteNay),
            for: .touchUpInside
        )

        rootView.ayeButton.addTarget(
            self,
            action: #selector(actionVoteAye),
            for: .touchUpInside
        )

        rootView.abstainButton.addTarget(
            self,
            action: #selector(actionVoteAbstain),
            for: .touchUpInside
        )
    }

    @objc private func actionVoteNay() {
        rootView.cardsStack.dismissTopCard(to: .left)
    }

    @objc private func actionVoteAye() {
        rootView.cardsStack.dismissTopCard(to: .right)
    }

    @objc private func actionVoteAbstain() {
        rootView.cardsStack.dismissTopCard(to: .top)
    }
}

extension TinderGovViewController: TinderGovViewProtocol {}
