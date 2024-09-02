import UIKit
import SoraUI
import SoraFoundation

final class TinderGovViewController: UIViewController, ViewHolder {
    typealias RootViewType = TinderGovViewLayout

    let presenter: TinderGovPresenterProtocol

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

        setupNavigationBar()
        setupActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let cardModels: [VoteCardView.ViewModel] = [
            .init(
                // swiftlint:disable:next line_length
                summary: "The Mythos Foundation and Mythical Games propose a token swap of 1,000,000 DOT for 20,000,000 MYTH tokens to celebrate Mythical Games joining Polkadot, enhancing blockchain gaming and benefiting DOT holders.",
                requestedAmount: .init(
                    assetAmount: "1M DOT",
                    fiatAmount: "$7,42M"
                ),
                gradientModel: .tinderGovCell()
            ),
            .init(
                // swiftlint:disable:next line_length
                summary: "Sovereign Nature proposes DOTphin Event Multipass with WalletConnect integration & dynamic NFTs by Unique Network for Polkadot events, aiming for unified proof of attendance and immersive engagement.",
                requestedAmount: .init(
                    assetAmount: "50,000 DOT",
                    fiatAmount: "$371,000"
                ),
                gradientModel: .tinderGovCell()
            ),
            .init(
                // swiftlint:disable:next line_length
                summary: "Georgi_PS proposes a bounty for technical support in Polkadot. Curator candidates, diverse in background, will review submissions and provide community updates.",
                requestedAmount: nil,
                gradientModel: .tinderGovCell()
            ),
            .init(
                // swiftlint:disable:next line_length
                summary: "The Mythos Foundation and Mythical Games propose a token swap of 1,000,000 DOT for 20,000,000 MYTH tokens to celebrate Mythical Games joining Polkadot, enhancing blockchain gaming and benefiting DOT holders.",
                requestedAmount: .init(
                    assetAmount: "1M DOT",
                    fiatAmount: "$7,42M"
                ),
                gradientModel: .tinderGovCell()
            ),
            .init(
                // swiftlint:disable:next line_length
                summary: "Sovereign Nature proposes DOTphin Event Multipass with WalletConnect integration & dynamic NFTs by Unique Network for Polkadot events, aiming for unified proof of attendance and immersive engagement.",
                requestedAmount: .init(
                    assetAmount: "50,000 DOT",
                    fiatAmount: "$371,000"
                ),
                gradientModel: .tinderGovCell()
            ),
            .init(
                // swiftlint:disable:next line_length
                summary: "Georgi_PS proposes a bounty for technical support in Polkadot. Curator candidates, diverse in background, will review submissions and provide community updates.",
                requestedAmount: nil,
                gradientModel: .tinderGovCell()
            )
        ]

        cardModels.forEach { viewModel in
            rootView.addCard(model: .init(viewModel: viewModel))
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
        presenter.actionBack()
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
