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

public enum DiscordError : Error {
    case generic(_ message: String)
}

public enum FileError : Error {
    case notFound(_ message: String)
    case downloadFailed(_ message: String)
}

public enum HTTPError : Error {
    
    ///
    case badRequest(_ message: String) // 400
    
    ///
    case unauthorized(_ message: String) // 401
    
    /// You don't have the proper permissions.
    case forbidden(_ message: String) // 403
    
    ///
    case notFound(_ message: String) // 404
    
    ///
    case methodNotAllowed(_ message: String) // 405
    
    /// Something went wrong.
    case base(_ message: String) // 5XX
}

public enum GatewayError : Error {
    case unknownError(_ message: String)
    case unknownOpcode(_ message: String)
    case decodeError(_ message: String)
    case notAuthenticated(_ message: String)
    case authenticationFailed(_ message: String)
    case alreadyAuthenticated(_ message: String)
    case invalidSeq(_ message: String)
    case rateLimited(_ message: String)
    case sessionTimedOut(_ message: String)
    case invalidShard(_ message: String)
    case shardingRequired(_ message: String)
    case invalidApiVersion(_ message: String)
    case invalidIntents(_ message: String)
    case disallowedIntents(_ message: String)
}

// Interaction Errors
public enum UIError : Error {
    
    /// Occurs when there are too many components attached to a message.
    case invalidUI(_ message: String)
    
    /// Occurs when a `Button` doesn't have the proper values set.
    case invalidButton(_ message: String)
    
    /// Occurs when an interaction message
    case noResponse(_ message: String)
}
