<p align="center">
    <img src="https://cdn.discordapp.com/attachments/655186216060321816/1121466989190324296/icon_3.png" width="230" height="230">
    <h1 align="center">Discord.swift</h1>
</p>

<p align="center">
    <img src="https://img.shields.io/static/v1?label=version&style=for-the-badge&message=0.0.14-beta&color=ff992b">
    <a href="https://discord-swift.gitbook.io/discord.swift/"><img src="https://img.shields.io/static/v1?label=guide&style=for-the-badge&message=gitbook&color=5865f2"></a>
</p>


A Discord API library written in Swift, kept up-to-date with the latest features. Simple, elegant, and easy to use. Have fun creating your own bot! 🤖 Whether it's for moderation, only for you and your friends, or something entirely unique!

Enjoying the library? Don't forget to leave a ⭐️ 😄. 

## 🛜 Links
- [Discord support server](https://discord.gg/TYDZeruQ7N)
- [Changelog](https://discord-swift.gitbook.io/discord.swift/resources/changelog)
- [Documentation](https://discord-swift.gitbook.io/discord.swift/resources/documentation)
- [Setup guide](https://discord-swift.gitbook.io/discord.swift/overview/getting-started)

## 👀 Linux Support
When it comes to hosting your bot, you'll notice that when it comes to macOS servers, they can be really expensive. Not only does this put a burden on you, but it makes the library less appealing to use. With this library being so young and releasing its very first version in May 2023, there's still a lot of work to do and this is one of those tasks. Discord.swift linux support is in development! With that said, so far its kind of a big change, so people who are already using the library should expect a handful of breaking changes. Not only is it required, but there were a few things I wanted to change anyway but was a little hesitant to just because I didn't want to push a breaking change. I'll say it now, expect breaking changes while the library is still in beta. Beta versions of...well anything is the time where you get things right, and I don't want to rush anything whatsoever. Linux support for Discord.swift will be released for version 0.1.0-beta. In the mean time, if anything pertinent occurs from the time of this readme update (Sep. 1, 2023), Discord.swift will continue to get updates on versions 0.0.X-beta. Thank you for all the support so far! Here's to the future release of 1.0.0 🍻.

**TL;DR** - Linux support for Discord.swift is in development and is scheduled to be released early October 2023 (hopefully sooner ❤️).

## 😎 Key Features
- Asynchronous functionality using `async` and `await`.
- Full application command support
    - [x] Slash commands
    - [x] Message commands
    - [x] User commands
- Full message components support
    - [x] Buttons
    - [x] Select menus
    - [x] Modals/text input

## Application Commands Example
```swift
import Discord

let bot = Discord(token: "...", intents: Intents.default)

bot.addSlashCommand(
    name: "example",
    description: "Example command",
    guildId: nil,
    onInteraction: { interaction async in
        try! await interaction.respondWithMessage("This is an example", ephemeral: true)
    }
)

bot.addUserCommand(
    name: "Who is",
    guildId: 1234567890123456789,
    onInteraction: { interaction async in
        try! await interaction.respondWithMessage("...")
    }
)

try! await bot.syncApplicationCommands() // Only needs to be done once
try! await bot.connect()
```

## Event Listener Example
```swift
import Discord

let bot = Discord(token: "...", intents: Intents.default)

class MyListener : EventListener {
    override func onMessageCreate(message: Message) async {
        // Don't respond to our own message
        guard !message.author.isBot else {
            return
        }

        if message.content == "hi swifty" {
            try! await message.channel.send("Hello!")
        }
    }
}

try! bot.addListeners(MyListener(name: "example"))
try! await bot.connect()
```
## Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/Defxult/Discord.swift", .exact("<version here>"))
]
// ...
dependencies: [
    .product(name: "Discord", package: "Discord.swift")
]
```
