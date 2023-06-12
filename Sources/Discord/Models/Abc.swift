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

typealias JSON = [String: Any]

/// Represents a Discord ID.
public typealias Snowflake = UInt

/// Discord's Unix timestamp, the first second of 2015.
public let discordEpoch: Snowflake = 1420070400000

protocol Updateable {
    func update(_ data: JSON)
}

/// Represents a base Discord object.
public protocol Object {
    
    /// The ID of the object.
    var id: Snowflake { get }
}

extension Object {
    
    /// The creation date converted from the objects snowflake.
    public var created: Date { snowflakeDate(id) }
}
