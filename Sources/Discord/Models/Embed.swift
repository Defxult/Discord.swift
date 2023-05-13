
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

/// Represents a Discord embed.
public class Embed {

    /// Embed type.
    public private(set) var type: EmbedType = .rich

    /// Embed title.
    public private(set) var title: String?
    
    /// Embed description.
    public private(set) var description: String?
    
    /// Embed URL.
    public private(set) var url: String?
    
    /// Embed timestamp.
    public private(set) var timestamp: Date?
    
    /// Embed color.
    public private(set) var color: Color?
    
    /// Embed footer.
    public private(set) var footer: Footer?
    
    /// Embed image.
    public private(set) var image: Image?
    
    /// Embed thumbnail.
    public private(set) var thumbnail: Thumbnail?

    /// Embed video.
    public private(set) var video: Video? = nil
    
    /// Embed provider.
    public private(set) var provider: Provider? = nil
    
    /// Embed author.
    public private(set) var author: Author?
    
    /// Embed fields.
    public private(set) var fields = [Field]()
    
    /// Converts the embed into a dictionary.
    public var dict: [String: Any] { convert() }
    
    /// Creates a copy of the embed.
    public var copy: Embed {
        get {
            let embedCopy = Embed.fromDict(dict)
            embedCopy.fields = fields
            embedCopy.timestamp = timestamp
            return embedCopy
        }
    }
    
    /// Total amount of characters in the embed. The Discord limit is 6000.
    public var count: Int {
        get {
            var count = 0
            count += title?.count ?? 0
            count += description?.count ?? 0
            
            for field in fields {
                count += field.name.count
                count += field.value.count
            }

            count += footer?.text.count ?? 0
            count += author?.name.count ?? 0
            return count
        }
    }
    
    /// Whether the embed has any data that's been set.
    public var isEmpty: Bool {
        get {
            let countableValues: [Any?] = [title, description, url, timestamp, color, footer, image, thumbnail, video, provider, author]
            return countableValues.allSatisfy { $0 == nil } && fields.count == 0
        }
    }
    
    /**
     Initializes a new embed.
     
     Below is an example on how to create an embed:
     ```swift
     // Setting via embed instance.
     let discord = Embed()
        .setTitle("Discord")
        .setDescription("Imagine a place")
        .setImage(url: "https://discord.com/assets/a69bd473fc9eb435cf791b8beaf29e93.png")
     
     // Setting via parameters
     let discord = Embed(title: "Discord", description: "Imagine a place")
     ```
     */
    public init(title: String? = nil, description: String? = nil, color: Color? = nil, url: String? = nil, timestamp: Date? = nil) {
        self.title = title
        self.description = description
        self.color = color
        self.url = url
        self.timestamp = timestamp
    }

    init(embedData: JSON) {
        for (k, v) in embedData {
            switch k {
            case "type":
                type = EmbedType.getEmbedType(v as! String)
            case "title":
                title = v as? String
            case "description":
                description = v as? String
            case "url":
                url = v as? String
            case "timestamp":
                timestamp = Conversions.stringDateToDate(iso8601: v as! String)
            case "color":
                color = Color(value: v as! Int)
            case "footer":
                let footerObj = v as! JSON
                footer = Footer(footerData: footerObj)
            case "image":
                let imageObj = v as! JSON
                image = Image(imageData: imageObj)
            case "thumbnail":
                let thumbnailObj = v as! JSON
                thumbnail = Thumbnail(thumbnailData: thumbnailObj)
            case "video":
                let videoObj = v as! JSON
                video = Video(videoData: videoObj)
            case "provider":
                let providerObj = v as! JSON
                provider = Provider(providerData: providerObj)
            case "author":
                let authorObj = v as! JSON
                author = Author(authorData: authorObj)
            case "fields":
                let fieldObjs = v as! [JSON]
                for fo in fieldObjs { fields.append(Field(fieldData: fo)) }
            default:
                continue
            }
        }
    }
    
    /// Resets the embed to it's empty state.
    /// - Returns: An empty embed.
    @discardableResult
    public func clear() -> Self {
        removeUrl()
        removeTitle()
        removeImage()
        removeColor()
        removeFooter()
        removeAuthor()
        removeThumbnail()
        removeDescription()
        removeAllFields()
        return self
    }

