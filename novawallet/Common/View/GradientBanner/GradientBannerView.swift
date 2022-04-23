import UIKit
import SoraUI

class GradientBannerView: UIView {
    let infoView = GradientBannerInfoView()

    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorBlack()!
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorWhite8()!
        view.cornerRadius = 12.0
        return view
    }()

    let leftGradientView: MultigradientView = {
        let view = MultigradientView()
        view.cornerRadius = 12.0
        return view
    }()

    let rightGradientView: MultigradientView = {
        let view = MultigradientView()
        view.cornerRadius = 12.0
        return view
    }()

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .leading
        view.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 0.0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindGradients(left: GradientModel, right: GradientModel) {
        leftGradientView.colors = left.colors
        leftGradientView.locations = left.locations
        leftGradientView.startPoint = left.startPoint
        leftGradientView.endPoint = left.endPoint

        rightGradientView.colors = right.colors
        rightGradientView.locations = right.locations
        rightGradientView.startPoint = right.startPoint
        rightGradientView.endPoint = right.endPoint
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(leftGradientView)
        leftGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(rightGradientView)
        rightGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(infoView)

        let widthOffset = stackView.layoutMargins.left + stackView.layoutMargins.right
        infoView.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-widthOffset)
        }
    }
}
