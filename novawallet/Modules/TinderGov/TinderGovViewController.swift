import UIKit
import SoraUI
import SoraFoundation

final class TinderGovViewController: UIViewController, ViewHolder {
    typealias RootViewType = TinderGovViewLayout

    let viewModel: TinderGovViewModelProtocol

    private lazy var titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.textAlignment = .center
        view.text = R.string.localizable.commonTinderGov(
            preferredLanguages: selectedLocale.rLanguages
        )
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
        view.text = "7 of 10"
    }

    init(viewModel: TinderGovViewModelProtocol) {
        self.viewModel = viewModel
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

        setupNavigationBar()
        setupActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let cardModels = viewModel.getCardsModel()
        cardModels.forEach { viewModel in
            rootView.addCard(model: viewModel)
        }

        rootView.finishedAddingCards()
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
        viewModel.actionBack()
    }

    @objc private func actionSettings() {
        // TODO: Implement
    }
}

// MARK: TinderGovViewProtocol

extension TinderGovViewController: TinderGovViewProtocol {}

// MARK: Private

private extension TinderGovViewController {
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

extension TinderGovViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }
    }
}

// MARK: Constants

extension TinderGovViewController {
    enum Constants {
        static let navbarButtonSize: CGFloat = 40
    }
}