    /// Sets the title of the embed. Up to 256 characters.
    /// - Parameter title: The title.
    /// - Returns: The embed instance.
    @discardableResult
    public func setTitle(_ title: String) -> Self {
        self.title = title
        return self
    }
    
    /// Removes the title.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeTitle() -> Self {
        title = nil
        return self
    }

    /// Sets the description of the embed. Up to 4096 characters
    /// - Parameter description: The description.
    /// - Returns: The embed instance.
    @discardableResult
    public func setDescription(_ description: String) -> Self {
        self.description = description
        return self
    }
    
    /// Removes the description.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeDescription() -> Self {
        description = nil
        return self
    }

    /// Sets the title URL of the embed.
    /// - Parameter url: The URL.
    /// - Returns: The embed instance.
    @discardableResult
    public func setUrl(_ url: String) -> Self {
        self.url = url
        return self
    }
    
    /// Removes the URL.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeUrl() -> Self {
        url = nil
        return self
    }

    /// Sets a custom time for the embed timestamp.
    /// - Parameter timestamp: The timestamp.
    /// - Returns: The embed instance.
    @discardableResult
    public func setTimestamp(_ date: Date = .now) -> Self {
        timestamp = date
        return self
    }
    
    /// Removes the timestamp.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeTimestamp() -> Self {
        timestamp = nil
        return self
    }

    /// Sets the color of the embed.
    /// - Parameter color: The color.
    /// - Returns: The embed instance.
    @discardableResult
    public func setColor(_ color: Color) -> Self {
        self.color = color
        return self
    }
    
    /// Removes the color.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeColor() -> Self {
        color = nil
        return self
    }

    /**
     Sets the footer of the embed.
     
     - Parameters:
        - text: The text on the footer. Up to 2048 characters.
        - iconUrl: The URL for the image that will be displayed in the footer. Only supports HTTP(S).
     - Returns: The embed instance.
    */
    @discardableResult
    public func setFooter(text: String, iconUrl: String? = nil) -> Self {
        footer = Footer(text: text, iconUrl: iconUrl)
        return self
    }

    /// Removes the footer.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeFooter() -> Self {
        footer = nil
        return self
    }

    /**
     Sets the image for the embed.
     
     You can use a local image in the embed by doing the following:
     ```swift
     let file = try File(name: "image.png", path: "/path/to/file/image.png")
     
     // Once you have the file, you must use the specialized attachment
     // URL in order to access the image:
     let embed = Embed()
         .setImage(url: "attachment://image.png")
     
     // Send the message and the image will be attached to the embed.
     try await channel.send(embeds: [embed], files: [file])
     ```
     
     - Parameter url: The URL for the image that will be displayed in the center. Only supports HTTP(S).
     - Returns: The embed instance.
    */
    @discardableResult
    public func setImage(url: String) -> Self {
        image = Image(url: url)
        return self
    }

    /// Removes the image.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeImage() -> Self {
        image = nil
        return self
    }

    /**
     Sets the thumbnail for the embed.
     
     You can use a local image in the embed by doing the following:
     ```swift
     let file = try File(name: "image.png", path: "/path/to/file/image.png")
     
     // Once you have the file, you must use the specialized attachment
     // URL in order to access the image:
     let embed = Embed()
         .setThumbnail(url: "attachment://image.png")
     
     // Send the message and the image will be attached to the embed.
     try await channel.send(embeds: [embed], files: [file])
     ```

     - Parameter url: The URL for the thumbnail that will be displayed in the top right corner. Only supports HTTP(S).
     - Returns: The embed instance.
    */
    @discardableResult
    public func setThumbnail(url: String) -> Self {
        thumbnail = Thumbnail(url: url)
        return self
    }

    /// Removes the thumbnail.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeThumbnail() -> Self {
        thumbnail = nil
        return self
    }

    /**
     Sets the author.
     
     - Parameters:
        - name: Name of the author. Up to 256 characters.
        - url: URL link for the author.
        - iconUrl: The URL for the image that will be displayed for the author. Only supports HTTP(S).
     - Returns: The embed instance.
    */
    @discardableResult
    public func setAuthor(name: String, url: String? = nil, iconUrl: String? = nil) -> Self {
        author = Author(name: name, url: url, iconUrl: iconUrl)
        return self
    }

    /// Removes the author.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeAuthor() -> Self {
        author = nil
        return self
    }

    /**
     Adds a field to the embed. Up to 25 fields.
     
     - Parameters:
        - name: Name of the field. Up to 256 characters.
        - value: Contents of the field. Up to 1024 characters.
        - inline: Whether or not this field should display inline.
     - Returns: The embed instance.
    */
    @discardableResult
    public func addField(name: String, value: String, inline: Bool = false) -> Self {
        fields.append(Field(name: name, value: value, inline: inline))
        return self
    }

    /// Removes a field at the specified index.
    /// - Parameter index: The index position to remove the field from.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeFieldAtIndex(_ index: Int) -> Self {
        fields.remove(at: index)
        return self
    }

    /// Removes all fields.
    /// - Returns: The embed instance.
    @discardableResult
    public func removeAllFields() -> Self {
        fields.removeAll()
        return self
    }

    /**
    Transform a dictionary into an `Embed`.

    - Parameter data: The information the embed is bound to.
    - Note: *All* keys in the dictionary should be presented as if it was pure json. For example, fields should be presented as:
    ```swift
    {
        "embeds" : [{
            "fields" : [{
                "name": "Field name",
                "value": "Field value",
                "inline": false
            }]
        }]
    }
    ```
    - Returns: An `Embed` object with it's properties set according to the data provided.
    */
    public static func fromDict(_ data: [String: Any]) -> Embed {
        return .init(embedData: data)
    }

    func convert() -> JSON {
        var payload: JSON = [:]
        
        if let title { payload["title"] = title }
        if let description { payload["description"] = description }
        if let url { payload["url"] = url }
        if let timestamp { payload["timestamp"] = ISO8601DateFormatter().string(from: timestamp) }
        if let color { payload["color"] = color.value }
        if let image { payload["image"] = ["url": image.url] }
        if let footer {
            var footerObj: JSON = ["text": footer.text]
            if let fIconUrl = footer.iconUrl { footerObj["icon_url"] = fIconUrl }
            payload["footer"] = footerObj
        }
        if let thumbnail {
            var thumbnailObj: JSON = ["url": thumbnail.url]
            if let thWidth = thumbnail.width { thumbnailObj["width"] = thWidth }
            if let thHeight = thumbnail.height { thumbnailObj["height"] = thHeight }
            payload["thumbnail"] = thumbnailObj
        }
        if let video {
            var videoObj: JSON = [:]
            if let vUrl = video.url { videoObj["url"] = vUrl }
            if let vWidth = video.width { videoObj["width"] = vWidth }
            if let vHeight = video.height { videoObj["height"] = vHeight }
            payload["video"] = videoObj
        }
        if let provider {
            var providerObj: JSON = [:]
            if let pName = provider.name { providerObj["name"] = pName }
            if let pUrl = provider.url { providerObj["url"] = pUrl }
            payload["provider"] = providerObj
        }
        if let author {
            var authorObj: JSON = ["name": author.name]
            if let aUrl = author.url { authorObj["url"] = aUrl }
            if let aIconUrl = author.iconUrl { authorObj["icon_url"] = aIconUrl }
            payload["author"] = authorObj
        }
        if fields.count > 0 {
            var fieldObjs = [JSON]()
            for f in fields {
                fieldObjs.append([
                    "name": f.name,
                    "value": f.value,
                    "inline": f.inline
                ])
            }
            payload["fields"] = fieldObjs
        }
        return payload
    }
    
    /// Converts an array of `Embed`s to an array of their json equivalent.
    static func convert(_ embeds: [Embed]) -> [JSON] {
        var embedObjects = [JSON]()
        for embed in embeds {
            embedObjects.append(embed.convert())
        }
        return embedObjects
    }
}


