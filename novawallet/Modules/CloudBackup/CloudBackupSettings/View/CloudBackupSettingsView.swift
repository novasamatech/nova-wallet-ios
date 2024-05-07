import Foundation
import SoraUI

final class CloudBackupSettingsView: StackTableView {}

final class CloudBackupActionCell: RowView<
    GenericTitleValueView<GenericPairValueView<CloudBackupActionStateView, MultiValueView>, UIImage>
> {
    
}

final class CloudBackupActionStateView: UIView {
    enum State {
        case disabled
        case unsynced
        case syncing
        case synced
    }
    
    let backgroundView: RoundedView = .create { view in
        view.cornerRadius = 20
    }
    
    let iconView = UIImageView()
    
    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.color = R.color.colorIndicatorShimmering()!
        view.hidesWhenStopped = true
    }
    
    override var intrinsicContentSize: CGSize {
        let cornerRadius = backgroundView.cornerRadius
        
        return CGSize(width: 2 * cornerRadius, height: 2 * cornerRadius)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupLayout()
    }
    
    func bind(state: State) {}
    
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
