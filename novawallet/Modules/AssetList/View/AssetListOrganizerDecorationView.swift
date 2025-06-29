import UIKit
import SnapKit

final class AssetListOrganizerDecorationView: UICollectionReusableView {
    let backgroundView = BlockBackgroundView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupStyle() {
        backgroundView.sideLength = 12
        backgroundView.cornerCut = .allCorners
    }
}
