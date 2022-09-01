import UIKit
import SubstrateSdk

final class SelectableIconSubtitleView: UIView {
    let iconSubtitleView = IconDetailsGenericView<GenericMultiValueView<PolkadotIconDetailsView>>()
    let radioSelectorView = RadioSelectorView()

    private var viewModel: ViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(iconSubtitleView)
        addSubview(radioSelectorView)

        iconSubtitleView.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        radioSelectorView.snp.makeConstraints {
            $0.leading.equalTo(iconSubtitleView.snp.trailing).offset(Constants.horizontalSpace)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview()
            $0.width.equalTo(Constants.radioButtonSize.width)
            $0.height.equalTo(Constants.radioButtonSize.height)
        }

        iconSubtitleView.spacing = Constants.iconSpace
        iconSubtitleView.iconWidth = Constants.iconSize.width
        iconSubtitleView.detailsView.stackView.alignment = .leading
    }
}

// MARK: - Model

extension SelectableIconSubtitleView {
    struct ViewModel {
        let icon: ImageViewModelProtocol?
        let title: String
        let subtitle: String
        let subtitleIcon: DrawableIconViewModel?
        let lineBreakMode: NSLineBreakMode

        let isSelected: Bool?
    }

    func bind(viewModel: ViewModel) {
        self.viewModel?.icon?.cancel(on: iconSubtitleView.imageView)
        iconSubtitleView.imageView.image = nil

        self.viewModel = viewModel

        iconSubtitleView.detailsView.valueTop.text = viewModel.title
        iconSubtitleView.detailsView.valueBottom.titleLabel.text = viewModel.subtitle
        iconSubtitleView.detailsView.valueBottom.titleLabel.lineBreakMode = viewModel.lineBreakMode

        viewModel.icon?.loadImage(
            on: iconSubtitleView.imageView,
            targetSize: Constants.iconSize,
            animated: true
        )

        viewModel.subtitleIcon.map {
            iconSubtitleView.detailsView.valueBottom.imageView.fillColor = $0.fillColor
            iconSubtitleView.detailsView.valueBottom.imageView.bind(icon: $0.icon)
        }

        guard let isSelected = viewModel.isSelected else {
            radioSelectorView.isHidden = true
            return
        }

        radioSelectorView.isHidden = false
        radioSelectorView.selected = isSelected
    }

    func clear() {
        viewModel?.icon?.cancel(on: iconSubtitleView.imageView)
    }
}

// MARK: - Constants

extension SelectableIconSubtitleView {
    enum Constants {
        static let horizontalSpace: CGFloat = 25
        static let radioButtonSize = CGSize(width: 20, height: 20)
        static let iconSize = CGSize(width: 32, height: 32)
        static let iconSpace: CGFloat = 12
    }
}
