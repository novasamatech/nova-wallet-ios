import UIKit
import SoraFoundation

final class CloudBackupReviewChangesViewController: UIViewController, ViewHolder {
    typealias RootViewType = CloudBackupReviewChangesViewLayout

    typealias DataSource =
        UICollectionViewDiffableDataSource<CloudBackupReviewSectionViewModel, CloudBackupReviewItemViewModel>

    let presenter: CloudBackupReviewChangesPresenterProtocol

    private lazy var dataSource = createDataSource()

    init(presenter: CloudBackupReviewChangesPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CloudBackupReviewChangesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource

        rootView.collectionView.registerCellClass(CloudBackupReviewChangesCell.self)
        rootView.collectionView.registerClass(
            RoundedIconTitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { [weak self] collectionView, indexPath, model -> UICollectionViewCell? in
                guard let self else {
                    return nil
                }

                let cell: CloudBackupReviewChangesCell? = collectionView.dequeueReusableCell(for: indexPath)

                cell?.bind(viewModel: model, locale: selectedLocale)

                return cell
            }
        )

        dataSource.supplementaryViewProvider = { [weak self] collectionView, _, indexPath in
            guard let headerModel = self?
                .dataSource
                .snapshot()
                .sectionIdentifiers[indexPath.section]
                .header else {
                return nil
            }

            let header: RoundedIconTitleCollectionHeaderView? = collectionView.dequeueReusableSupplementaryView(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                for: indexPath
            )
            header?.bind(viewModel: .init(title: headerModel.title, icon: headerModel.icon))
            header?.contentInsets = .init(top: 16, left: 0, bottom: 8, right: 0)
            return header
        }

        return dataSource
    }

    private func setupLocalization() {
        rootView.notNowButton.imageWithTitleView?.title = R.string.localizable.commonNotNow(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.applyButton.imageWithTitleView?.title = R.string.localizable.commonApply(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.header.valueTop.text = R.string.localizable.cloudBackupReviewTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.header.valueBottom.attributedText = NSAttributedString.coloredItems(
            [
                R.string.localizable.cloudBackupReviewEnsurePassphrase(
                    preferredLanguages: selectedLocale.rLanguages
                )
            ],
            formattingClosure: { items in
                R.string.localizable.cloudBackupReviewSubtitle(
                    items[0],
                    preferredLanguages: selectedLocale.rLanguages
                )
            },
            color: R.color.colorTextPrimary()!
        )
    }
}

extension CloudBackupReviewChangesViewController: CloudBackupReviewChangesViewProtocol {
    func didReceive(viewModels: [CloudBackupReviewSectionViewModel]) {
        rootView.showHeader = { section in
            viewModels[section].header != nil
        }

        dataSource.apply(viewModels)
    }
}

extension CloudBackupReviewChangesViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
