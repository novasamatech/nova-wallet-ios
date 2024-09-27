import UIKit

final class VoteCardOverlayView: GenericBorderedView<UIImageView> {
    private(set) var vote: VoteResult?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    override var intrinsicContentSize: CGSize {
        switch vote {
        case .aye, .nay:
            return CGSize(width: Constants.voteOverlayAyeNaySize, height: Constants.voteOverlayAyeNaySize)
        case .abstain, .skip, nil:
            return CGSize(width: Constants.voteOverlayAbstainSize, height: Constants.voteOverlayAbstainSize)
        }
    }

    func configure() {
        backgroundView.applyFilledBackgroundStyle()
    }

    func bind(vote: VoteResult) {
        self.vote = vote

        switch vote {
        case .aye:
            contentInsets = Constants.voteOverlayAyeNayInsets
            contentView.image = R.image.iconThumbsUpFilled()
            backgroundView.fillColor = R.color.colorButtonBackgroundApprove()!
            backgroundView.cornerRadius = Constants.voteOverlayAyeNaySize / 2
        case .nay:
            contentInsets = Constants.voteOverlayAyeNayInsets
            contentView.image = R.image.iconThumbsDownFilled()
            backgroundView.fillColor = R.color.colorButtonBackgroundReject()!
            backgroundView.cornerRadius = Constants.voteOverlayAyeNaySize / 2
        case .abstain:
            contentInsets = Constants.voteOverlayAbstainInsets
            backgroundView.fillColor = R.color.colorButtonBackgroundSecondary()!
            contentView.image = R.image.iconAbstain()
            backgroundView.cornerRadius = Constants.voteOverlayAbstainSize / 2
        case .skip:
            contentView.image = nil
            backgroundView.fillColor = .clear
        }

        invalidateIntrinsicContentSize()

        setNeedsLayout()
    }
}

extension VoteCardOverlayView {
    enum Constants {
        static let voteOverlayAbstainSize: CGFloat = 56
        static let voteOverlayAyeNaySize: CGFloat = 64
        static let voteOverlayAbstainInsets = UIEdgeInsets(inset: 16)
        static let voteOverlayAyeNayInsets = UIEdgeInsets(inset: 20)
    }
}
