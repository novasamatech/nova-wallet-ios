import SoraUI
import SnapKit

protocol CollapsableNetworkInfoViewDelegate: AnyObject {
    func animateAlongsideWithInfo(sender: AnyObject?)
    func didChangeExpansion(isExpanded: Bool, sender: AnyObject)
}

class CollapsableContainerView: UIView {
    private enum Constants {
        static let headerHeight: CGFloat = 32
        static let rowHeight: CGFloat = 44
        static let contentMargins = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        static let stackViewBottomInset: CGFloat = 4
    }

    let backgroundView = BlockBackgroundView()

    let networkInfoContainer: UIView = .create {
        $0.backgroundColor = .clear
        $0.clipsToBounds = true
    }

    let contentView: UIView = .create {
        $0.backgroundColor = .clear
    }

    let titleControl: ActionTitleControl = .create {
        $0.indicator = ResizableImageActionIndicator(size: .init(width: 24, height: 24))
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: R.color.colorTextSecondary()!)
        $0.identityIconAngle = CGFloat.pi / 2.0
        $0.activationIconAngle = -CGFloat.pi / 2.0
        $0.titleLabel.apply(style: .footnoteSecondary)
        $0.titleLabel.textAlignment = .left
        $0.titleLabel.numberOfLines = 1
        $0.layoutType = .flexible
        $0.horizontalSpacing = 0
        $0.imageView.isUserInteractionEnabled = false
        $0.activate(animated: false)
    }

    let stackView: UIStackView = .create {
        $0.axis = .vertical
        $0.distribution = .fill
        $0.alignment = .fill
        $0.spacing = 0.0
        $0.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        $0.isLayoutMarginsRelativeArrangement = true
    }

    weak var delegate: CollapsableNetworkInfoViewDelegate?

    lazy var expansionAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    var expanded: Bool { titleControl.isActivated }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setExpanded(_ value: Bool, animated: Bool) {
        guard value != expanded else {
            return
        }

        if value {
            titleControl.activate(animated: animated)
        } else {
            titleControl.deactivate(animated: animated)
        }

        applyExpansion(animated: animated)
    }

    private func setupHandlers() {
        titleControl.addTarget(self, action: #selector(actionToggleExpansion), for: .valueChanged)
    }

    var rows: [UIView] {
        []
    }

    private func setupLayout() {
        addSubview(backgroundView)

        addSubview(titleControl)
        titleControl.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.headerHeight)
        }

        addSubview(networkInfoContainer)
        networkInfoContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleControl.snp.bottom)
        }

        networkInfoContainer.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(networkInfoContainer.snp.edges)
        }

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(Constants.stackViewBottomInset)
        }

        rows.forEach { view in
            stackView.addArrangedSubview(view)

            view.translatesAutoresizingMaskIntoConstraints = false
            view.snp.makeConstraints { make in
                make.height.equalTo(Constants.rowHeight)
            }
        }
    }

    private func applyExpansion(animated: Bool) {
        if animated {
            expansionAnimator.animate(block: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.applyExpansionState()

                let animation = CABasicAnimation()
                animation.toValue = strongSelf.backgroundView.contentView?.shapePath
                strongSelf.backgroundView.contentView?.layer
                    .add(animation, forKey: #keyPath(CAShapeLayer.path))

                strongSelf.delegate?.animateAlongsideWithInfo(sender: strongSelf)
            }, completionBlock: nil)
        } else {
            applyExpansionState()
            setNeedsLayout()
        }
    }

    private func applyExpansionState() {
        if expanded {
            contentView.snp.updateConstraints { make in
                make.top.equalToSuperview()
            }

            networkInfoContainer.alpha = 1.0
            delegate?.didChangeExpansion(isExpanded: true, sender: self)
        } else {
            contentView.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(
                    -CGFloat(stackView.arrangedSubviews.count) * Constants.rowHeight - Constants.stackViewBottomInset
                )
            }

            networkInfoContainer.alpha = 0.0
            delegate?.didChangeExpansion(isExpanded: false, sender: self)
        }
    }

    @objc func actionToggleExpansion() {
        applyExpansion(animated: true)
    }
}
