# Discord.swift
[![Discord](https://img.shields.io/discord/1068105613323804733?label=discord&style=for-the-badge&logo=discord)](https://discord.gg/TYDZeruQ7N)
![Repo Version](https://img.shields.io/static/v1?label=version&style=for-the-badge&message=0.0.2-alpha&color=ff992b)

A Discord API wrapper written in Swift, kept up-to-date with the latest features. Simple, elegant, and easy to use. Have fun creating your own bot! 🤖 Whether it's for moderation, only for you and your friends, or something entirely unique!

## Key Features
- Asynchronous functionality using `async` and `await`.
- Full application command support
    - [x] Slash commands
    - [x] Message commands
    - [x] User commands
- Full message components support
    - [x] Buttons
    - [x] Select menus
    - [x] Modals/text input
- Implementation of the latest Discord API updates.

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
    .package(url: "https://github.com/Defxult/Discord.swift", branch: "main")
]
// ...
dependencies: [
    .product(name: "Discord", package: "Discord.swift")
]
```
