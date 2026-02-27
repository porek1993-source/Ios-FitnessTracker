// YouTubeLinkGenerator.swift
// Generátor dynamických YouTube odkazů na základě názvu cviku.

import Foundation

enum YouTubeLinkGenerator {

    /// Vygeneruje URL pro vyhledávání správné techniky cviku na YouTube.
    /// Preferuje `nameEn` (lepší výsledky), ale umí fallback na `nameCz`.
    static func searchURL(nameEn: String?, nameCz: String) -> URL {
        let searchTerm = nameEn ?? nameCz
        let query = "how+to+do+\(searchTerm)+proper+form"
            .replacingOccurrences(of: " ", with: "+")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm

        return URL(string: "https://www.youtube.com/results?search_query=\(query)")
            ?? URL(string: "https://www.youtube.com") ?? URL(fileURLWithPath: "/")
    }
}
