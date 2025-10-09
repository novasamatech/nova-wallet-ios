import Foundation
import UIKit
import UIKit_iOS

final class StackIconChainCell: RowView<UIView>, StackTableViewCellProtocol {
    let chainView = AssetListChainView()

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 22.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        rowContentView.addSubview(chainView)
        chainView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview()
            make.height.equalTo(24.0)
        }

        borderView.strokeWidth = 0.0

        isUserInteractionEnabled = false
    }
}
