import SubstrateSdk
import UIKit
import UIKit_iOS

final class SubtensorValidatorSelectViewLayout: UIView {
    let searchField = UITextField()
    let tableView = UITableView(frame: .zero, style: .plain)
    let emptyLabel = UILabel()
    let actionButton = TriangularedButton()
    let bottomBar = UIView()
    let errorCard = UIStackView()
    let errorTitle = UILabel()
    let errorDetail = UILabel()
    let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupStyles()
        setupLayout()
    }

    private func setupStyles() {
        searchField.backgroundColor = R.color.colorBlockBackground()
        searchField.textColor = R.color.colorTextPrimary()
        searchField.font = .regularSubheadline
        searchField.layer.cornerRadius = 10
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        searchField.leftViewMode = .always
        searchField.returnKeyType = .search
        searchField.isHidden = true

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        emptyLabel.font = .regularFootnote
        emptyLabel.textColor = R.color.colorTextSecondary()
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        bottomBar.backgroundColor = R.color.colorSecondaryScreenBackground()
        actionButton.applyDefaultStyle()

        errorCard.axis = .vertical
        errorCard.spacing = 8
        errorCard.backgroundColor = R.color.colorWarningBlockBackground()
        errorCard.layer.cornerRadius = 12
        errorCard.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        errorCard.isLayoutMarginsRelativeArrangement = true
        errorCard.isHidden = true
        errorTitle.font = .semiBoldSubheadline
        errorTitle.textColor = R.color.colorTextPrimary()
        errorDetail.font = .regularFootnote
        errorDetail.textColor = R.color.colorTextSecondary()
        errorDetail.numberOfLines = 0
        retryButton.contentHorizontalAlignment = .left
        retryButton.titleLabel?.font = .semiBoldFootnote
        errorCard.addArrangedSubview(errorTitle)
        errorCard.addArrangedSubview(errorDetail)
        errorCard.addArrangedSubview(retryButton)
    }

    private func setupLayout() {
        addSubview(searchField)
        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(errorCard)
        addSubview(bottomBar)
        bottomBar.addSubview(actionButton)
        searchField.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchField.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
            make.leading.trailing.equalToSuperview().inset(32)
        }
        errorCard.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        bottomBar.snp.makeConstraints { make in make.leading.trailing.bottom.equalToSuperview() }
        actionButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(52)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(12)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSearchVisible(_ visible: Bool) {
        searchField.isHidden = !visible
        tableView.snp.remakeConstraints { make in
            if visible {
                make.top.equalTo(searchField.snp.bottom).offset(12)
            } else {
                make.top.equalTo(safeAreaLayoutGuide)
            }
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }
}

final class SubtensorValidatorSelectCell: UITableViewCell {
    let radio = UIImageView()
    let iconView: PolkadotIconView = .create { view in
        view.backgroundColor = .clear
        view.fillColor = .clear
    }

    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let apyLabel = UILabel()
    let infoButton = UIButton(type: .custom)
    let divider = UIView()
    var infoAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()
        titleLabel.font = .regularSubheadline
        titleLabel.textColor = R.color.colorTextPrimary()
        subtitleLabel.font = .caption1
        subtitleLabel.textColor = R.color.colorTextSecondary()
        apyLabel.font = .semiBoldFootnote
        apyLabel.textColor = R.color.colorTextPositive()
        apyLabel.textAlignment = .right
        infoButton.setImage(R.image.iconInfoFilled(), for: .normal)
        infoButton.tintColor = R.color.colorIconSecondary()
        infoButton.addTarget(self, action: #selector(showInfo), for: .touchUpInside)
        divider.backgroundColor = R.color.colorDivider()

        [radio, iconView, titleLabel, subtitleLabel, apyLabel, infoButton, divider].forEach(contentView.addSubview)
        radio.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        iconView.snp.makeConstraints { make in
            make.leading.equalTo(radio.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(apyLabel.snp.leading).offset(-8)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualTo(apyLabel.snp.leading).offset(-8)
        }
        infoButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }
        apyLabel.snp.makeConstraints { make in
            make.trailing.equalTo(infoButton.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(48)
        }
        divider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        infoAction = nil
    }

    func bind(_ model: SubtensorValidatorRowViewModel, icon: DrawableIcon?) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        apyLabel.text = model.apy ?? "—"
        radio.image = UIImage(systemName: model.isSelected ? "largecircle.fill.circle" : "circle")
        radio.tintColor = model.isSelected ? R.color.colorButtonBackgroundPrimary() : R.color.colorIconSecondary()
        if let icon { iconView.bind(icon: icon) }
    }

    @objc private func showInfo() { infoAction?() }
}

final class SubtensorValidatorSkeletonCell: UITableViewCell, SkeletonableView {
    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { contentView }
    var hidingViews: [UIView] { [] }
    var skeletonSpaceSize: CGSize { contentView.bounds.size }

    private let radio = UIImageView(image: UIImage(systemName: "circle"))
    private let info = UIImageView(image: R.image.iconInfoFilled())
    private let divider = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        radio.tintColor = R.color.colorIconSecondary()
        info.tintColor = R.color.colorIconSecondary()
        divider.backgroundColor = R.color.colorDivider()
        [radio, info, divider].forEach(contentView.addSubview)
        radio.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        info.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        divider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if skeletonView == nil {
            startLoadingIfNeeded()
        } else if skeletonView?.bounds.size != skeletonSpaceSize {
            updateLoadingState()
        }
        contentView.bringSubviewToFront(radio)
        contentView.bringSubviewToFront(info)
        contentView.bringSubviewToFront(divider)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            skeletonView?.stopSkrulling()
        } else {
            skeletonView?.restartSkrulling()
        }
    }

    func createSkeletons(for size: CGSize) -> [Skeletonable] {
        guard size.width > 0 else { return [] }
        let shapes: [(CGPoint, CGSize)] = [
            (CGPoint(x: 52, y: 17), CGSize(width: 24, height: 24)),
            (CGPoint(x: 88, y: 14), CGSize(width: 120, height: 12)),
            (CGPoint(x: 88, y: 31), CGSize(width: min(160, size.width - 168), height: 10)),
            (CGPoint(x: size.width - 92, y: 23), CGSize(width: 48, height: 12))
        ]
        return shapes.map { offset, shapeSize in
            SingleSkeleton.createRow(
                on: self,
                containerView: contentView,
                spaceSize: size,
                offset: offset,
                size: shapeSize
            )
        }
    }
}
