import WebKit

extension WKWebView {
    static var desktopWidth: CGFloat { 1100 }
    static var deskstopUserAgent: String {
        // swiftlint:disable:next line_length
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.1 Safari/537.36"
    }

    func viewportScript(for width: CGFloat? = nil, targetWidthInPixels: CGFloat) -> String {
        let scale = UIScreen.main.scale
        let width = width ?? bounds.width
        let viewPortScale = width / scale / targetWidthInPixels

        return createViewportScript(from: targetWidthInPixels, scale: viewPortScale)
    }

    private func createViewportScript(from width: CGFloat, scale: CGFloat) -> String {
        // swiftlint:disable line_length
        """
        document.querySelector('meta[name="viewport"]').setAttribute("content", "width=\(width)px initial-scale=\(scale)");
        """
        // swiftlint:enable line_length
    }
}
