import WebKit

extension WKWebView {
    static var desktopWidth: CGFloat { 1100 }
    
    func viewportScript(for width: CGFloat?, targetWidthInPixels: CGFloat) -> String {
        let scale = UIScreen.main.scale
        let width = width ?? bounds.width
        let viewPortScale = width / scale / targetWidthInPixels
        let javaScript = """
        document.querySelector('meta[name="viewport"]').setAttribute("content", "width=\(targetWidthInPixels)px initial-scale=\(viewPortScale)");
        """
        return javaScript
    }
}
