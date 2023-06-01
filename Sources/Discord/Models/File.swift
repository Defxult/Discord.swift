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

/// Represents a file to upload to Discord.
public struct File {
    
    /// The absolute path of the file.
    public let path: String
    
    /// Name of the file including it's extension.
    public let name: String
    
    /// Data representaion of the file.
    public let data: Data

    let mimetype: String
    var asImageData: String { "data:\(mimetype);base64,\(data.base64EncodedString())" }
    
    /// Initializes a new a file using the direct patch of an existing file.
    /// - Parameters:
    ///   - name: The name of the file **to include** it's file extension.
    ///   - path: The *absolute path* of the file from which to read.
    public init(name: String, path: String) throws {
        self.name = name
        self.path = path
        if let nsData = NSData(contentsOfFile: path) {
            data = Data(base64Encoded: nsData.base64EncodedData())!
            mimetype = MimeType(path: path).value
        }
        else {
            throw FileError.notFound("File '\(path)' could not be found with the provided path")
        }
    }
    
    /// Create a file by using it's name and data.
    /// - Parameters:
    ///   - name: Name of the file **to include** it's file extension.
    ///   - using: The files data.
    /// - Note: The file extension should match the data being used. For example, if the data you're *using* is a text file, the *name* should be "Example.txt".
    public init(name: String, using: Data) {
        path = .empty
        self.name = name
        data = using
        mimetype = MimeType(path: name).value
    }
    
    /// Convert the URLs into files.
    /// - Parameter urls: The URLs to extract the data from. These must have a path extension (.png, .gif, .mp3, etc). If a URL does not have a path extension it is ignored.
    /// - Returns: The files that were converted from the given URLs.
    public static func download(urls: [URL]) async throws -> [File] {
        // Extract the URLs that contain a path extension because the extension is needed for `File.init()`
        let urlsWithExt = urls.filter({ $0.pathExtension != .empty })
        
        return try await withThrowingTaskGroup(of: File.self, body: { group -> [File] in
            var files = [File]()
            for (n, url) in urlsWithExt.enumerated() {
                group.addTask {
                    let data = try await URLSession.shared.data(for: URLRequest(url: url)).0
                    return File(name: "file_\(n).\(url.pathExtension)", using: data)
                }
            }
            
            for try await value in group {
                files.append(value)
            }
            
            return files
        })
    }
}
