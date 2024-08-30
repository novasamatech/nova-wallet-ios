import UIKit
import SoraUI
import SnapKit

final class RoundedGradientBackgroundView: RoundedView {
    let leftGradientView = MultigradientView()
    let rightGradientView = MultigradientView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        backgroundColor = .clear
    }

    override var cornerRadius: CGFloat {
        didSet {
            super.cornerRadius = cornerRadius

            leftGradientView.cornerRadius = cornerRadius
            rightGradientView.cornerRadius = cornerRadius
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: GradientBannerModel) {
        leftGradientView.colors = model.left.colors
        leftGradientView.locations = model.left.locations
        leftGradientView.startPoint = model.left.startPoint
        leftGradientView.endPoint = model.left.endPoint

        rightGradientView.colors = model.right.colors
        rightGradientView.locations = model.right.locations
        rightGradientView.startPoint = model.right.startPoint
        rightGradientView.endPoint = model.right.endPoint
    }

    private func setupLayout() {
        addSubview(leftGradientView)
        leftGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(rightGradientView)
        rightGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
