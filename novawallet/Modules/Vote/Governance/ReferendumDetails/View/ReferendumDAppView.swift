import UIKit

final class ReferendumDAppView: UIView {
    let iconImageView: DAppIconView = .create {
        $0.contentInsets = Constants.iconInsets
        $0.backgroundView.cornerRadius = 12
        $0.backgroundView.apply(style: .container)
    }

    let titleView = MultiValueView()
    let arrowView = UIImageView(image: R.image.iconChevronRight())
    private var model: Model?

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
            alignment: .center,
            spacing: Constants.horizontalSpace,
            [
                iconImageView,
                titleView,
                UIView(),
                arrowView
            ]
        )

        arrowView.snp.makeConstraints {
            $0.width.height.equalTo(Constants.arrowSize)
        }

        iconImageView.snp.makeConstraints {
            $0.width.height.equalTo(Constants.iconWidth)
        }

        titleView.stackView.alignment = .leading

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

// MARK: - Model

extension ReferendumDAppView {
    struct Model {
        let icon: ImageViewModelProtocol?
        let title: String
        let subtitle: String
    }

    func bind(viewModel: Model) {
        model?.icon?.cancel(on: iconImageView.imageView)
        iconImageView.imageView.image = nil

        model = viewModel

        titleView.valueTop.text = viewModel.title
        titleView.valueBottom.text = viewModel.subtitle

        viewModel.icon?.loadImage(
            on: iconImageView.imageView,
            targetSize: .init(width: Constants.iconWidth, height: Constants.iconWidth),
            animated: true
        )
    }

    func clear() {
        model?.icon?.cancel(on: iconImageView.imageView)
    }
}

// MARK: - Constants

extension ReferendumDAppView {
    enum Constants {
        static let arrowSize = CGSize(width: 16, height: 16)
        static let horizontalSpace: CGFloat = 12
        static let iconWidth: CGFloat = 48
        static let iconInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
    }
}
