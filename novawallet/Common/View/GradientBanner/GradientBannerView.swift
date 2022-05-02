import UIKit
import SoraUI

class GradientBannerView: UIView {
    let infoView = GradientBannerInfoView()

    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorBlack()!
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorWhite8()!
        view.cornerRadius = 12.0
        return view
    }()

    let leftGradientView: MultigradientView = {
        let view = MultigradientView()
        view.cornerRadius = 12.0
        return view
    }()

    let rightGradientView: MultigradientView = {
        let view = MultigradientView()
        view.cornerRadius = 12.0
        return view
    }()

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .leading
        view.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 0.0)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 8.0
        return view
    }()

    var contentInsets: UIEdgeInsets {
        get {
            stackView.layoutMargins
        }

        set {
            stackView.layoutMargins = newValue
            setNeedsLayout()
        }
    }

    private var linkView: LinkView?

    private var loadingView: RoundedView?

    var linkButton: RoundedButton? { linkView?.actionButton }
    private(set) var actionButton: TriangularedButton?

    var showsLink: Bool = true {
        didSet {
            if showsLink {
                setupLinkButton()
            } else {
                removeLinkButton()
            }
        }
    }

    var showsAction: Bool = false {
        didSet {
            if showsAction {
                setupActionButton()
            } else {
                removeActionButton()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        if showsLink {
            setupLinkButton()
        }

        if showsAction {
            setupActionButton()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startLoading() {
        guard showsAction else {
            return
        }

        actionButton?.isHidden = true

        setupLoadingView()
    }

    func stopLoading() {
        guard showsAction else {
            return
        }

        actionButton?.isHidden = false
        removeLoadingView()
    }

    func bind(model: GradientBannerModel) {
        bindGradients(left: model.left, right: model.right)
    }

    func bindGradients(left: GradientModel, right: GradientModel) {
        leftGradientView.colors = left.colors
        leftGradientView.locations = left.locations
        leftGradientView.startPoint = left.startPoint
        leftGradientView.endPoint = left.endPoint

        rightGradientView.colors = right.colors
        rightGradientView.locations = right.locations
        rightGradientView.startPoint = right.startPoint
        rightGradientView.endPoint = right.endPoint
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(leftGradientView)
        leftGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(rightGradientView)
        rightGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(infoView)

        let widthOffset = stackView.layoutMargins.left + stackView.layoutMargins.right
        infoView.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-widthOffset)
        }
    }

    private func setupLinkButton() {
        guard linkButton == nil else {
            return
        }

        let linkView = LinkView()
        stackView.insertArranged(view: linkView, after: infoView)

        self.linkView = linkView
    }

    private func removeLinkButton() {
        linkView?.removeFromSuperview()
        linkView = nil
    }

    private func setupActionButton() {
        guard actionButton == nil else {
            return
        }

        let actionButton = TriangularedButton()
        actionButton.applyDefaultStyle()
        actionButton.changesContentOpacityWhenHighlighted = true
        actionButton.triangularedView?.sideLength = 10.0
        actionButton.imageWithTitleView?.titleFont = .semiBoldSubheadline

        stackView.addArrangedSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-32.0)
            make.height.equalTo(44.0)
        }

        self.actionButton = actionButton
    }

    private func removeActionButton() {
        actionButton?.removeFromSuperview()
        actionButton = nil
    }

    private func setupLoadingView() {
        guard loadingView == nil else {
            return
        }

        let loadingView = RoundedView()
        loadingView.applyFilledBackgroundStyle()
        loadingView.fillColor = R.color.colorWhite8()!

        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.tintColor = R.color.colorTransparentText()
        loadingView.addSubview(activityIndicator)

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        stackView.addArrangedSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-32)
            make.height.equalTo(44.0)
        }

        self.loadingView = loadingView

        activityIndicator.startAnimating()
    }

    private func removeLoadingView() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
}
