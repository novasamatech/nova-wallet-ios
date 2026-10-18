import Foundation

struct StartStakingViewModel {
    let title: AccentTextModel
    let caption: String?
    let paragraphs: [ParagraphView.Model]
    let wikiUrl: StartStakingUrlModel
    let termsUrl: StartStakingUrlModel
}

struct StartStakingUrlModel {
    let text: String
    let url: URL
    let urlName: String
}
