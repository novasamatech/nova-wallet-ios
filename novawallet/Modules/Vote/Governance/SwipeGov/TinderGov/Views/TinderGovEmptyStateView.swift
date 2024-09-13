import SoraUI
import UIKit

class TinderGovEmptyStateView: UIView {
    let imageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.imageSiriTinderGov()
    }

    let textLabel: UILabel = .create { view in
        view.textAlignment = .center
        view.apply(style: .footnoteSecondary)
    }

    let confirmVotesButton: UIButton = .create { view in
        view.titleLabel?.apply(style: .semiboldSubheadlineAccent)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
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
    }

    func bind(with viewModel: TinderGovEmptyStateViewModel) {
        switch viewModel {
        case let .votings(votingsModel):
            textLabel.text = votingsModel.text
            confirmVotesButton.setTitle(votingsModel.buttonText, for: .normal)
            confirmVotesButton.isHidden = false
        case let .empty(text):
            confirmVotesButton.isHidden = true
            textLabel.text = text
        }
    }
}

enum TinderGovEmptyStateViewModel {
    struct VotingsModel {
        let text: String
        let buttonText: String
    }

    case votings(VotingsModel)
    case empty(text: String)
}
