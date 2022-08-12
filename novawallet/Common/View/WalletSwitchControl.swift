import Foundation
import UIKit
import SoraUI

final class WalletSwitchContentView: UIView {
    let typeImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    let iconView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(typeImageView)
        typeImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(24.0)
        }

        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(iconView.snp.height)
        }
    }
}

final class WalletSwitchControl: ControlView<RoundedView, WalletSwitchContentView> {
    private var iconViewModel: ImageViewModelProtocol?

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 80.0, height: 40.0)))
    }

    var typeImageView: UIImageView { controlContentView.typeImageView }

    var iconView: UIImageView { controlContentView.iconView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    func bind(viewModel: WalletSwitchViewModel) {
        iconViewModel?.cancel(on: iconView)

        iconViewModel = viewModel.iconViewModel

        if let iconViewModel = viewModel.iconViewModel {
            let height = preferredHeight ?? frame.height
            let targetSize = CGSize(width: height, height: height)
            iconViewModel.loadImage(on: iconView, targetSize: targetSize, animated: true)
        }

        switch viewModel.type {
        case .secrets:
            controlBackgroundView.fillColor = .clear
            controlBackgroundView.highlightedFillColor = .clear
            controlBackgroundView.strokeColor = .clear
            controlBackgroundView.highlightedStrokeColor = .clear

            typeImageView.image = nil
        case .watchOnly:
            controlBackgroundView.fillColor = R.color.colorWhite16()!
            controlBackgroundView.highlightedFillColor = R.color.colorWhite16()!
            controlBackgroundView.strokeColor = R.color.colorWhite8()!
            controlBackgroundView.highlightedStrokeColor = R.color.colorWhite8()!

            typeImageView.image = R.image.iconWatchOnly()
        case .paritySigner:
            controlBackgroundView.fillColor = R.color.colorWhite16()!
            controlBackgroundView.highlightedFillColor = R.color.colorWhite16()!
            controlBackgroundView.strokeColor = R.color.colorWhite8()!
            controlBackgroundView.highlightedStrokeColor = R.color.colorWhite8()!

            typeImageView.image = R.image.iconParitySigner()
        }
    }

    private func configure() {
        backgroundColor = .clear
        preferredHeight = 40.0
        contentInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 0.0)

        controlBackgroundView.applyFilledBackgroundStyle()
        controlBackgroundView.fillColor = .clear
        controlBackgroundView.highlightedFillColor = .clear
        controlBackgroundView.strokeColor = .clear
        controlBackgroundView.highlightedStrokeColor = .clear
        controlBackgroundView.strokeWidth = 1.0

        controlBackgroundView.cornerRadius = (preferredHeight ?? 0) / 2.0

        changesContentOpacityWhenHighlighted = true
    }
}
