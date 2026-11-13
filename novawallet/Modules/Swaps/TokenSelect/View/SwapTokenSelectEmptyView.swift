import UIKit

final class SwapTokenSelectEmptyView: UIView {
    let imageView: UIImageView = .create { view in
        view.image = R.image.iconEmptyList()
        view.contentMode = .center
    }

    let detailsLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension SwapTokenSelectEmptyView {
    func setupLayout() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(Constants.imageSize)
        }

        addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(Constants.labelTopOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// MARK: Constants

private extension SwapTokenSelectEmptyView {
    enum Constants {
        static let imageSize: CGFloat = 96
        static let labelTopOffset: CGFloat = 1
    }
}