fileprivate protocol Imageable {
    var url: String {get}
    var height: Int? {get}
    var width: Int? {get}
}

extension Embed {

    /// Represents an embed's type.
    public enum EmbedType : String {

        /// Generic embed rendered from embed attributes.
        case rich = "rich"
        
        /// Image embed.
        case image = "image"
        
        /// Video embed.
        case video = "video"
        
        /// Animated GIF image embed rendered as a video embed.
        case gifv = "gifv"
        
        /// Article embed.
        case article = "article"
        
        /// Link embed.
        case link = "link"
        
        static func getEmbedType(_ type: String) -> EmbedType {
            // NOTE: When initially testing, I did run into a "auto_moderation_message" type. This occurs when a auto-moderation
            // message is sent. It's not officially documented (https://discord.com/developers/docs/resources/channel#embed-object-embed-types)
            // so it's better to just default as .rich
            if let match = EmbedType(rawValue: type) { return match }
            else { return .rich }
        }
    }

    /// Represents an embed footer.
    public struct Footer {
        
        /// Footer text.
        public let text: String
        
        /// URL of footer icon. Only supports HTTP(S).
        public let iconUrl: String?

        fileprivate init(text: String, iconUrl: String? = nil) {
            self.text = text
            self.iconUrl = iconUrl
        }

