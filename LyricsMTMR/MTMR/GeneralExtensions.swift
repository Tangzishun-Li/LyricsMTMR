import Foundation

extension String {
    var ifNotEmpty: String? {
        return count > 0 ? self : nil
    }
}

func localized(_ zh: String, _ en: String) -> String {
    AppSettings.appLanguage == .chinese ? zh : en
}
