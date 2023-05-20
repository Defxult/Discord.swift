# Discord.swift
A Discord API wrapper written in Swift, kept up-to-date with the latest features/updates.

Join the Discord server: https://discord.gg/TYDZeruQ7N

## Key Features
- Asynchronous programming using `async` and `await`.
- Full application command support (slash, user, and message commands).
- Full message components support (buttons, select menus, modals/text input)
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
    name: "whois",
    guildId: 1234567890123456789,
    onInteraction: { interaction async in
        try! await interaction.respondWithMessage("...")
    }
)

try await bot.syncApplicationCommands() // Only needs to be done once
try await bot.connect()
```

## Event Listener Example
```swift
import Discord

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

let bot = Discord(token: "...", intents: Intents.default)
try bot.addListeners(MyListener(name: "example"))
try await bot.connect()
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
