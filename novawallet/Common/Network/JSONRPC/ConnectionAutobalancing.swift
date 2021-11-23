import Foundation

protocol ConnectionAutobalancing {
    var urls: [URL] { get }

    func changeUrls(_ newUrls: [URL])
}
