import UIKit
import SoraUI

final class DAppFavoriteItemView: UIView {
    private let dAppItemView: DAppItemView = .create { view in
        view.layoutStyle = .horizontal
    }

    let favoriteButton: UIButton = .create { view in
        view.setImage(
            R.image.iconFavButtonSel(),
            for: .normal
        )
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

private extension DAppFavoriteItemView {
    func setupLayout() {
        let content = UIStackView.hStack(
            alignment: .center,
            [
                dAppItemView,
                .spacer(),
                favoriteButton
            ]
        )

        addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        favoriteButton.snp.makeConstraints { make in
            make.size.equalTo(20)
        }
    }
}

// MARK: Internal

extension DAppFavoriteItemView {
    func bind(viewModel: DAppViewModel) {
        dAppItemView.bind(viewModel: viewModel)
    }
}
