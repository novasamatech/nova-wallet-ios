import Foundation

enum DAppBrowserInteractorError: Error {
    case scriptFileMissing
    case invalidUrl
    case unexpectedMessageType
}
