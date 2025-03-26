import Foundation

struct DAppTransportModel {
    let name: String
    let handlerNames: Set<String>
    let scripts: [DAppBrowserScript]
}
