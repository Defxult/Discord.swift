# Discord.swift

Discord.swift has been a passion project for me. I've noticed that there are Discord API wrappers for many languages, but there wasn't any for Swift that were kept up-to-date with the latest features, so I decided to make this one. This project has came a long way since I've started on it. I've been programming for quite some time, but I'm on the newer side when it comes to Swift so forgive me if you see a lot of code that can be improved.

This project is currently in pre-alpha, and I plan on improving the library over time and I could use all the help I can get 😄. Thank you for taking the time to read.

## Basic Example
```swift
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
try await bot.addListeners(MyListener(name: "example"))
try await bot.connect()
```
Join the Discord server: https://discord.gg/TYDZeruQ7N
