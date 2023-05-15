import Foundation

protocol URIScanDelegate: AnyObject {
    func uriScanDidReceive(uri: String, context: AnyObject?)
}
