import XCTest
import Foundation
@testable import Discord

class MyListener : EventListener {
    override func onReady() async {
        print("READY")
    }
    
    override func onRawMessageReactionRemove(payload: (userId: Snowflake, channelId: Snowflake, messageId: Snowflake, emoji: PartialEmoji, guildId: Snowflake?)) async {
        print(payload.emoji)
    }
    
    override func onMessageCreate(message: Message) async {
        guard !message.author.isBot else { return }
        
        let sps = message.bot!.getGuild(305912183189929984)!
        let main = message.bot!.getGuild(587937522043060224)!
        
        let __main__test1 = 702791440429875350
        let discordSwiftTest1 = 1070009070813200455
        
        // MARK: Discord.swift testing
        if message.channel.id == discordSwiftTest1 {
            let guild = message.guild!
            let bot = message.bot!
            
            // DISCONNECT
            if message.content == "dc" { bot.disconnect(); print("Disconnected") }
            guard !message.author.isBot else { return }
            
            // CODE HERE
            try! await bot.updatePresence(status: .dnd, activity: nil)
            print("Updated")
        }
        
        // MARK: __main__ testing
//        if message.channel.id == __main__test1 {
//            let guild = message.guild!
//            let bot = message.bot!
//
//            // CODE HERE
//            do {
//                try await message.channel.send("Hello")
//            } catch HTTPError.forbidden(let message) {
//                print(message)
//            } catch {
//                // ...
//            }
//        }
    }
}

final class DiscordTests: XCTestCase {
    func testExample() async throws {
        
        let bot = Discord(token: getVariable("TOKEN")!, intents: Intents.default, ignoreDms: true)
        
        try! bot.addListeners(MyListener(name: "example.listener"))
        
//        bot.addUserCommand(
//            name: "Who is",
//            guildId: 587937522043060224,
//            onInteraction: { interaction async in
//                // Convert the data to its proper type
//                let data  = interaction.data as! ApplicationCommandData
//                
//                // You can get the member the invoking user clicked on via targetId
//                let member = interaction.guild!.getMember(data.targetId!)
//                
//                try! await interaction.respondWithMessage("...")
//            }
//        )
//        
//        bot.addMessageCommand(
//            name: "Example",
//            guildId: 123456789012345678,
//            onInteraction: { interaction async in
//                // Convert the data to its proper type
//                let data = interaction.data as! ApplicationCommandData
//                
//                // You can get the message the invoking user clicked on via `.message`
//                let message = data.message
//                
//                try! await interaction.respondWithMessage("...")
//            }
//        )
        
//        bot.addSlashCommand(
//            name: "example",
//            description: "Example description",
//            guildId: 1068105613323804733,
//            onInteraction: { inter async in
//                let x = try! await inter.guild!.applicationCommands().first!
//                try! await inter.respondWithMessage(x.mention!)
//            }
//        )
        
        //try! await bot.syncApplicationCommands()
      
        try! await bot.connect()
    }
}




//// MARK: Future LIVE slash commands
//func registerAppCommands(_ bot: Discord) {
//    // Tags
//    bot.addSlashCommand(
//        name: "tag",
//        description: "desc",
//        guildId: 587937522043060224,
//        onInteraction: { inter async in
//            let data = inter.data as! ApplicationCommandData
//
//            if let create = data.options?.first(where: { $0.name == "create" }) {
//                try! await inter.respondWithModal(
//                    Modal(title: "Tag Creator", customId: "tagCreator",
//                          inputs: [
//                            .init(label: "Tag name", style: .short, customId: "tagName", minLength: 3, maxLength: 30, placeholder: "Can't contain spaces or underscores. Example: my-tag"),
//                            .init(label: "Tag contents", style: .paragraph, customId: "tagContents", minLength: 5, maxLength: 2000)
//                          ],
//                          onSubmit: { inter async in
//                              let data = inter.data as! ModalSubmitData
//                              let result = data.results.first(where: { $0.inputId == "tagName" })!
//                              try! await inter.respondWithMessage(embeds: [Embed(description: "<:miscVoteYES:687491186667028513> Tag `\(result.value)` created", color: .green)])
//                          })
//                )
//            }
//        },
//        options: [
//            .init(
//                .subCommand,
//                name: "create",
//                description: "Create a tag",
//                required: true
//            ),
//            .init(
//                .subCommand,
//                name: "get",
//                description: "Get a tag",
//                required: true,
//                options: [
//                    .init(.string, name: "name", description: "Tag name", required: true)
//                ]
//            ),
//            .init(
//                .subCommand,
//                name: "edit",
//                description: "Edit a tag you own",
//                required: true,
//                options: [
//                    .init(.string, name: "name", description: "Tag name", required: true)
//                ]
//            ),
//            .init(
//                .subCommand,
//                name: "delete",
//                description: "Delete a tag you own",
//                required: true,
//                options: [
//                    .init(.string, name: "name", description: "Tag name", required: true)
//                ]
//            )
//        ]
//    )
//}

// MARK: Rules

//let txt = """
//    **1 - ** Always follow Discord [community guidelines](https://discord.com/guidelines) and [terms of service](https://discord.com/terms).
//
//    **2 - ** Be respectful to everyone.
//
//    **3 - ** Do not spam.
//
//    **4 - ** Do not post NSFW content whatsoever. This includes links, avatars, images, videos, etc.
//
//    **5 - ** Do not use slurs of any kind.
//
//    **6 - ** Bot commands should stay in <#1082143562457690122> or in either help channels.
//
//    **7 - ** Use the proper channels. Memes go in <#1082145719072342046>, etc.
//
//    Last updated \(formatTimestamp(date: .now))
//    """
//
//let embed = Embed()
//    .setTitle("Server Rules")
//    .setColor(.skyBlue)
//    .setDescription(txt)
//    .setThumbnail(url: bot.user!.avatar!.url)
//
//let channel = bot.getChannel(1068105736166572063) as! TextChannel
//let msg = try! await channel.requestMessage(1110430361642602576)
//try! await msg.edit(.content(""))
//try! await msg.edit(.embeds([embed]))
//print("DONE")


// MARK: Markdown escape testing
//try! await message.channel.send(
//    Markdown.escape("""
//        > quote
//        - bullet point
//        # header
//        `inline code`
//        \(url)
//        ```swift
//        code block
//        ```
//        **bold**
//        *italics*
//        https://github.com/Defxult/Discord.swift/releases/tag/0.0.3-alpha
//        :cool:
//        ~~strikethrough~~
//        __underlinie__
//        ||spoiler||
//        @everyone
//        https://discord.com/channels/1068105613323804733/1070009070813200455/1115638594120450139
//        @here
//        <:swiftLogo:1110792949098360872>
//        <#1070009070813200455>
//        <@&1110782045162057749>
//        """,
//        ignoreUrls: true
//    ),
//    allowedMentions: .all
//)
