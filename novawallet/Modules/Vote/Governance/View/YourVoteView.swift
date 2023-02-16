import UIKit

final class YourVotesView: UIView {
    let topLine = createSeparator(color: R.color.colorDivider()!)
    let ayeView: YourVoteView = .create {
        $0.apply(style: .aye)
    }

    let nayView: YourVoteView = .create {
        $0.apply(style: .nay)
    }

    let abstainView: YourVoteView = .create {
        $0.apply(style: .abstain)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: 12,
            [
                topLine,
                ayeView,
                nayView,
                abstainView
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 13, left: 0, bottom: 0, right: 0))
        }
        topLine.snp.makeConstraints {
            $0.height.equalTo(1)
        }
    }
}

extension YourVotesView {
    struct Model {
        let aye: YourVoteView.Model?
        let nay: YourVoteView.Model?
        let abstain: YourVoteView.Model?
    }

    func bind(viewModel: Model) {
        ayeView.isHidden = viewModel.aye == nil
        ayeView.bind(viewModel: viewModel.aye)
        nayView.isHidden = viewModel.nay == nil
        nayView.bind(viewModel: viewModel.nay)
        abstainView.isHidden = viewModel.abstain == nil
        abstainView.bind(viewModel: viewModel.abstain)
    }
}

final class YourVoteView: UIView {
    let typeView: BorderedLabelView = .create {
        $0.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
    }

    let voteLabel = UILabel(style: .votes, textAlignment: .left)
    lazy var content: UIStackView = UIView.hStack(
        spacing: 6,
        [
            typeView,
            voteLabel
        ]
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        voteLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension YourVoteView {
    struct Model {
        let title: String
        let description: String
        let style: YourVoteView.Style
    }

    func bind(viewModel: Model?) {
        typeView.titleLabel.text = viewModel?.title
        voteLabel.text = viewModel?.description

        if let style = viewModel?.style {
            apply(style: style)
        }
    }
}

extension YourVoteView {
    struct Style {
        let voteLabel: UILabel.Style
        let typeView: UILabel.Style
        let mode: Mode

        enum Mode {
            case titleType, typeTitle
        }
    }

    func apply(style: Style) {
        voteLabel.apply(style: style.voteLabel)
        typeView.titleLabel.apply(style: style.typeView)
        switch style.mode {
        case .titleType:
            content.semanticContentAttribute = .forceRightToLeft
        case .typeTitle:
            content.semanticContentAttribute = .unspecified
        }
    }
}

extension YourVoteView.Style {
    static let aye = YourVoteView.Style(
        voteLabel: .votes,
        typeView: .ayeType,
        mode: .typeTitle
    )
    static let nay = YourVoteView.Style(
        voteLabel: .votes,
        typeView: .nayType,
        mode: .typeTitle
    )
    static let abstain = YourVoteView.Style(
        voteLabel: .votes,
        typeView: .abstainType,
        mode: .typeTitle
    )
    static let ayeInverse = YourVoteView.Style(
        voteLabel: .votes,
        typeView: .ayeType,
        mode: .titleType
    )
    static let nayInverse = YourVoteView.Style(
        voteLabel: .votes,
        typeView: .nayType,
        mode: .titleType
    )
    static let abstainInverse = YourVoteView.Style(
        voteLabel: .votes,
        typeView: .abstainType,
        mode: .titleType
    )
}

extension UILabel.Style {
    static let ayeType = UILabel.Style(
        textColor: R.color.colorTextPositive(),
        font: .semiBoldCaps1
    )
    static let nayType = UILabel.Style(
        textColor: R.color.colorTextNegative(),
        font: .semiBoldCaps1
    )
    static let abstainType = UILabel.Style(
        textColor: R.color.colorChipText(),
        font: .semiBoldCaps1
    )
    static let votes = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .caption1
    )
}
