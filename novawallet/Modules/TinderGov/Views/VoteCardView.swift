import SnapKit
import UIKit
import SoraUI

typealias ReportEvidenceAction = () -> Void
typealias SkipEvidenceAction = () -> Void

struct VoteCardModel {
    let viewModel: VoteCardView.ViewModel
}

final class VoteCardView: RoundedView {
    struct ViewModel {
        let title: String
    }

    private enum Constants {
        static let topAnimationInset: CGFloat = -500
        static let bottomAnimationInset: CGFloat = -400
        static let hideInstructionsBottomInset: CGFloat = 36
        static let titleAndMediaSpacing: CGFloat = -24
        static let videoCountdownBottomInset: CGFloat = 16
        static let overlayAnimationDuration: TimeInterval = 0.3
    }

    private let gradientView: RoundedGradientBackgroundView = .create { view in
        view.applyCellBackgroundStyle()
        view.bind(model: .tinderGovCell())
    }

    private let title: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.textAlignment = .left
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var cornerRadius: CGFloat {
        didSet {
            super.cornerRadius = cornerRadius
            gradientView.cornerRadius = cornerRadius
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func bind(viewModel: ViewModel) {
        title.text = viewModel.title
    }
}

extension VoteCardView: CardStackable {
    func didBecomeTopView() {}

    func prepareForReuse() {
        title.text = nil
    }
}

private extension VoteCardView {
    func setupLayout() {
        addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(title)
        title.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(16)
        }
    }
}

enum VoteResult {
    case aye
    case nay
    case abstain
}

extension VoteResult {
    var dismissalDirection: CardsZStack.DismissalDirection {
        switch self {
        case .aye:
            .right
        case .nay:
            .left
        case .abstain:
            .top
        }
    }
}
