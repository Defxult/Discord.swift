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
public struct Asset : Downloadable, Hashable {

    /// The hash value of the asset.
    public let hash: String

    /// The direct URL of the asset.
    public let url: String

    // ---- API Separate ----
 
    /// Whether the asset is animated.
    public let animated: Bool
    
    // ----------------------
    
    public static func == (lhs: Asset, rhs: Asset) -> Bool { lhs.url == rhs.url }
    public func hash(into hasher: inout Hasher) { hasher.combine(url) }

    init(hash: String, fullURL: String) {
        self.hash = hash
        animated = hash.starts(with: "a_")
        if fullURL.starts(with: "/") {
            url = APIRoute.cdn.rawValue + fullURL
        } else {
            fatalError("Path must start with /")
        }
    }
    
    static func imageType(hash: String) -> String {
        hash.starts(with: "a_") ? hash + ".gif" : hash + ".png"
    }
}

/// Represents an object that has a URL where its contents can be converted into a ``File``.
public protocol Downloadable {
    
    /// The URL of the object.
    var url: String { get }
}

extension Downloadable {
    
    /// Converts the contents of the objects URL into a ``File``. For successful conversion, the URL of the downloadable
    /// must match the specifications of parameter `urls` in ``File/download(urls:)``.
    /// - Returns: The file representation of the URL, or `nil` if the conversion failed.
    public func download() async throws -> File? {
        try await File.download(urls: [URL(string: url)!]).first
    }
}
