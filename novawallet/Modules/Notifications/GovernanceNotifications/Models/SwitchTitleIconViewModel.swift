struct SwitchTitleIconViewModel {
    let title: String
    let icon: ImageViewModelProtocol?
    var isOn: Bool
    let action: (Bool) -> Void
}
