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

/// Represents a sticker.
public struct Sticker : Object {

    /// ID of the sticker.
    public let id: Snowflake
    
    /// For standard stickers, ID of the pack the sticker is from.
    public let packId: Snowflake?
    
    /// Name of the sticker.
    public let name: String
    
    /// Description of the sticker.
    public let description: String?
    
    /// Type of sticker format.
    public let format: Format

    init(stickerData: JSON) {
        id = Conversions.snowflakeToUInt(stickerData["id"])
        packId = Conversions.snowflakeToOptionalUInt(stickerData["pack_id"])
        name = stickerData["name"] as! String
        description = stickerData["description"] as? String
        format = Format(rawValue: stickerData["format_type"] as! Int)!
    }
}

/// Represents a guild sticker.
public struct GuildSticker : Object, Hashable {

    /// ID of the guild sticker.
    public let id: Snowflake
    
    /// Name of the guild sticker.
    public let name: String
    
    /// Description of the guild sticker.
    public let description: String?
    
    /// The **name** of the unicode emoji.
    public let emoji: String
    
    /// Type of sticker format.
    public let format: Sticker.Format
    
    /// Whether this guild sticker can be used, may be false due to loss of server boosts.
    public let isAvailable: Bool
    
    /// The guild this sticker belongs to.
    public var guild: Guild { bot!.getGuild(guildId)! }
    private let guildId: Snowflake
    
    /// The user that uploaded the guild sticker.
    public let user: User?
    
    // Hashable
    public static func == (lhs: GuildSticker, rhs: GuildSticker) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    /// Your bot instance.
    public private(set) weak var bot: Bot?

    init(bot: Bot, guildStickerData: JSON) {
        self.bot = bot
        id = Conversions.snowflakeToUInt(guildStickerData["id"])
        name = guildStickerData["name"] as! String
        description = guildStickerData["description"] as? String
        emoji = guildStickerData["tags"] as! String
        format = Sticker.Format(rawValue: guildStickerData["format_type"] as! Int)!
        
        // Discord says this is optional, so there's a chance it might not be there. But I can't find any
        // circumstances as to why it wouldn't be present, so a forced cast will do for now.
        isAvailable = guildStickerData["available"] as! Bool
        
        guildId = Conversions.snowflakeToUInt(guildStickerData["guild_id"])
        
        if let userObj = guildStickerData["user"] as? JSON { user = User(userData: userObj) }
        else { user = nil }
    }
    
    /// Edit the guild sticker.
    /// - Parameters:
    ///   - edits: The enum containing all values to be updated or removed for the guild sticker.
    ///   - reason: The reason for editing the guild sticker. This shows up in the guilds audit log.
    /// - Returns: The updated guild sticker.
    @discardableResult
    public func edit(_ edits: Edit..., reason: String? = nil) async throws -> GuildSticker {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }
        
        var payload: JSON = [:]
        for e in edits {
            switch e {
            case .name(let name):
                payload["name"] = name
            case .description(let description):
                payload["description"] = nullable(description)
            case .emoji(let emoij):
                payload["tags"] = emoij
            }
        }
        return try await bot!.http.modifyGuildSticker(guildId: guildId, stickerId: id, data: payload, reason: reason)
    }
    
    /// Delete the guild sticker.
    /// - Parameter reason: The reason for deleting the guild sticker.
    public func delete(reason: String? = nil) async throws {
        try await bot!.http.deleteGuildSticker(guildId: guildId, stickerId: id, reason: reason)
    }
}

extension GuildSticker {
    
    /// Represents the values that can be edited in a ``GuildSticker``.
    public enum Edit {
        
        /// Name of the sticker.
        case name(String)
        
        /// Description of the sticker. Can be set to `nil` to remove the description.
        case description(String?)
        
        /// The **name** of a unicode emoji. You can typically find the name of a unicode emoji by typing a colon in the discord app. For example, the 🍕 emoji's name would be "pizza".
        case emoji(String)
    }
}

extension Sticker {

    /// Represents a stickers format.
    public enum Format : Int {
        
        /// A sticker with a file format of png.
        case png = 1
        
        /// A sticker with a file format of apng.
        case apng
        
        /// A sticker with a file format of lottie.
        case lottie
    }

    /// Represents a sticker sent with a message.
    public struct Item {
        
        /// ID of the sticker.
        public let id: Snowflake

        /// Name of the sticker.
        public let name: String
        
        /// Type of sticker format
        public let format: Format
        
        /// URL for the sticker.
        public let url: String

        init(itemData: JSON) {
            id = Conversions.snowflakeToUInt(itemData["id"])
            name = itemData["name"] as! String
            format = Format(rawValue: itemData["format_type"] as! Int)!
            url = APIRoute.cdn.rawValue + "/stickers/\(id).png"
        }
    }

    /// Represents a pack of standard stickers.
    public struct Pack {
        
        /// ID of the sticker pack.
        public let id: Snowflake
        
        /// The stickers in the pack.
        public let stickers: [Sticker]
        
        /// Name of the sticker pack
        public let name: String
        
        /// ID of the pack's SKU.
        public let skuId: Snowflake
        
        /// ID of a sticker in the pack which is shown as the pack's icon
        public let coverStickerId: Snowflake?
        
        /// Description of the sticker pack.
        public let description: String
        
        /// ID of the sticker pack's banner image.
        public let bannerAssetId: Snowflake?

        init(packData: JSON) {
            id = Conversions.snowflakeToUInt(packData["id"])
            stickers = (packData["stickers"] as! [JSON]).map({ .init(stickerData: $0) })
            name = packData["name"] as! String
            skuId = Conversions.snowflakeToUInt(packData["sku_id"])
            coverStickerId = Conversions.snowflakeToOptionalUInt(packData["cover_sticker_id"])
            description = packData["description"] as! String
            bannerAssetId = Conversions.snowflakeToOptionalUInt(packData["banner_asset_id"])
        }
    }
}
