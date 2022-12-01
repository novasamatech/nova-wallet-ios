import Foundation
import CommonWallet

final class WalletHistoryBackgroundView: UIView {
    let minimizedSideLength: CGFloat = 12.0

    let minimizedBackgroundView = BlockBackgroundView()
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

extension WalletHistoryBackgroundView: HistoryBackgroundViewProtocol {
    func apply(style _: HistoryViewStyleProtocol) {}

    func applyFullscreen(progress: CGFloat) {
        let sideLength = minimizedSideLength * progress

        minimizedBackgroundView.sideLength = sideLength
        minimizedBackgroundView.alpha = progress

        fullBackgroundView.sideLength = sideLength
        fullBackgroundView.alpha = (1 - progress)
    }
}
