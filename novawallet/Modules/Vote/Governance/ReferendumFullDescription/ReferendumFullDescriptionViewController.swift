import UIKit

final class ReferendumFullDescriptionViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumFullDescriptionViewLayout

    let presenter: ReferendumFullDescriptionPresenterProtocol

    init(presenter: ReferendumFullDescriptionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumFullDescriptionViewLayout()
    }

    // swiftlint:disable line_length
    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        guard let markdownText = try? createMarkdownTextSample() else {
            return
        }
        didRecieve(
            title: "Polkadot and Kusama participation in the 10th Pais Digital Chile Summit.",
            description: markdownText
        )
    }

    private func createMarkdownTextSample() throws -> String {
        let url = Bundle.main.url(forResource: "test", withExtension: "md")!
        let data = try Data(contentsOf: url)
        return String(data: data, encoding: .utf8)!
    }
}

extension ReferendumFullDescriptionViewController: ReferendumFullDescriptionViewProtocol {
    func didRecieve(title: String, description: String) {
        rootView.set(title: title)
        rootView.set(markdownText: description)
    }
}
