import UIKit
import Foundation_iOS

final class SubtensorWhereToStakeViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorWhereToStakeViewLayout
    let presenter: SubtensorWhereToStakePresenterProtocol
    private var page = 0
    private var lastWidth: CGFloat = 0

    init(presenter: SubtensorWhereToStakePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SubtensorWhereToStakeViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.carousel.delegate = self
        rootView.previousButton.addAction(UIAction { [weak self] _ in
            self?.presenter.movePage(by: -1)
        }, for: .touchUpInside)
        rootView.nextButton.addAction(UIAction { [weak self] _ in
            self?.presenter.movePage(by: 1)
        }, for: .touchUpInside)
        presenter.setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if lastWidth != rootView.carousel.bounds.width {
            lastWidth = rootView.carousel.bounds.width
            rootView.carousel.setContentOffset(CGPoint(x: CGFloat(page) * rootView.stride, y: 0), animated: false)
        }
    }
}

extension SubtensorWhereToStakeViewController: SubtensorWhereToStakeViewProtocol {
    func didReceive(cards: [SubtensorWhereToStakeCardModel], title: String, caption: String) {
        self.title = title
        rootView.captionLabel.text = caption
        rootView.bind(cards: cards) { [weak self] in self?.presenter.choose($0) }
    }

    func didReceive(page: Int, hasPrevious: Bool, hasNext: Bool) {
        self.page = page
        rootView.pageControl.currentPage = page
        rootView.previousButton.isEnabled = hasPrevious
        rootView.nextButton.isEnabled = hasNext
        rootView.previousButton.alpha = hasPrevious ? 1 : 0.4
        rootView.nextButton.alpha = hasNext ? 1 : 0.4
        rootView.carousel.setContentOffset(CGPoint(x: CGFloat(page) * rootView.stride, y: 0), animated: true)
    }
}

extension SubtensorWhereToStakeViewController: UIScrollViewDelegate {
    func scrollViewWillEndDragging(
        _: UIScrollView,
        withVelocity _: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let page = Int((targetContentOffset.pointee.x / rootView.stride).rounded())
        targetContentOffset.pointee.x = CGFloat(min(max(page, 0), max(rootView.cards.count - 1, 0))) * rootView.stride
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        presenter.selectPage(Int((scrollView.contentOffset.x / rootView.stride).rounded()))
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { presenter.selectPage(Int((scrollView.contentOffset.x / rootView.stride).rounded())) }
    }
}

extension SubtensorWhereToStakeViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }
        presenter.setup()
    }
}
