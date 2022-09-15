//
//  WebUtils.swift
//  BeamAIBrowser
//

import Foundation

extension URL {
    static func httpURL(withString string: String) -> URL? {
        let urlString: String
        if (string.starts(with: "http://") || string.starts(with: "https://")) { urlString = string }
        else { urlString = "http://" + string }
        return URL(string: urlString)
    }
}
