import UIKit_iOS
import UIKit

class SwipeGovEmptyStateView: UIView {
    let imageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.imageSiriSwipeGov()
    }

    let textLabel: UILabel = .create { view in
        view.textAlignment = .center
        view.numberOfLines = 0
        view.apply(style: .footnoteSecondary)
    }

    let confirmVotesButton: UIButton = .create { view in
        view.titleLabel?.apply(style: .semiboldSubheadlineAccent)
    }

    private var votingsModel: SwipeGovEmptyStateViewModel.VotingsModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        let stack = UIStackView.vStack(
            spacing: 16,
            [
                imageView,
                textLabel,
                confirmVotesButton
            ]
        )

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        textLabel.snp.makeConstraints { make in
            make.width.equalTo(220)
        }
    }

    func bind(with viewModel: SwipeGovEmptyStateViewModel) {
        switch viewModel {
        case let .votings(votingsModel):
            self.votingsModel = votingsModel

            textLabel.text = votingsModel.text
            confirmVotesButton.setTitle(votingsModel.buttonText, for: .normal)
            confirmVotesButton.setTitleColor(R.color.colorButtonTextAccent(), for: .normal)
            confirmVotesButton.isHidden = false
        case let .empty(text):
            confirmVotesButton.isHidden = true
            textLabel.text = text
        }
    }

    private func setupHandlers() {
        confirmVotesButton.addTarget(
            self,
            action: #selector(confirmVotesAction),
            for: .touchUpInside
        )
    }

    @objc private func confirmVotesAction() {
        votingsModel?.action()
    }
}

enum SwipeGovEmptyStateViewModel {
    struct VotingsModel {
        let text: String
        let buttonText: String
        let action: () -> Void
    }

    case votings(VotingsModel)
    case empty(text: String)
}
