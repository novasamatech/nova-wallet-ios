import Foundation

struct PayCardModel {
    let resource: PayCardHtmlResource
    let messageNames: Set<String>
    let scripts: [DAppBrowserScript]
}
