import UIKit

final class YourVotesView: UIView {
    let topLine = createSeparator(color: R.color.colorWhite8())
    let ayeView = YourVoteView()
    let nayView = YourVoteView()

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
                nayView
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension YourVotesView {
    struct Model {
        let aye: YourVoteView.Model?
        let nay: YourVoteView.Model?
    }

    func bind(viewModel: Model) {
        ayeView.isHidden = viewModel.aye == nil
        ayeView.bind(viewModel: viewModel.aye)
        nayView.isHidden = viewModel.nay == nil
        nayView.bind(viewModel: viewModel.nay)
    }
}

final class YourVoteView: UIView {
    let typeView: BorderedLabelView = .create {
        $0.titleLabel.apply(style: .type)
        $0.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
    }

    let voteLabel = UILabel(style: .votes, textAlignment: .left)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.hStack(
            spacing: 6,
            [
                typeView,
                voteLabel
            ]
        )

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
    }

    func bind(viewModel: Model?) {
        typeView.titleLabel.text = viewModel?.title
        voteLabel.text = viewModel?.description
    }
}

extension UILabel.Style {
    static let type = UILabel.Style(
        textColor: R.color.colorDarkGreen(),
        font: .semiBoldCaps1
    )
    static let votes = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
}
