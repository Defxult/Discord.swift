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

/// Represents a color on Discord.
public struct Color : Hashable {

    private static let maximumColorValue = 16_777_215
    
    /// Returns a `Color` with its value set to `0x5865f2`.
    public static let blurple = Color(value: 0x5865f2)
    
    /// Returns a `Color` with its value set to `0xeb459e`.
    public static let fuchsia = Color(value: 0xeb459e)
    
    /// Returns a `Color` with its value set to `0xfc0303`.
    public static let red = Color(value: 0xfc0303)
    
    /// Returns a `Color` with its value set to `0xff992b`.
    public static let orange = Color(value: 0xff992b)
    
    /// Returns a `Color` with its value set to `0xffdc2b`.
    public static let yellow = Color(value: 0xffdc2b)
    
    /// Returns a `Color` with its value set to `0x2bff32`.
    public static let green = Color(value: 0x2bff32)
    
    /// Returns a `Color` with its value set to `0x026105`.
    public static let darkGreen = Color(value: 0x026105)
    
    /// Returns a `Color` with its value set to `0x36b1d6`.
    public static let skyBlue = Color(value: 0x36b1d6)
    
    /// Returns a `Color` with its value set to `0x1021e3`.
    public static let darkBlue = Color(value: 0x1021e3)
    
    /// Returns a `Color` with its value set to `0x8f44f2`.
    public static let purple = Color(value: 0x8f44f2)
    
    /// Returns a `Color` with its value set to `0xfca7f0`.
    public static let pink = Color(value: 0xfca7f0)
    
    /// Returns a `Color` with its value set to `0x000001`.
    public static let black = Color(value: 0x000001)
    
    /// Returns a `Color` with its value set to `0xffffff`.
    public static let white = Color(value: 0xffffff)
    
    /// Returns a `Color` with its value set to `0xa6a6a6`.
    public static let gray = Color(value: 0xa6a6a6)
    
    /// Returns a `Color` with its value set to `0x2f3136`.
    public static let darkTheme = Color(value: 0x2f3136)
    
    /// Returns a `Color` with its value set to `0x008080`.
    public static let teal = Color(value: 0x008080)
    
    /// Returns a random `Color`.
    public static var random: Color { Color(value: .random(in: 0...Color.maximumColorValue)) }

    /// Returns the individual RGB values of the color separated into a tuple.
    public var asRgb: (r: Int, g: Int, b: Int) {
        let r = (value >> (8 * 2)) & 0xff
        let g = (value >> (8 * 1)) & 0xff
        let b = (value >> (8 * 0)) & 0xff
        return (r, g, b)
    }
    
    /**
     Returns a color in its hex form.
     
     ```swift
     let yellow = Color(r: 216, g: 237, b: 55)
     print(yellow.asHex)
     // Prints "d8ed37"
     ```
     */
    public var asHex: String { String(value, radix: 16) }
    
    /// The color value.
    public var value: Int { didSet { value = Color.verifyValue(value) } }
    
    // Hashable
    public static func == (lhs: Color, rhs: Color) -> Bool { lhs.value == rhs.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(value) }

    /// Initializes a new color.
    /// - Parameter value: A color value.
    public init(value: Int) {
        self.value = Color.verifyValue(value)
    }
    
    /// Initializes a new color using RGB values.
    /// - Parameters:
    ///   - r: Red component of the color (0-255).
    ///   - g: Green component of the color (0-255).
    ///   - b: Blue component of the color (0-255).
    public init(r: Int, g: Int, b: Int) {
        let convertedRGB = ((r&0x0ff) << 16) | ((g&0x0ff) << 8 ) | (b&0x0ff)
        value = Color.verifyValue(convertedRGB)
    }
    
    /// Initializes a new color using a hexadecimal value.
    /// - Parameter hex: The hexadecimal value.
    public init(hex: String) {
        var convertedValue = 0
        
        // Convert the hex string to its `Int` representation
        let toInt = { (value: String) -> Int in
            Int(value, radix: 16) ?? 0
        }
        
        // I've seen hex values be represented in 3 ways:
        // 1 - as the standard: 0xd8ed37
        // 2 - with a hashtag: #d8ed37
        // 3 - or just itself: d8ed37
        if hex.lowercased().starts(with: "0x") { convertedValue = toInt(hex.dropFirst(2).description) }
        else if hex.starts(with: "#") { convertedValue = toInt(hex.dropFirst().description) }
        else { convertedValue = toInt(hex) }
        
        value = Color.verifyValue(convertedValue)
    }
    
    // If the HTTP POST request color value is < 0 or > `.maximumColorValue`
    // an HTTP bad request error occurs (invalid form body). This method simply
    // verifies/corrects the value so that doesn't occur.
    private static func verifyValue(_ value: Int) -> Int {
        value < 0 ? 0 : min(value, maximumColorValue)
    }

    static func getPayloadColor(value: Int?) -> Color? {
        if let value { return Color(value: value) }
        else { return nil }
    }
}
