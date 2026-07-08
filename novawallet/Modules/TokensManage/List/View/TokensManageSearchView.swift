import UIKit
import UIKit_iOS

class TokensManageSearchView: TopCustomSearchView {
    let zeroBalanceFilterView: GenericPairValueView<UILabel, UISwitch> = .create { view in
        view.makeHorizontal()
        view.stackView.alignment = .center

        view.fView.apply(style: .footnoteSecondary)
        view.sView.onTintColor = R.color.colorIconAccent()
    }

    let dustFilterView: GenericPairValueView<UILabel, UISwitch> = .create { view in
        view.makeHorizontal()
        view.stackView.alignment = .center

        view.fView.apply(style: .footnoteSecondary)
        view.sView.onTintColor = R.color.colorIconAccent()
    }

    let dustThresholdControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.insertSegment(withTitle: "< $1", at: 0, animated: false)
        control.insertSegment(withTitle: "< $5", at: 1, animated: false)
        control.insertSegment(withTitle: "< $10", at: 2, animated: false)
        control.insertSegment(withTitle: "< $50", at: 3, animated: false)
        control.selectedSegmentIndex = 0
        return control
    }()

    private let dustContainerView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()

    /// Main vertical stack that holds all controls below the safe area.
    /// UIStackView automatically collapses hidden arranged subviews,
    /// so the layout grows/shrinks naturally like Android's LinearLayout.
    let controlsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .fill
        return stack
    }()

    var zeroBalanceFilterLabel: UILabel {
        zeroBalanceFilterView.fView
    }

    var zeroBalanceFilterSwitch: UISwitch {
        zeroBalanceFilterView.sView
    }

    var dustFilterLabel: UILabel {
        dustFilterView.fView
    }

    var dustFilterSwitch: UISwitch {
        dustFilterView.sView
    }

    var dustContainerVisible: Bool {
        !dustContainerView.isHidden
    }

    override func setupLayout() {
        addSubview(blurBackgroundView)

        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Search bar has a fixed height
        searchBar.snp.makeConstraints { make in
            make.height.equalTo(36.0)
        }

        // Zero-balance filter row has a fixed height
        zeroBalanceFilterView.snp.makeConstraints { make in
            make.height.equalTo(36)
        }

        // Dust sub-controls
        dustFilterView.snp.makeConstraints { make in
            make.height.equalTo(36)
        }

        dustThresholdControl.snp.makeConstraints { make in
            make.height.equalTo(28)
        }

        dustContainerView.addArrangedSubview(dustFilterView)
        dustContainerView.addArrangedSubview(dustThresholdControl)

        // Build the main vertical stack: search bar, zero-balance toggle, dust container
        controlsStackView.addArrangedSubview(searchBar)
        controlsStackView.addArrangedSubview(zeroBalanceFilterView)
        controlsStackView.addArrangedSubview(dustContainerView)

        addSubview(controlsStackView)
        controlsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(4)
        }

        // Initially hide dust filter controls
        dustContainerView.isHidden = true
        dustThresholdControl.isHidden = true
    }

    func setDustFilterVisible(_ visible: Bool) {
        dustContainerView.isHidden = !visible

        if !visible {
            dustThresholdControl.isHidden = true
        }
    }

    func setDustThresholdVisible(_ visible: Bool) {
        dustThresholdControl.isHidden = !visible
    }
}
