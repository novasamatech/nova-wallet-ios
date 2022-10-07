import UIKit

final class ReferendumView: UIView {
    let referendumInfoView = ReferendumInfoView()
    let progressView = VotingProgressView()
    let yourVoteView = YourVoteView()

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
            spacing: 0,
            [
                referendumInfoView,
                progressView,
                yourVoteView
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

typealias ReferendumTableViewCell = BlurredTableViewCell<ReferendumView>

extension ReferendumTableViewCell {
    func applyStyle() {
        contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        innerInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
    }
}
