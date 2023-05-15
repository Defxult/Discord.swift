# Discord.swift

Discord.swift has been a passion project for me. I've noticed that there are Discord API wrappers for many languages, but there wasn't any for Swift that were kept up-to-date with the latest features, so I decided to make this one. This project has came a long way since I've started on it. I've been programming for quite some time, but I'm on the newer side when it comes to Swift so forgive me if you see a lot of code that can be improved.

This project is currently in alpha, but I have almost everything implemented that the Discord API has to offer. I plan on improving the library over time and I could use all the help I can get 😄. Thank you for taking the time to read.

Join the Discord server: https://discord.gg/TYDZeruQ7N

## Key Features
- Asynchronous programming using `async` and `await`.
- Full application command support.
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
