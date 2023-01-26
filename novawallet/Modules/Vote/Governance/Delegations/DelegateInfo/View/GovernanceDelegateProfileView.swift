import UIKit

final class GovernanceDelegateProfileView: UIView {
    let nameLabel = UILabel(style: .regularSubhedlinePrimary, numberOfLines: 1)

    let avatarView: DAppIconView = .create {
        $0.contentInsets = .zero
    }

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

    private var imageViewModel: ImageViewModelProtocol?

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

        imageViewModel?.cancel(on: avatarView.imageView)

        imageViewModel = viewModel.imageViewModel

        switch viewModel.type {
        case .individual:
            avatarView.backgroundView.apply(style: .clear)

            imageViewModel?.loadImage(
                on: avatarView.imageView,
                targetSize: iconSize,
                cornerRadius: iconSize.height / 2.0,
                animated: true
            )
        case .organization:
            let iconRadius = floor(iconSize.height / 5.0)
            avatarView.backgroundView.apply(style: .roundedContainer(radius: iconRadius))

            imageViewModel?.loadImage(
                on: avatarView.imageView,
                targetSize: iconSize,
                animated: true
            )
        }
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
