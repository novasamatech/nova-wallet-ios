import Foundation

struct SubtensorValidatorCardViewModel {
    let icon: ImageViewModelProtocol?
    let name: String?
    let subtitle: String
    let rate: SubtensorRowState<String>
    let rateCaption: String
    var isActive: Bool?
}
