import UIKit

final class YourWalletsViewController: UIViewController {
    typealias RootViewType = YourWalletsViewLayout

    let presenter: YourWalletsPresenterProtocol

    init(presenter: YourWalletsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = YourWalletsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension YourWalletsViewController: YourWalletsViewProtocol {
    func update(viewModel _: [YourWalletsViewModel]) {}
}

// TODO: Remove
final class TestYourWalletsViewController: UITableViewController {
    let presenter: YourWalletsPresenterProtocol
    private var viewModel: [YourWalletsViewModel] = []

    init(presenter: YourWalletsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel.count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)

        let cellModel = viewModel[indexPath.row]
        switch cellModel {
        case let .common(model, _):
            cell.textLabel?.text = model.name
            cell.detailTextLabel?.text = model.address
            model.imageViewModel?.loadImage(
                on: cell.imageView!,
                targetSize: .init(width: 32, height: 32),
                animated: true
            )
        case let .notFound(model):
            cell.textLabel?.text = model.name
            cell.detailTextLabel?.text = "Account not found"
            model.imageViewModel?.loadImage(
                on: cell.imageView!,
                targetSize: .init(width: 32, height: 32),
                animated: true
            )
        }
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard case let .common(cellModel, _) = viewModel[indexPath.row] else {
            return
        }
        presenter.didSelect(viewModel: cellModel)
    }
}

extension TestYourWalletsViewController: YourWalletsViewProtocol {
    func update(viewModel: [YourWalletsViewModel]) {
        self.viewModel = viewModel
        tableView.reloadData()
    }
}
