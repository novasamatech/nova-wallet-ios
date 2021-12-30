import UIKit

final class DAppListErrorView: UICollectionViewCell {
    static let preferredHeight: CGFloat = 200.0

    let listBackgroundView = TriangularedBlurView()
    let errorView = ErrorStateView()

    var selectedLocale: Locale {
        get {
            errorView.locale
        }

        set {
            errorView.locale = newValue
        }
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

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        layoutAttributes.frame.size = CGSize(width: layoutAttributes.frame.width, height: Self.preferredHeight)
        return layoutAttributes
    }

    private func setupLayout() {
        contentView.addSubview(listBackgroundView)
        listBackgroundView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        contentView.addSubview(errorView)
        errorView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(16.0)
            make.leading.trailing.equalTo(listBackgroundView)
        }
    }
}
