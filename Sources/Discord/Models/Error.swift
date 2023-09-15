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

/// Represents an error typically thrown by the library itself and usually isn't the result of an API error.
public enum DiscordError : Error {
    
    /// A generic error. Usually thrown when the library requires something that was not provided.
    case generic(_ message: String)
}

/// Represents an error releated to a ``File``.
public enum FileError : Error {
    
    /// The file was not found.
    case notFound(_ message: String)
}

/// Represnts an error that occured when attempting to interact with the Discord API.
public enum HTTPError : Error {
    
    /// The request was improperly formatted or the server did not understand it (error code 400).
    case badRequest(_ message: String)
    
    /// The bots authorization was not valid (error code 401).
    case unauthorized(_ message: String)
    
    /// You don't have the proper permissions (error code 403).
    case forbidden(_ message: String)
    
    /// The resource for the endpoint doesn't exist (error code 404).
    case notFound(_ message: String)
    
    /// The HTTP method used is not valid for the endpoint (error code 405).
    case methodNotAllowed(_ message: String)
    
    /// There was not a gateway available to process the request. Wait a bit and retry (error code 502).
    case gatewayUnavailable(_ message: String)
    
    /// Something went wrong (error code 5xx).
    case base(_ message: String)
}

/// Represents a Discord gateway error.
public enum GatewayError : Error {
    
    /// Something went wrong.
    case unknownError(_ message: String)
    
    /// An invalid opcode was sent.
    case unknownOpcode(_ message: String)
    
    /// An invalid payload was sent.
    case decodeError(_ message: String)
    
    /// A payload was sent prior to identifying.
    case notAuthenticated(_ message: String)
    
    /// The token sent with the identify payload was incorrect.
    case authenticationFailed(_ message: String)
    
    /// More than one identify payload was sent.
    case alreadyAuthenticated(_ message: String)
    
    /// The sequence sent when resuming the session was invalid.
    case invalidSequence(_ message: String)
    
    /// Too many payloads are being sent.
    case rateLimited(_ message: String)
    
    /// The session has timed out.
    case sessionTimedOut(_ message: String)
    
    /// An invalid shard was sent when identifying
    case invalidShard(_ message: String)
    
    /// Sharding your connection is required in order to connect.
    case shardingRequired(_ message: String)
    
    /// An invalid version of the gateway was sent.
    case invalidApiVersion(_ message: String)
    
    /// Invalid intents were sent.
    case invalidIntents(_ message: String)
    
    /// A disallowed intent was sent. An intent may have been specified that you have
    /// not enabled or are not approved for. Verify your privileged intents are enabled in your developer portal.
    case disallowedIntents(_ message: String)
}

/// Represents an error related to message components.
public enum UIError : Error {
    
    /// Occurs when there are too many components attached to a message.
    case invalidUI(_ message: String)
    
    /// Occurs when a ``Button`` doesn't have the proper values set.
    case invalidButton(_ message: String)
    
    /// Occurs when an interaction was never responded to.
    case noResponse(_ message: String)
}
