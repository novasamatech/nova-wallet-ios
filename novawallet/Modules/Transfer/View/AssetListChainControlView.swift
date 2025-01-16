import UIKit
import UIKit_iOS

final class AssetListChainControlView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.apply(style: .roundedChips(radius: 7))
    }

    let iconView = UIImageView()

    let actionControl: ActionTitleControl = .create { view in
        let color = R.color.colorButtonTextAccent()!
        view.imageView.image = R.image.iconLinkChevron()?.tinted(with: color)
        view.identityIconAngle = CGFloat.pi / 2.0
        view.activationIconAngle = -CGFloat.pi / 2.0
        view.titleLabel.textColor = color
        view.titleLabel.font = .semiBoldCaps1
        view.horizontalSpacing = 2.0
        view.imageView.isUserInteractionEnabled = false
    }

    let iconSize = CGSize(width: 24.0, height: 24.0)

    private var iconViewModel: ImageViewModelProtocol?

    convenience init() {
        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 48.0, height: 24.0))
        self.init(frame: defaultFrame)
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

    func bind(viewModel: NetworkViewModel) {
        actionControl.titleLabel.text = viewModel.name.uppercased()

        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel.icon
        viewModel.icon?.loadImage(on: iconView, targetSize: iconSize, animated: true)

        actionControl.invalidateLayout()
        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(iconView)
        addSubview(actionControl)

        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.size.equalTo(24.0)
        }

        actionControl.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8.0)
            make.trailing.equalToSuperview().inset(8.0)
            make.top.bottom.equalToSuperview()
        }

        backgroundView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(1.0)
            make.trailing.equalToSuperview()
        }
    }
}