        init(footerData: JSON) {
            text = footerData["text"] as! String
            iconUrl = footerData["icon_url"] as? String
        }
    }

    /// Represents an embed image.
    public struct Image: Imageable {
        
        /// Source URL of image. Only supports HTTP(S).
        public let url: String
        
        /// Height of image.
        public let height: Int?
        
        /// Width of image.
        public let width: Int?

        fileprivate init(url: String, height: Int? = nil, width: Int? = nil) {
            self.url = url
            self.height = height
            self.width = width
        }
        
        init(imageData: JSON) {
            self.url = imageData["url"] as! String
            self.height = imageData["height"] as? Int
            self.width = imageData["width"] as? Int
        }
    }

    /// Represents an embed thumbnail.
    public struct Thumbnail: Imageable {

        /// Source URL of image. Only supports HTTP(S).
        public let url: String
        
        /// Height of image.
        public let height: Int?
        
        /// Width of image.
        public let width: Int?

        fileprivate init(url: String, height: Int? = nil, width: Int? = nil) {
            self.url = url
            self.height = height
            self.width = width
        }

        init(thumbnailData: JSON) {
            url = thumbnailData["url"] as! String
            height = thumbnailData["height"] as? Int
            width = thumbnailData["width"] as? Int
        }
    }

    /// Represents an embeds video information.
    public struct Video {

        /// Source URL of image. Only supports HTTP(S).
        public let url: String?
        
        /// Height of image.
        public let height: Int?
        
        /// Width of image.
        public let width: Int?

        init(videoData: JSON) {
            url = videoData["url"] as? String
            height = videoData["height"] as? Int
            width = videoData["width"] as? Int
        }
    }

    /// Represents an embeds provider information.
    public struct Provider {
        
        /// Name of provider.
        public let name: String?
        
        /// URL of provider.
        public let url: String?

        init(providerData: JSON) {
            self.name = providerData["name"] as? String
            self.url = providerData["url"] as? String
        }
    }

    /// Represents an embed author.
    public struct Author {
        
        /// Name of author.
        public let name: String
        
        /// URL of author.
        public let url: String?
        
        /// Source URL of image. Only supports HTTP(S).
        public let iconUrl: String?

        fileprivate init(name: String, url: String? = nil, iconUrl: String? = nil) {
            self.name = name
            self.url = url
            self.iconUrl = iconUrl
        }

        init(authorData: JSON) {
            self.name = authorData["name"] as! String
            self.url = authorData["url"] as? String
            self.iconUrl = authorData["icon_url"] as? String
        }
    }

    /// Represents an embed field.
    public struct Field {
        
        /// Name of the field.
        public let name: String
        
        /// Value of the field.
        public let value: String
        
        /// Whether or not this field should display inline.
        public let inline: Bool

        fileprivate init(name: String, value: String, inline: Bool = false) {
            self.name = name
            self.value = value
            self.inline = inline
        }

        init(fieldData: JSON) {
            name = fieldData["name"] as! String
            value = fieldData["value"] as! String
            inline = fieldData["inline"] as! Bool
        }
    }
}
