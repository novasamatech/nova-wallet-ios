import Foundation

struct PayCardModel {
    let resource: PayCardResource
    let messageNames: Set<String>
    let scripts: [DAppBrowserScript]
}
