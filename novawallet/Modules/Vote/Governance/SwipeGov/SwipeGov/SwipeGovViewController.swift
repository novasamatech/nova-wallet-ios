import UIKit
import UIKit_iOS
import Foundation_iOS

final class SwipeGovViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwipeGovViewLayout

    let presenter: SwipeGovPresenterProtocol

    var cardsStackViewModel: CardsZStackViewModel?

    private lazy var titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.textAlignment = .center
        view.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSwipeGov()
    }

    private lazy var backControl: UIControl = createNavbarControl(
        with: R.image.iconBack()
    )
    private lazy var settingsControl: UIControl = createNavbarControl(
        with: R.image.iconSettings()
    )

    let titleReferendaCounterLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.textAlignment = .center
    }

    init(
        presenter: SwipeGovPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.setup()
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

    @objc private func actionBack() {
        presenter.actionBack()
    }

    @objc private func actionSettings() {
        presenter.actionSettings()
    }

    @objc private func actionVotingList() {
        presenter.actionVotingList()
    }
}

// MARK: SwipeGovViewProtocol

extension SwipeGovViewController: SwipeGovViewProtocol {
    func updateCardsStack(with viewModel: CardsZStackViewModel) {
        rootView.cardsStack.updateStack(with: viewModel.changeModel)
        rootView.cardsStack.setupValidationAction(viewModel.validationAction)
        rootView.emptyStateView.bind(with: viewModel.emptyViewModel)
        rootView.finishedAddingCards()

        if viewModel.stackIsEmpty {
            rootView.hideVoteButtons()
        } else {
            rootView.showVoteButtons()
        }

        notifyPresenterOnEmptyIfNeeded(using: viewModel)

        cardsStackViewModel = viewModel
    }

    func skipCard() {
        rootView.cardsStack.skipCard()
    }

    func updateVotingList(with viewModel: VotingListWidgetViewModel) {
        rootView.votingListWidget.bind(with: viewModel)
        rootView.showVotingListWidget()
    }

    func updateCardsCounter(with text: String) {
        titleReferendaCounterLabel.text = text
    }

    func didReceive(canOpenSettings: Bool) {
        settingsControl.isEnabled = canOpenSettings
    }

    func didUpdateVotingPower(for modelId: VoteCardId, voteResult: VoteResult) {
        rootView.cardsStack.dismissTopIf(cardId: modelId, voteResult: voteResult)
    }
}

// MARK: Private

private extension SwipeGovViewController {
    func notifyPresenterOnEmptyIfNeeded(using viewModel: CardsZStackViewModel) {
        guard
            let oldViewModel = cardsStackViewModel,
            viewModel.stackIsEmpty,
            !oldViewModel.stackIsEmpty
        else {
            return
        }

        presenter.cardsStackBecameEmpty()
    }

    func setupNavigationBar() {
        let titleStackView = UIStackView.vStack(
            spacing: 2,
            [
                titleLabel,
                titleReferendaCounterLabel
            ]
        )

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backControl)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsControl)
        navigationItem.titleView = titleStackView
    }

    func setupActions() {
        rootView.votingListWidget.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(actionVotingList)
            )
        )

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
        backControl.addTarget(
            self,
            action: #selector(actionBack),
            for: .touchUpInside
        )
        settingsControl.addTarget(
            self,
            action: #selector(actionSettings),
            for: .touchUpInside
        )
    }

    func createNavbarControl(with icon: UIImage?) -> UIControl {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.cornerRadius = Constants.navbarButtonSize / 2
        button.roundedBackgroundView?.strokeWidth = 1.0
        button.roundedBackgroundView?.strokeColor = R.color.colorContainerBorder()!
        button.imageWithTitleView?.iconImage = icon

        return button
    }
}

// MARK: Localizable

extension SwipeGovViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }
    }
}

// MARK: Constants

extension SwipeGovViewController {
    enum Constants {
        static let navbarButtonSize: CGFloat = 40
    }
}
