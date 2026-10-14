import Foundation

struct SubtensorValidatorCardViewModel {
    let icon: ImageViewModelProtocol?
    let name: String?
    let subtitle: String
    let rate: SubtensorPortfolioLoadable<String>
    let rateCaption: String
}
