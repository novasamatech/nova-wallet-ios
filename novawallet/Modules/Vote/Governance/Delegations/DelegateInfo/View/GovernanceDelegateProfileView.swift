import UIKit

final class GovernanceDelegateProfileView: UIView {
    let nameLabel = UILabel(style: .regularSubhedlinePrimary, numberOfLines: 1)

    let avatarView = BorderedImageView()

    var locale: Locale {
        get {
            typeView.locale
        }

        set {
            typeView.locale = newValue
        }
    }

    let typeView = GovernanceDelegateTypeView()

    let iconSize: CGSize

    init(size: CGSize) {
        iconSize = size

        super.init(frame: CGRect(origin: .zero, size: size))

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: GovernanceDelegateProfileView.Model) {
        nameLabel.text = viewModel.name
        typeView.bind(type: viewModel.type)

        avatarView.bind(
            viewModel: viewModel.imageViewModel,
            targetSize: iconSize,
            delegateType: viewModel.type
        )
    }

    private func setupLayout() {
        let contentView = UIView.vStack(spacing: 16, [
            .hStack(alignment: .center, spacing: 12, [
                avatarView,
                .vStack(spacing: 0, [
                    UIView(),
                    .vStack(spacing: 4, [
                        nameLabel,
                        .hStack([
                            typeView,
                            UIView()
                        ])
                    ]),
                    UIView()
                ])
            ])
        ])

        addSubview(contentView)

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarView.snp.makeConstraints { make in
            make.size.equalTo(iconSize)
        }
    }
}

extension GovernanceDelegateProfileView {
    struct Model {
        let name: String
        let type: GovernanceDelegateTypeView.Model
        let imageViewModel: ImageViewModelProtocol?
    }
}
