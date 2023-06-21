/**
The MIT License (MIT)

Copyright (c) 2023-present Defxult

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

import Foundation

/// Represents a Discord CDN.
public struct Asset {

    /// The hash value of the asset.
    public let hash: String

    /// The direct URL of the asset.
    public let url: String

    // ---- API Separate ----
 
    /// Whether the asset is animated.
    public let animated: Bool
    
    // ----------------------

    static func imageType(hash: String) -> String {
        hash.starts(with: "a_") ? hash + ".gif" : hash + ".png"
    }

    init(hash: String, fullURL: String) {
        self.hash = hash
        animated = hash.starts(with: "a_")
        if fullURL.starts(with: "/") {
            url = APIRoute.cdn.rawValue + fullURL
        } else {
            fatalError("Path must start with /")
        }
    }
    
    /// Converts the contents of the asset to a ``File``.
    /// - Returns: The file representation of the asset.
    public func download() async throws -> File {
        try await File.download(urls: [URL(string: url)!]).first!
    }
}
