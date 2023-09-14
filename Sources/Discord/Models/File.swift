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
import Vapor

/// Represents a file to upload to Discord.
public struct File {
    
    /// The absolute path of the file.
    public let path: String
    
    /// Name of the file including its extension.
    public let name: String
    
    /// Data representaion of the file.
    public let data: Data
    
    /// Whether the file is blurred as a spoiler.
    public let spoiler: Bool

    let mimetype: String
    var asImageData: String { "data:\(mimetype);base64,\(data.base64EncodedString())" }
    
    /// Initializes a new a file using the direct patch of an existing file.
    /// - Parameters:
    ///   - name: Name of the file **to include** its file extension.
    ///   - path: The *absolute path* of the file from which to read.
    ///   - spoiler: Whether the file is blurred as a spoiler.
    public init(name: String, path: String, spoiler: Bool = false) throws {
        self.name = File.setSpoiler(name: name, spoiler: spoiler)
        self.path = path
        self.spoiler = spoiler
        if let nsData = NSData(contentsOfFile: path) {
            data = Data(base64Encoded: nsData.base64EncodedData())!
            mimetype = MimeType(path: path).value
        }
        else {
            throw FileError.notFound("File '\(path)' could not be found with the provided path")
        }
    }
    
    /// Create a file by using its name and data.
    /// - Parameters:
    ///   - name: Name of the file **to include** its file extension.
    ///   - using: The files data.
    ///   - spoiler: Whether the file is blurred as a spoiler.
    /// - Note: The file extension should match the data being used. For example, if the data you're *using* is a text file, the *name* should be "Example.txt".
    public init(name: String, using: Data, spoiler: Bool = false) {
        path = .empty
        self.name = File.setSpoiler(name: name, spoiler: spoiler)
        data = using
        self.spoiler = spoiler
        mimetype = MimeType(path: name).value
    }
    
    /// Convert the URLs into files.
    /// - Parameter urls: URLs to extract the data from. These must have a path extension (.png, .gif, .mp3, etc). If a URL does not have a path extension it is ignored.
    /// - Returns: The files that were converted from the given URLs.
    public static func download(urls: [URL]) async throws -> [File] {
        // Extract the URLs that contain a path extension because the extension is needed for `File.init()`
        let urlsWithExt = urls.filter({ $0.pathExtension != .empty })
        
        return try await withThrowingTaskGroup(of: File.self, body: { group -> [File] in
            var files = [File]()
            let app = Vapor.Application()
            
            // Vapor complains if the `Application` isn't
            // shutdown before it's deinitialized
            defer { app.shutdown() }
            
            for (n, url) in urlsWithExt.enumerated() {
                group.addTask {
                    let resp = try await app.client.get(URI(string: url.absoluteString))
                    let data = Data(buffer: resp.body!)
                    return File(name: "file_\(n).\(url.pathExtension)", using: data)
                }
            }
            
            for try await value in group {
                files.append(value)
            }
            
            return files
        })
    }
    
    private static func setSpoiler(name: String, spoiler: Bool) -> String {
        spoiler ? "SPOILER_\(name)" : name
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
