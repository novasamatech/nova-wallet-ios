import UIKit

final class WalletHistoryBackgroundView: UIView {
    let minimizedSideLength: CGFloat = 12.0

    let minimizedBackgroundView: OverlayBlurBackgroundView = .create { view in
        view.borderType = .none
        view.overlayView.strokeColor = R.color.colorCardActionsBorder()!
        view.overlayView.strokeWidth = 1
    }

    let fullBackgroundView: BlurBackgroundView = .create {
        $0.borderType = []
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

    private func setupLayout() {
        addSubview(minimizedBackgroundView)

        minimizedBackgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(fullBackgroundView)

        fullBackgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension WalletHistoryBackgroundView {
    func applyFullscreen(progress: CGFloat) {
        let sideLength = minimizedSideLength * (1 - progress)

        minimizedBackgroundView.sideLength = sideLength
        minimizedBackgroundView.alpha = 1 - progress

        fullBackgroundView.sideLength = sideLength
        fullBackgroundView.alpha = progress
    }
}
