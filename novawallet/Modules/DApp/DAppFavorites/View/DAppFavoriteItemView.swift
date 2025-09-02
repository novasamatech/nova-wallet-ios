import UIKit
import UIKit_iOS

protocol DAppFavoriteItemViewDelegate: AnyObject {
    func didTapFavoriteButton(_ itemId: String)
}

final class DAppFavoriteItemView: UIView {
    weak var delegate: DAppFavoriteItemViewDelegate?

    let favoriteButton: UIButton = .create { view in
        view.setImage(
            R.image.iconFavButtonSel(),
            for: .normal
        )
    }

    private let dAppItemView: DAppItemView = .create { view in
        view.layoutStyle = .horizontal
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupAction()
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
                .spacer(length: 24),
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

    func setupAction() {
        favoriteButton.addTarget(
            self,
            action: #selector(actionRemoveFavorite),
            for: .touchUpInside
        )
    }

    @objc func actionRemoveFavorite() {
        guard let model = dAppItemView.model else { return }

        delegate?.didTapFavoriteButton(model.identifier)
    }
}

// MARK: Internal

extension DAppFavoriteItemView {
    func bind(viewModel: DAppViewModel) {
        dAppItemView.bind(viewModel: viewModel)
    }
}
