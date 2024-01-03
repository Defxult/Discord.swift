<p align="center">
    <h1 align="center">Discord.swift</h1>
</p>

<p align="center">
    <img src="https://img.shields.io/static/v1?label=version&style=for-the-badge&message=0.1.4-beta&color=ff992b">
    <a href="https://discord-swift.gitbook.io/discord.swift/overview/getting-started"><img src="https://img.shields.io/static/v1?label=guide&style=for-the-badge&message=gitbook&color=5865f2"></a>
</p>


A Discord API library written in Swift.

## 🌍 Links
- [Changelog](https://discord-swift.gitbook.io/discord.swift/resources/changelog)
- [Documentation](https://discord-swift.gitbook.io/discord.swift/resources/documentation)
- [Setup guide](https://discord-swift.gitbook.io/discord.swift/overview/getting-started)

## 😎 Key Features
- Asynchronous functionality using `async` and `await`
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

let bot = Bot(token: "...", intents: Intents.default)

bot.addSlashCommand(
    name: "example",
    description: "Example command",
    guildId: nil,
    onInteraction: { interaction in
        try! await interaction.respondWithMessage("This is an example", ephemeral: true)
    }
)

bot.addUserCommand(
    name: "Who is",
    guildId: 1234567890123456789,
    onInteraction: { interaction in
        try! await interaction.respondWithMessage("...")
    }
)

try! await bot.syncApplicationCommands() // Only needs to be done once
bot.run()
```

## Event Listener Example
```swift
import Discord

let bot = Bot(token: "...", intents: Intents.default)

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
bot.run()
```
## Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/Defxult/Discord.swift.git", .exact("<version here>"))
]
// ...
dependencies: [
    .product(name: "Discord", package: "Discord.swift")
]
```
