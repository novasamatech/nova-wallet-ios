import UIKit

final class MarkdownDescriptionViewController: UIViewController, ViewHolder {
    typealias RootViewType = MarkdownDescriptionViewLayout

    let presenter: MarkdownDescriptionPresenterProtocol

    init(presenter: MarkdownDescriptionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MarkdownDescriptionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.markdownView.delegate = self
    }
}

extension MarkdownDescriptionViewController: MarkdownDescriptionViewProtocol {
    func didReceive(model: MarkdownDescriptionModel) {
        title = model.title

        rootView.set(title: model.header)
        rootView.set(markdownText: model.details)
    }
}

extension MarkdownDescriptionViewController: MarkdownViewContainerDelegate {
    func markdownView(_: MarkdownViewContainer, asksHandle url: URL) {
        presenter.open(url: url)
    }
}
