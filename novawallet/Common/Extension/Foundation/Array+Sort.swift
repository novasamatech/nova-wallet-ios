import Foundation

extension Array where Element == String {
    func sortedLexicographically() -> Self {
        sorted { (str1, str2) -> Bool in
            let utfView1 = [String.UTF16View.Element](str1.utf16)
            let utfView2 = [String.UTF16View.Element](str2.utf16)

            for index in 0 ..< Swift.max(utfView1.count, utfView2.count) {
                if let char1 = utfView1[safe: index], let char2 = utfView2[safe: index] {
                    if char1 != char2 {
                        return char1 < char2
                    }
                } else {
                    return utfView1[safe: index] == nil
                }
            }
            return true
        }
    }
}
