import Foundation

func dictToData(_ dict: [String: Any]) -> Data {
    return try! JSONSerialization.data(withJSONObject: dict)
}

func dataToDict(_ data: Data) -> JSON {
    return try! JSONSerialization.jsonObject(with: data) as! JSON
}

fileprivate struct ResumePayload {
    fileprivate let sessionId: String
    fileprivate var sequence: Int
    fileprivate var resumeGatewayURL: String?
    
    fileprivate init(data: JSON) {
        let d = data["d"] as! JSON
        sessionId = d["session_id"] as! String
        sequence = data["s"] as! Int
        resumeGatewayURL =  nil
    }
}

fileprivate struct GatewayPayload {
    
    /// Opcode for the payload.
    fileprivate let op: Int
    
    /// The event data.
    fileprivate let d: JSON?
    
    /// Sequence number, used for resuming sessions and heartbeats.
    fileprivate let s: Int?
    
    /// The event name for this payload.
    fileprivate let t: String?
    
    fileprivate init(data: JSON) {
        op = data["op"] as! Int
        d = data["d"] as? JSON
        s = data["s"] as? Int
        t = data["t"] as? String
    }
}

struct Opcode {
    static let dispatch = 0
    static let heartbeat = 1
    static let identify = 2
    static let presenceUpdate = 3
    static let voiceStateUpdate = 4
    static let resume = 6
    static let reconnect = 7
    static let requestGuildMembers = 8
    static let invalidSession = 9
    static let hello = 10
    static let heartbeatAck = 11
}

fileprivate class State {
    let guildId: Snowflake
    let chunkCount: Int
    var chunkIndex: Int
    
    var isCompleted: Bool { chunkIndex == chunkCount }
    
    init(guildId: Snowflake, chunkCount: Int, chunkIndex: Int) {
        self.guildId = guildId
        self.chunkCount = chunkCount
        self.chunkIndex = chunkIndex
    }
}

class InitialState {
    fileprivate var expectedGuilds: Int
    fileprivate var guildsCreated = 0
    fileprivate var states: [State] = []
    var dispatched = false
    
    fileprivate init(expectedGuilds: Int) {
        self.expectedGuilds = expectedGuilds
    }
    
    fileprivate func addState(_ state: State) {
        states.append(state)
    }
    
    fileprivate func getState(guildId: Snowflake) -> State? {
        return states.first(where: { $0.guildId == guildId })
    }
    
    fileprivate func updateState(guildId: Snowflake) {
        let state = getState(guildId: guildId)!
        state.chunkIndex += 1
    }
    
    fileprivate func allStatesCompleted() -> Bool { states.allSatisfy({ $0.isCompleted }) }
}

class WSGateway {
    var initialHandshakeComplete = false
    var ws: URLSessionWebSocketTask
    var shards: Int
    var isConnected = false
    var initialState: InitialState? = nil
    private var heartbeatInterval = 0
    private let bot: Discord
    private var wsResume: ResumePayload?
    private let apiVersion = "/?v=10&encoding=json"
    private let session: URLSession
    fileprivate let gatewayURLObj: URL
    fileprivate var gp: GatewayPayload?
    
    init(bot: Discord, gatewayUrl: String, shards: Int) {
        gatewayURLObj = URL(string: gatewayUrl + apiVersion)!
        session = URLSession.shared
        ws = session.webSocketTask(with: gatewayURLObj)
        wsResume = nil
        self.shards = shards
        self.bot = bot
    }
    
    func handshake(sharding: Bool) async throws {
        if initialHandshakeComplete {
            Log.message("Attempting another handshake - setting new WebSocket", withTimestamp: true)
            ws = session.webSocketTask(with: gatewayURLObj)
        }
        ws.resume()
        
        // Waiting for Opcode HELLO
        let info = try await ws.receive()
        
        switch info {
        case .data(_):
            Log.fatal("Websocket info found in DATA")
        case .string(let str):
            let opHello = HTTPClient.strJsonToDict(str)
            gp = GatewayPayload(data: opHello)
            let dObj = opHello["d"] as! JSON
            heartbeatInterval = dObj["heartbeat_interval"] as! Int
            
            var d: JSON = [
                "token": bot.http.token,
                "intents": Intents.convert(bot.intents),
                "properties": [
                    "os": bot.version.gateway.os,
                    "browser": bot.version.gateway.lib,
                    "device": bot.version.gateway.lib
                ]
            ]
            
            if bot.sharding { d["shards"] = [0, shards] }
            
            // Now that we've reveived opHello, we need to ID ourself
            let identity: JSON = [
                "op": Opcode.identify,
                "d": d
            ]
            try await ws.send(.data(dictToData(identity)))
        @unknown default:
            throw GatewayError.unknownError("An unknown error occured")
        }
    }
    
    func membersChunk(guildId: Snowflake) async {
        let payload: JSON = [
            "op": Opcode.requestGuildMembers,
            "d": [
                "guild_id": guildId,
                "query": String.empty,
                "limit": 0
            ] as [String : Any]
        ]
        try! await ws.send(.data(dictToData(payload)))
    }
    
    func heartbeat(requestedByGateway: Bool = false) async throws {
        
        func sendHeartBeat() async throws {
            try await ws.send(.data(dictToData([
                "op": Opcode.heartbeat,
                "d": wsResume == nil ? NIL : wsResume!.sequence
            ])))
        }
        
        if requestedByGateway {
            try await sendHeartBeat()
        }
        else {
            while true {
                await sleep(heartbeatInterval)
                if isConnected { try await sendHeartBeat() }
                else { break }
            }
        }
    }
    
    func determineWsError(code: Int) -> (error: GatewayError, requiresReconnect: Bool) {
        switch code {
        case 4000:
            return (GatewayError.unknownError("Something went wrong"), true)
        case 4001:
            return (GatewayError.unknownOpcode("An invalid op code was sent"), true)
        case 4002:
            return (GatewayError.decodeError("An invalid payload was sent"), true)
        case 4003:
            return (GatewayError.notAuthenticated("An attempt to send data was made before the bot could identify"), true)
        case 4004:
            return (GatewayError.authenticationFailed("Invalid bot token"), false)
        case 4005:
            return (GatewayError.alreadyAuthenticated("More the one identity payloads were sent"), true)
        case 4007:
            return (GatewayError.invalidSeq("The sequence when resuming the session was invalid"), true)
        case 4008:
            return (GatewayError.rateLimited("Too many payloads are being sent"), true)
        case 4009:
            return (GatewayError.sessionTimedOut("Session timed out"), true)
        case 4010:
            return (GatewayError.invalidShard("An invalid shard was sent when identifying"), false)
        case 4011:
            return (GatewayError.shardingRequired("Sharding the connection is required"), false)
        case 4012:
            return (GatewayError.invalidApiVersion("An invalid API version was sent for the gateway"), false)
        case 4013:
            return (GatewayError.invalidIntents("An invalid intent was sent for the gateway intent"), false)
        case 4014:
            return (GatewayError.disallowedIntents("A disallowed intent was sent for the gateway intent"), false)
        default:
            return (GatewayError.unknownError("Something went wrong"), true)
        }
    }
    
    private func reconnect() async {
        Log.message("(Reconnect) Connecting to gateway. Waiting for op hello...", withTimestamp: true)
        ws = session.webSocketTask(with: gatewayURLObj)
        ws.resume()
        
        // Waiting for op hello
        _ = try! await ws.receive()
        Log.message("(Reconnect) OP hello received", withTimestamp: true)
        
        let reconnectPayload: JSON = [
            "op": Opcode.resume,
            "d": [
                "token": bot.http.token,
                "session_id": wsResume!.sessionId,
                "seq": wsResume!.sequence
            ] as [String : Any]
        ]
        Log.message("(Reconnect) Sending reconnect payload...", withTimestamp: true)
        try! await ws.send(.data(dictToData(reconnectPayload)))
        Log.message("(Reconnect) Reconnect payload sent successfully", withTimestamp: true)
    }
    
    func listen() async throws {
        while isConnected {
            
            // Wait for an event to be dispatched
            if let msg = try? await ws.receive() {
                switch msg {
                case .data(_):
                    Log.fatal("Payload via listen() found in .data")
                case .string(let string):
                    let resumePayload = HTTPClient.strJsonToDict(string)
                    let gatewayPayload = GatewayPayload(data: resumePayload)
                    
                    if gatewayPayload.op == Opcode.dispatch {
                        let event = WSGateway.getEvent(name: gatewayPayload.t!)
                        if event == .ready {
                            wsResume = ResumePayload(data: resumePayload)
                            wsResume?.resumeGatewayURL = gatewayPayload.d?["resume_gateway_url"] as? String
                            bot.user = ClientUser(clientUserData: gatewayPayload.d!["user"] as! JSON)
                            
                            let guildsCount = (gatewayPayload.d!["guilds"] as! [JSON]).count
                            initialState = InitialState(expectedGuilds: guildsCount)
                        }
                        else { wsResume?.sequence = gatewayPayload.s! }
                        await createAndUpdate(data: gatewayPayload.d!, event: event)
                    }
                    else if gatewayPayload.op == Opcode.heartbeat {
                        Log.message("Gateway requested HEARTBEAT. Sending heartbeat...", withTimestamp: true)
                        try await heartbeat(requestedByGateway: true)
                    }
                    else if gatewayPayload.op == Opcode.reconnect {
                        Log.message("Gateway requested RECONNECT. Attempting reconnect...", withTimestamp: true)
                        await reconnect()
                    }
                    else if gatewayPayload.op == Opcode.invalidSession {
                        Log.message("Session invalidated. Attempting handshake...", withTimestamp: true)
                        try await handshake(sharding: bot.sharding)
                        await sleep(Int.random(in: 1...5) * 1000)
                    }
                    else if gatewayPayload.op == Opcode.heartbeatAck {
                        Log.message("Heartbeat ACK", withTimestamp: true)
                        continue
                    }
                    else {
                        Log.fatal("Gateway payload not handled: \(gatewayPayload)")
                    }
                @unknown default:
                    Log.fatal("Unknown error")
                }
                
                // An error occured so handle accordingly
            } else {
                let closeEventCode = ws.closeCode.rawValue
                Log.message("WS Closed - Error Code - \(closeEventCode) | \(ws.closeCode) - \(String(describing: ws.error?.localizedDescription))", withTimestamp: true)
                
                let wsError = determineWsError(code: closeEventCode)
                if wsError.requiresReconnect {
                    Log.message("WebSocket Requires RECONNECT - \(wsError)", withTimestamp: true)
                    await reconnect()
                }
            }
        }
    }
    
    private static func getEvent(name: String) -> DiscordEvent {
        return DiscordEvent(rawValue: name)!
    }
    
    /// Handles the process of calling the `onInteraction` closures set by the users for interactions
    private func handleInteractions(interaction: Interaction) async {
        switch interaction.type {
        case .ping:
            break
        case .applicationCommand, .applicationCommandAutocomplete:
            let appData = interaction.data as! ApplicationCommandData
            if let appCmd = interaction.bot!.pendingApplicationCommands.first(where: { $0.name == appData.name && $0.guildId == appData.guildId && $0.type == appData.type }) {
                if interaction.type == .applicationCommand {
                    await appCmd.onInteraction(interaction)
                } else {
                    // Find the options and its suggestion that matches the currently dispatched
                    if let dataOptions = appData.options {
                        let autocompleteName = dataOptions.last!.name
                        if let cmdOptions = appCmd.options {
                            if let cmdOptionMatch = cmdOptions.first(where: { $0.name == autocompleteName }) {
                                try! await interaction.respondWithAutocomplete(choices: cmdOptionMatch.suggestions!)
                            }
                        }
                    }
                }
            }
        case .messageComponent:
            if let cachedMsg = interaction.bot!.getMessage(interaction.message!.id) {
                // Reset the onTimeout timer. With each interaction this is reset because I don't want the
                // components to be disabled (by default) when components are in active use
                cachedMsg.ui?.startOnTimeoutTimer()
                
                await cachedMsg.ui?.onInteraction(interaction)
            }
        case .modalSubmit:
            let modalSubmitData = interaction.data as! ModalSubmitData
            if let pending = interaction.bot!.pendingModals.first(where: { $0.key == modalSubmitData.customId }) {
                await pending.value(interaction)
            }
        }
    }
    
    private func createAndUpdate(data: JSON, event: DiscordEvent) async {
        
        func getGuildIdFromJSON(_ data: JSON) -> Snowflake {
            if data.keys.contains(where: { $0 == "guild_id" }) {
                return Conversions.snowflakeToUInt(data["guild_id"])
            } else {
                fatalError("guild_id was not found in JSON response")
            }
        }
        
        let dispatch = bot.listeners.forEachAsync
        
        switch event {
        case .ready:
            dispatch({ await $0.onConnect(user: self.bot.user!) })
            
            // `onReady()` is based on the initial state. Meaning when it's finished caching everything,
            // aka guilds, channels, users, members, etc, the event will be dispatched. But the guild itself
            // is what houses *all* of that information. Without guilds, there isn't much to cache (with the exception of DMs).
            // So basically, if the `.guilds` intent is missing, dispatch `onReady()` when the bot has connected
            // to Discord because there is no caching when all of its caching capabilites are essentially
            // disabled (missing the .guilds intent).
            if !bot.intents.contains(.guilds) {
                initialState?.dispatched = true
                dispatch({ await $0.onReady() })
            }
            
        case .resumed:
            Log.message("Gateway resumed", withTimestamp: true)
            
        case .reconnect, .invalidSession:
            Log.message("Recieved event -> \(event) - reconnecting...", withTimestamp: true)
            await reconnect()
            
        case .applicationCommandPermissionsUpdate:
            let permissions = GuildApplicationCommandPermissions(guildAppCommandPermData: data)
            dispatch({ await $0.onApplicationCommandPermissionsUpdate(permissions: permissions) })
            
        case .autoModerationRuleCreate:
            let rule = AutoModerationRule(bot: bot, autoModData: data)
            dispatch({ await $0.onAutoModerationRuleCreate(rule: rule) })
            
        case .autoModerationRuleUpdate:
            let rule = AutoModerationRule(bot: bot, autoModData: data)
            dispatch({ await $0.onAutoModerationRuleUpdate(rule: rule) })
            
        case .autoModerationRuleDelete:
            let rule = AutoModerationRule(bot: bot, autoModData: data)
            dispatch({ await $0.onAutoModerationRuleDelete(rule: rule) })
            
        case .autoModerationActionExecution:
            let actionExec = AutoModerationRule.ActionExecution(bot: bot, actionExecutionData: data)
            dispatch({ await $0.onAutoModerationRuleExecution(execution: actionExec) })
            
        case .channelCreate:
            let channelType = data["type"] as! Int
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            let channel = determineGuildChannelType(type: channelType, data: data, bot: bot, guildId: guild.id)
            guild.cacheChannel(channel)
            dispatch({ await $0.onChannelCreate(channel: channel) })
            
        case .channelUpdate:
            let channelId = Conversions.snowflakeToUInt(data["id"])
            let beforeChannel = bot.getChannel(channelId)! as! GuildChannel
            let afterChannel = determineGuildChannelType(type: beforeChannel.type.rawValue, data: data, bot: bot, guildId: beforeChannel.guildId)
            afterChannel.guild.cacheChannel(afterChannel)
            dispatch({ await $0.onChannelUpdate(before: beforeChannel, after: afterChannel) })
            
        case .channelDelete:
            let channelId = Conversions.snowflakeToUInt(data["id"])
            let deletedChannel = bot.getChannel(channelId)! as! GuildChannel
            dispatch({ await $0.onChannelDelete(channel: deletedChannel) })
            deletedChannel.guild.removeChannelFromCache(channelId)
            
        case .channelPinsUpdate:
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let channel = bot.getChannel(channelId)! as! GuildChannel
            
            var pinnedAt: Date? = nil
            if let pinnedDate = data["last_pin_timestamp"] as? String { pinnedAt = Conversions.stringDateToDate(iso8601: pinnedDate) }
            dispatch({ await $0.onChannelPinsUpdate(channel: channel, pinnedAt: pinnedAt) })
            
        case .threadCreate:
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            let thread = ThreadChannel(bot: bot, threadData: data, guildId: guild.id)
            guild.cacheChannel(thread)
            dispatch({ await $0.onThreadCreate(thread: thread) })
            
        case .threadUpdate:
            let threadId = Conversions.snowflakeToUInt(data["id"])
            let guildId = getGuildIdFromJSON(data)
            let memberCount = data["member_count"] as! Int
            dispatch({ await $0.onRawThreadUpdate(payload: (threadId, guildId, memberCount, data)) })
            
            let guild = bot.getGuild(guildId)!
            let beforeThread = guild.channelsCache.removeValue(forKey: threadId) as! ThreadChannel
            let afterThread = determineGuildChannelType(type: beforeThread.type.rawValue, data: data, bot: bot, guildId: beforeThread.guildId) as! ThreadChannel
            guild.cacheChannel(afterThread)
            dispatch({ await $0.onThreadUpdate(before: beforeThread, after: afterThread) })
            
        case .threadDelete:
            let threadId = Conversions.snowflakeToUInt(data["id"])
            let guildId = getGuildIdFromJSON(data)
            let parentId = Conversions.snowflakeToUInt(data["parent_id"])
            
            if let thread = bot.getChannel(threadId) as? ThreadChannel {
                thread.guild.removeChannelFromCache(thread.id)
                dispatch({ await $0.onThreadDelete(thread: thread) })
            }
            
            dispatch({ await $0.onRawThreadDelete(payload: (threadId, guildId, parentId)) })
            
        case .threadListSync:
            // Discord says: "Sent when the current user *gains* access to a channel". When testing, basically if
            // a channel containing threads was not visible to the bot, and the permissions were changed so the
            // bot can now see said threads, this is dispatched. If a channel that the bot can now see doesn't have
            // any threads, this is not be dispatched by discord.
            
            let guildId = getGuildIdFromJSON(data)
            let threadObjs = data["threads"] as! [JSON]
            
            var syncedThreads = [ThreadChannel]()
            let guild = bot.getGuild(guildId)!
            
            for threadObj in threadObjs {
                let thread = ThreadChannel(bot: bot, threadData: threadObj, guildId: guildId)
                syncedThreads.append(thread)
                guild.cacheChannel(thread)
            }
            
            dispatch({ await $0.onThreadListSync(threads: syncedThreads) })
        
        case .threadMemberUpdate:
            // Unused
            break
            
        case .threadMembersUpdate:
            let threadId = Conversions.snowflakeToUInt(data["id"])
            let guildId = getGuildIdFromJSON(data)
            let memberCount = data["member_count"] as! Int
            
            if let guild = bot.getGuild(guildId) {
                if let thread = guild.getChannel(threadId) as? ThreadChannel {
                    thread.memberCount = memberCount
                }
            }
            
            if let addedThreadMemberObjs = data["added_members"] as? [JSON] {
                for obj in addedThreadMemberObjs {
                    dispatch({ await $0.onThreadMemberAdd(member: .init(threadMemberData: obj)) })
                }
            }
            
            if let ids = data["removed_member_ids"] as? [String] {
                var convertedSnowflakes = [Snowflake]()
                for id in ids {
                    convertedSnowflakes.append(Conversions.snowflakeToUInt(id))
                }
                dispatch({ await $0.onRawThreadMemberRemove(ids: convertedSnowflakes) })
            }
            
        case .guildCreate:
            let guild = Guild(bot: bot, guildData: data, fromGateway: true)
            initialState!.guildsCreated += 1
            bot.cacheGuild(guild)
            dispatch({ await $0.onGuildCreate(guild: guild) })
            dispatch({ await $0.onGuildAvailable(guild: guild) })
            
            if bot.intents.contains(.guildPresences) {
                Task { await membersChunk(guildId: guild.id) }
            }
            if initialState!.expectedGuilds == initialState!.guildsCreated {
                initialState!.dispatched = true
                dispatch({ await $0.onReady() })
            }
            
        case .guildUpdate:
            let guildId = Conversions.snowflakeToUInt(data["id"])
            let guild = bot.getGuild(guildId)!
            guild.update(data)
            
            dispatch({ await $0.onGuildUpdate(guild: guild) })
            
        case .guildDelete:
            let guildId = Conversions.snowflakeToUInt(data["id"])
            let guild = bot.getGuild(guildId)!
            
            if let _ = data["unavailable"] as? Bool {
                guild.isAvailable = false
                dispatch({ await $0.onGuildUnavailable(guild: guild) })
            } else {
                bot.guildsCache.removeValue(forKey: guildId)
            }
            
            dispatch({ await $0.onGuildDelete(guild: guild) })
            
        case .guildAuditLogCreate:
            let auditLog = AuditLog(auditLogDataFromGateway: data)
            dispatch({ await $0.onAuditLogCreate(log: auditLog) })
            
        case .guildBan:
            let guildId = getGuildIdFromJSON(data)
            let guild = bot.getGuild(guildId)!
            let user = User(userData: data["user"] as! JSON)
            
            dispatch({ await $0.onGuildBan(guild: guild, user: user) })
            
        case .guildUnban:
            let guildId = getGuildIdFromJSON(data)
            let guild = bot.getGuild(guildId)!
            let user = User(userData: data["user"] as! JSON)
            
            dispatch({ await $0.onGuildUnban(guild: guild, user: user) })
            
        case .guildEmojisUpdate:
            let guildId = getGuildIdFromJSON(data)
            let guild = bot.getGuild(guildId)!
            
            let emojiObjs = data["emojis"] as! [JSON]
            var emojisAfter = Set<Emoji>()
            
            for emojiObj in emojiObjs {
                emojisAfter.insert(Emoji(bot: bot, guildId: guildId, emojiData: emojiObj))
            }
            
            let beforeCopy = guild.emojis
            guild.emojis = emojisAfter
            
            dispatch({ await $0.onGuildEmojisUpdate(before: beforeCopy, after: emojisAfter) })
            
        case .guildStickersUpdate:
            let guildId = getGuildIdFromJSON(data)
            let guild = bot.getGuild(guildId)!
            
            let stickerObjs = data["stickers"] as! [JSON]
            var stickersAfter = [GuildSticker]()
            
            for stickerObj in stickerObjs {
                
                // GuildSticker init expects the guild_id, so manually insert it in this specific case
                var injectedGuildIdStickerObj = stickerObj
                injectedGuildIdStickerObj["guild_id"] = String(guildId)
                
                stickersAfter.append(GuildSticker(bot: bot, guildStickerData: injectedGuildIdStickerObj))
            }
            
            let beforeCopy = guild.stickers
            guild.stickers = stickersAfter
            
            dispatch({ await $0.onGuildStickersUpdate(before: beforeCopy, after: stickersAfter) })
            
        case .guildIntegrationsUpdate:
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            dispatch({ await $0.onGuildIntegrationUpdate(guild: guild) })
            
        case .guildMemberJoin:
            let guildId = getGuildIdFromJSON(data)
            let member = Member(bot: bot, memberData: data, guildId: guildId)
            member.guild.cacheMember(member)
            dispatch({ await $0.onGuildMemberJoin(member: member) })
            
        case .guildMemberRemove:
            let userObj = data["user"] as! JSON
            let userId = Conversions.snowflakeToUInt(userObj["id"])
            let guildId = getGuildIdFromJSON(data)
            
            if let member = bot.getMember(userId, in: guildId) {
                dispatch({ await $0.onGuildMemberRemove(member: member) })
                member.guild.removeMemberFromCache(member.id)
            }
            
            dispatch({ await $0.onRawGuildMemberRemove(payload: (guildId, User(userData: userObj))) })
            
        case .guildMemberUpdate:
            let guildId = getGuildIdFromJSON(data)
            let guild = bot.getGuild(guildId)!
            
            let userObj = data["user"] as! JSON
            let userId = Conversions.snowflakeToUInt(userObj["id"])
            
            if let beforeMember = guild.getMember(userId) {
                let afterMember = Member(bot: bot, memberData: data, guildId: guildId)
                afterMember.guild.cacheMember(afterMember)
                
                dispatch({ await $0.onGuildMemberUpdate(before: beforeMember, after: afterMember) })
            }
            
        case .guildMembersChunk:
            let guildId = getGuildIdFromJSON(data)
            let guild = bot.getGuild(guildId)!
            
            if bot.intents.contains(.guildPresences) {
                if let _ = initialState!.getState(guildId: guildId) {
                    initialState!.updateState(guildId: guildId)
                } else {
                    initialState!.addState(.init(guildId: guildId, chunkCount: data["chunk_count"] as! Int, chunkIndex: (data["chunk_index"] as! Int) + 1))
                }
                
                for cm in data["members"] as! [JSON] {
                    let user = cm["user"] as! JSON
                    let chunkedMemberId = Conversions.snowflakeToUInt(user["id"])
                    if guild.getMember(chunkedMemberId) == nil {
                        let chunkedMember = Member(bot: bot, memberData: cm, guildId: guildId)
                        bot.cacheUser(chunkedMember.user!)
                        guild.cacheMember(chunkedMember)
                    }
                }
                
                if (initialState!.expectedGuilds == initialState!.states.count && initialState!.allStatesCompleted()) {
                    initialState?.states.removeAll()
                    if !initialState!.dispatched {
                        initialState!.dispatched = true
                        dispatch({ await $0.onReady() })
                    }
                }
            }
            
        case .guildRoleCreate:
            let guildId = getGuildIdFromJSON(data)
            let role = Role(bot: bot, roleData: data["role"] as! JSON, guildId: guildId)
            let guild = bot.getGuild(guildId)!
            guild.roles.append(role)
            dispatch({ await $0.onGuildRoleCreate(role: role) })
            
        case .guildRoleUpdate:
            let guildId = getGuildIdFromJSON(data)
            let updatedRole = Role(bot: bot, roleData: data["role"] as! JSON, guildId: guildId)
            let guild = bot.getGuild(guildId)!
            let oldRole = guild.getRole(updatedRole.id)!
            
            let idx = guild.roles.firstIndex(of: oldRole)!
            guild.roles[idx] = updatedRole
            dispatch({ await $0.onGuildRoleUpdate(before: oldRole, after: updatedRole) })
            
        case .guildRoleDelete:
            let guildId = getGuildIdFromJSON(data)
            let roleId = Conversions.snowflakeToUInt(data["role_id"])
            let guild = bot.getGuild(guildId)!
            let role = guild.getRole(roleId)!
            dispatch({ await $0.onGuildRoleDelete(role: role) })
            guild.roles.removeAll(where: { $0.id == roleId })
            
        case .guildScheduledEventCreate:
            let event = Guild.ScheduledEvent(bot: bot, eventData: data)
            event.guild.scheduledEvents.append(event)
            dispatch({ await $0.onGuildScheduledEventCreate(event: event) })
            
        case .guildScheduledEventUpdate:
            let eventAfter = Guild.ScheduledEvent(bot: bot, eventData: data)
            let guild = bot.getGuild(eventAfter.guild.id)!
            let eventBefore = guild.getScheduledEvent(eventAfter.id)!
            
            let idx = guild.scheduledEvents.firstIndex(where: { $0.id == eventBefore.id })!
            guild.scheduledEvents[idx] = eventAfter
            dispatch({ await $0.onGuildScheduledEventUpdate(before: eventBefore, after: eventAfter) })
            
        case .guildScheduledEventDelete:
            let event = Guild.ScheduledEvent(bot: bot, eventData: data)
            event.guild.scheduledEvents.removeAll(where: { $0.id == event.id })
            dispatch({ await $0.onGuildScheduledEventDelete(event: event) })
            
        case .guildScheduledEventUserAdd:
            let eventId = Conversions.snowflakeToUInt(data["guild_scheduled_event_id"])
            let guildId = getGuildIdFromJSON(data)
            let userId = Conversions.snowflakeToUInt(data["user_id"])
            let event = bot.getGuild(guildId)!.getScheduledEvent(eventId)!
            let user = bot.getUser(userId)!
            dispatch({ await $0.onGuildScheduledEventUserAdd(event: event, user: user) })
            
        case .guildScheduledEventUserRemove:
            let eventId = Conversions.snowflakeToUInt(data["guild_scheduled_event_id"])
            let guildId = getGuildIdFromJSON(data)
            let userId = Conversions.snowflakeToUInt(data["user_id"])
            let event = bot.getGuild(guildId)!.getScheduledEvent(eventId)!
            let user = bot.getUser(userId)!
            dispatch({ await $0.onGuildScheduledEventUserRemove(event: event, user: user) })
            
        case .integrationCreate:
            let integration = Guild.Integration(bot: bot, integrationData: data, guildId: getGuildIdFromJSON(data))
            dispatch({ await $0.onIntegrationCreate(integration: integration) })
            
        case .integrationUpdate:
            let integration = Guild.Integration(bot: bot, integrationData: data, guildId: getGuildIdFromJSON(data))
            dispatch({ await $0.onIntegrationUpdate(integration: integration) })
            
        case .integrationDelete:
            let id = Conversions.snowflakeToUInt(data["id"])
            let guildId = getGuildIdFromJSON(data)
            let applicationId = Conversions.snowflakeToUInt(data["application_id"])
            dispatch({ await $0.onIntegrationDelete(payload: (id, guildId, applicationId)) })
            
        case .interactionCreate:
            let interaction = Interaction(bot: bot, interactionData: data)
            dispatch({ await $0.onInteractionCreate(interaction: interaction) })
            Task { await handleInteractions(interaction: interaction) }
            
        case .inviteCreate:
            let inv = Invite(bot: bot, inviteData: data)
            dispatch({ await $0.onInviteCreate(invite: inv) })
            
        case .inviteDelete:
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            let code = data["code"] as! String
            dispatch({ await $0.onRawInviteDelete(payload: (channelId, guildId, code)) })
            
        case .messageCreate:
            let message = Message(bot: bot, messageData: data)
            if message.isDmMessage && !message.isEphemeral {
                guard !bot.ignoreDms else { break }
                bot.dms.update(with: message.channel as! DMChannel)
            }
            
            bot.cacheMessage(message)
            bot.cacheUser(message.author)
            
            // Update the channels last_message_id
            if let channel = bot.getChannel(message.channelId) {
                switch channel.type {
                case .dm:
                    let c = channel as! DMChannel
                    c.lastMessageId = message.id
                    
                case .guildText, .guildAnnouncement:
                    let c = channel as! TextChannel
                    c.lastMessageId = message.id
                    
                case .guildVoice:
                    let c = channel as! VoiceChannel
                    c.lastMessageId = message.id
                    
                case .announcementThread, .publicThread, .privateThread:
                    let c = channel as! ThreadChannel
                    c.lastMessageId = message.id
                    
                case .guildStageVoice:
                    let c = channel as! StageChannel
                    c.lastMessageId = message.id
                
                // Not messageable
                case .guildCategory, .guildForum:
                    break
                }
            }
            
            dispatch({ await $0.onMessageCreate(message: message) })
            
        case .messageUpdate:
            let messageId = Conversions.snowflakeToUInt(data["id"])
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            let cachedMessage = bot.getMessage(messageId)
            
            cachedMessage?.update(data)
            dispatch({ await $0.onRawMessageUpdate(payload: (cachedMessage, guildId, channelId, data)) })
            
        case .messageDelete:
            let messageId = Conversions.snowflakeToUInt(data["id"])
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            
            if let message = bot.getMessage(messageId) {
                // Before the message is removed from the cache, invalidate the UI onTimeout timer
                message.ui?.timer?.invalidate()
                
                bot.removeCachedMessage(message.id)
                dispatch({ await $0.onMessageDelete(message: message) })
            }
            dispatch({ await $0.onRawMessageDelete(payload: (messageId, channelId, guildId)) })
            
        case .messageDeleteBulk:
            var messagesIds = [Snowflake]()
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            
            for messageIdStr in data["ids"] as! [String] { messagesIds.append(Conversions.snowflakeToUInt(messageIdStr)) }
            
            var messagesFoundInCache = [Message]()
            for msgId in messagesIds {
                if let msg = bot.getMessage(msgId) { messagesFoundInCache.append(msg) }
            }
            
            if messagesFoundInCache.count > 0 {
                dispatch({ await $0.onMessageDeleteBulk(messages: messagesFoundInCache) })
            }
            
            dispatch({ await $0.onRawMessageDeleteBulk(payload: (messagesIds, channelId, guildId)) })
            
            // Remove all the messages from the internal cache (if any)
            for m in messagesFoundInCache { bot.removeCachedMessage(m.id) }
            
        case .messageReactionAdd:
            let userId = Conversions.snowflakeToUInt(data["user_id"])
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let messageId = Conversions.snowflakeToUInt(data["message_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            let emoji = PartialEmoji(partialEmojiData: data["emoji"] as! JSON)
            
            var member: Member? = nil
            if let memberObj = data["member"] as? JSON { member = Member(bot: bot, memberData: memberObj, guildId: guildId!) }
            
            if let message = bot.getMessage(messageId) {
                let userIdWhoReacted = userId
                let userReacted = userIdWhoReacted == bot.user!.id
                
                if let user = bot.getUser(userIdWhoReacted) {
                    if let reaction = message.getReaction(emoji.description!) {
                        reaction.count += 1
                        dispatch({ await $0.onMessageReactionAdd(reaction: reaction, user: user) })
                    } else {
                        let reactionObj: JSON = [
                            "count": 1,
                            "me": userReacted,
                            "emoji": data["emoji"] as! JSON
                        ]
                        let newReaction = Reaction(bot: bot, reactionData: reactionObj, message: message)
                        message.reactions.append(newReaction)
                        dispatch({ await $0.onMessageReactionAdd(reaction: newReaction, user: user) })
                    }
                }
            }
            
            dispatch({ await $0.onRawMessageReactionAdd(payload: (userId, channelId, messageId, emoji, guildId, member)) })
            
        case .messageReactionRemove:
            let userIdWhoRemovedReaction = Conversions.snowflakeToUInt(data["user_id"])
            let messageId = Conversions.snowflakeToUInt(data["message_id"])
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            let emoji = PartialEmoji(partialEmojiData: data["emoji"] as! JSON)
            
            if let message = bot.getMessage(messageId), let user = bot.getUser(userIdWhoRemovedReaction) {
                if let reaction = message.getReaction(emoji.description!) {
                    // If the current reaction count is 1 and a reaction is currently being removed
                    // there are no reactions left, so remove them all.
                    if reaction.count == 1 {
                        message.reactions.removeAll(where: { $0.emoji.description == reaction.emoji.description })
                    } else {
                        reaction.count -= 1
                    }
                    reaction.userReacted = reaction.userReacted && (userIdWhoRemovedReaction == bot.user!.id) ? false : true
                    dispatch({ await $0.onMessageReactionRemove(reaction: reaction, user: user) })
                }
            }
            
            dispatch({ await $0.onRawMessageReactionRemove(payload: (userIdWhoRemovedReaction, channelId, messageId, emoji, guildId)) })
            
        case .messageReactionRemoveAll:
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let messageId = Conversions.snowflakeToUInt(data["message_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            
            if let message = bot.getMessage(messageId) {
                // There needs to be a copy of reactions because reactions.removeAll() is used.
                let reactionsCopy = message.reactions.map({ $0 })
                
                dispatch({ await $0.onMessageReactionRemoveAll(message: message, reactions: reactionsCopy) })
                message.reactions.removeAll()
            }
            
            dispatch({ await $0.onRawMessageReactionRemoveAll(payload: (channelId, messageId, guildId)) })
            
        case .messageReactionRemoveEmoji:
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let messageId = Conversions.snowflakeToUInt(data["message_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            let emoji = PartialEmoji(partialEmojiData: data["emoji"] as! JSON)
            
            if let message = bot.getMessage(messageId) {
                if let reactionToRemove = message.reactions.first(where: { $0.emoji.description == emoji.description }) {
                    message.reactions.removeAll(where: { $0.emoji.description == emoji.description })
                    dispatch({ await $0.onMessageReactionRemoveEmoji(reaction: reactionToRemove) })
                }
            }
            
            dispatch({ await $0.onRawMessageReactionRemoveEmoji(payload: (channelId, messageId, emoji, guildId)) })
            
        case .presenceUpdate:
            let userObj = data["user"] as! JSON
            let userId = Conversions.snowflakeToUInt(userObj["id"])
            if let user = bot.getUser(userId) {
                user.update(userObj)
                let status = User.Status(rawValue: data["status"] as! String)!
                
                var activities = [User.Activity]()
                for activityObj in data["activities"] as! [JSON] {
                    activities.append(User.Activity(activityData: activityObj))
                }
                
                dispatch({ await $0.onUserUpdate(user: user) })
                dispatch({ await $0.onPresenceUpdate(user: user, status: status, activities: activities.count == 0 ? nil : activities) })
            }
            
        case .stageInstanceCreate:
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            let stageInstance = StageInstance(bot: bot, stageInstanceData: data)
            
            guild.stageInstances.append(stageInstance)
            dispatch({ await $0.onStageInstanceCreate(stageInstance: stageInstance) })
            
        case .stageInstanceDelete:
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            let stageInstanceId = Conversions.snowflakeToUInt(data["id"])
            
            if let toDelStageInstIdx = guild.stageInstances.firstIndex(where: { $0.id == stageInstanceId }) {
                let deletedStageInstance = guild.stageInstances.remove(at: toDelStageInstIdx)
                dispatch({ await $0.onStageInstanceDelete(stageInstance: deletedStageInstance) })
            }
            
        case .stageInstanceUpdate:
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            let stageInstanceId = Conversions.snowflakeToUInt(data["id"])
            if let before = guild.stageInstances.first(where: { $0.id == stageInstanceId }) {
                let idx = guild.stageInstances.firstIndex(where: { $0.id == before.id })!
                let after = StageInstance(bot: bot, stageInstanceData: data)
                
                guild.stageInstances.remove(at: idx)
                guild.stageInstances.append(after)
                dispatch({ await $0.onStageInstanceUpdate(before: before, after: after) })
            }
            
        case .typingStart:
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let guildId = Conversions.snowflakeToOptionalUInt(data["guild_id"])
            let userId = Conversions.snowflakeToUInt(data["user_id"])
            let typingStartDate = Date(timeIntervalSince1970: data["timestamp"] as! TimeInterval)
            
            let memberObj = data["member"] as? JSON
            let channel = bot.getChannel(channelId) as? Messageable
            
            if let memberObj, let channel {
                dispatch({ [self] in await $0.onTypingStart(by: Member(bot: bot, memberData: memberObj, guildId: guildId!), at: typingStartDate, in: channel) })
            } else if let user = bot.getUser(userId), let channel {
                dispatch({ await $0.onTypingStart(by: user, at: typingStartDate, in: channel) })
            }
            
            if let memberObj {
                dispatch({ [self] in await $0.onRawTypingStart(payload: (channelId, guildId, userId, typingStartDate, Member(bot: bot, memberData: memberObj, guildId: guildId!))) })
            } else {
                dispatch({ await $0.onRawTypingStart(payload: (channelId, guildId, userId, typingStartDate, nil)) })
            }
            
        case .userUpdate:
            // This only updates the current bot user.
            let user = bot.getUser(Conversions.snowflakeToUInt(data["id"]))
            user?.update(data)
            
        case .voiceStateUpdate:
            // Docs say guild_id is optional. When tested, it's missing when recieved over the gateway, but seems to always be present here
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            
            let sessionId = data["session_id"] as! String
            if let vcState = guild.voiceStates.first(where: { $0.sessionId == sessionId }) {
                // If the channel_id is not nil, it's a state update. If nil, they left the channel so remove it from the cache.
                if let _ = Conversions.snowflakeToOptionalUInt(data["channel_id"]) {
                    vcState.update(data)
                } else {
                    vcState.guild.voiceStates.removeAll(where: { $0.sessionId == vcState.sessionId && $0.user.id == vcState.user.id })
                }
                dispatch({ await $0.onVoiceStateUpdate(voiceState: vcState) })
            } else {
                let newState = VoiceChannel.State(bot: bot, voiceStateData: data, guildId: guild.id)
                guild.voiceStates.append(newState)
                dispatch({ await $0.onVoiceStateUpdate(voiceState: newState) })
            }
            
        case .voiceServerUpdate:
            let token = data["token"] as! String
            let guildId = getGuildIdFromJSON(data)
            let endpoint = data["endpoint"] as? String
            dispatch({ await $0.onVoiceServerUpdate(token: token, guildId: guildId, endpoint: endpoint) })
            
        case .webhooksUpdate:
            let guild = bot.getGuild(getGuildIdFromJSON(data))!
            let channelId = Conversions.snowflakeToUInt(data["channel_id"])
            let channel = guild.getChannel(channelId)!
            dispatch({ await $0.onWebhooksUpdate(channel: channel) })
        }
    }
}

/// Represents the events that are dispatched by Discord.
public enum DiscordEvent : String, CaseIterable {
    
    /// Dispatched when a client has completed the initial handshake with the gateway.
    case ready = "READY"

    /// Dispatched when the client has resumed a session.
    case resumed = "RESUMED"
    
    /// Bot should reconnect to the gateway and resume.
    case reconnect = "RECONNECT"
    
    /// Failure to identify, resume, or invalid active session.
    case invalidSession = "INVALID_SESSION"

    /// An application command permission was updated.
    case applicationCommandPermissionsUpdate = "APPLICATION_COMMAND_PERMISSIONS_UPDATE"
    
    /// Auto moderation rule was created.
    case autoModerationRuleCreate = "AUTO_MODERATION_RULE_CREATE"
    
    /// Auto moderation rule was updated.
    case autoModerationRuleUpdate = "AUTO_MODERATION_RULE_UPDATE"
    
    /// Auto moderation rule was deleted.
    case autoModerationRuleDelete = "AUTO_MODERATION_RULE_DELETE"

    /// Auto moderation rule was triggered and an action was executed (e.g. a message was blocked).
    case autoModerationActionExecution = "AUTO_MODERATION_ACTION_EXECUTION"

    /// New guild channel was created.
    case channelCreate = "CHANNEL_CREATE"

    /// Channel was updated.
    case channelUpdate = "CHANNEL_UPDATE"

    /// Channel was deleted.
    case channelDelete = "CHANNEL_DELETE"

    /// Message was pinned or unpinned.
    case channelPinsUpdate = "CHANNEL_PINS_UPDATE"

    /// Thread created, also fired when being added to a private thread.
    case threadCreate = "THREAD_CREATE"
    
    /// Thread was updated.
    case threadUpdate = "THREAD_UPDATE"

    /// Thread was deleted.
    case threadDelete = "THREAD_DELETE"

    /// Sent when gaining access to a channel, contains all active threads in that channel.
    case threadListSync = "THREAD_LIST_SYNC"
    
    // [UNUSED] Thread member for the current user was updated.
    case threadMemberUpdate = "THREAD_MEMBER_UPDATE"

    /// Users were added or removed from a thread.
    case threadMembersUpdate = "THREAD_MEMBERS_UPDATE"
    
    /// A guild became available or user joined a new guild.
    case guildCreate = "GUILD_CREATE"
    
    /// Guild was updated
    case guildUpdate = "GUILD_UPDATE"

    /// When a guild becomes or was already unavailable due to an outage. Also when the bot leaves or is removed from a guild.
    case guildDelete = "GUILD_DELETE"
    
    /// A guild audit log entry was created.
    case guildAuditLogCreate = "GUILD_AUDIT_LOG_ENTRY_CREATE"

    /// User was banned from a guild.
    case guildBan = "GUILD_BAN_ADD"

    /// User was unbanned from a guild.
    case guildUnban = "GUILD_BAN_REMOVE"

    /// Guild emojis were updated.
    case guildEmojisUpdate = "GUILD_EMOJIS_UPDATE"

    /// Guild stickers were updated.
    case guildStickersUpdate = "GUILD_STICKERS_UPDATE"
    
    /// Guild integration was updated.
    case guildIntegrationsUpdate = "GUILD_INTEGRATIONS_UPDATE"
    
    /// New user joined a guild.
    case guildMemberJoin = "GUILD_MEMBER_ADD"
    
    /// User was removed from a guild.
    case guildMemberRemove = "GUILD_MEMBER_REMOVE"
    
    /// Guild member was updated.
    case guildMemberUpdate = "GUILD_MEMBER_UPDATE"
    
    /// This event is used internally and can't be utilized via ``EventListener``.
    case guildMembersChunk = "GUILD_MEMBERS_CHUNK"
    
    /// A new guild role was created.
    case guildRoleCreate = "GUILD_ROLE_CREATE"
    
    /// Guild role was updated.
    case guildRoleUpdate = "GUILD_ROLE_UPDATE"
    
    /// Guild role was deleted.
    case guildRoleDelete = "GUILD_ROLE_DELETE"
    
    /// A new guild scheduled event was created.
    case guildScheduledEventCreate = "GUILD_SCHEDULED_EVENT_CREATE"
    
    /// Guild scheduled event was updated.
    case guildScheduledEventUpdate = "GUILD_SCHEDULED_EVENT_UPDATE"
    
    /// Guild scheduled event was deleted.
    case guildScheduledEventDelete = "GUILD_SCHEDULED_EVENT_DELETE"
    
    /// A new user subscribed to a guild scheduled event.
    case guildScheduledEventUserAdd = "GUILD_SCHEDULED_EVENT_USER_ADD"
    
    /// User unsubscribed from a guild scheduled event.
    case guildScheduledEventUserRemove = "GUILD_SCHEDULED_EVENT_USER_REMOVE"
    
    /// A new guild integration was created.
    case integrationCreate = "INTEGRATION_CREATE"
    
    /// Guild integration was updated.
    case integrationUpdate = "INTEGRATION_UPDATE"
    
    /// Guild integration was deleted.
    case integrationDelete = "INTEGRATION_DELETE"
    
    /// User used an interaction, such as an Application Command.
    case interactionCreate = "INTERACTION_CREATE"
    
    /// A new invite to a channel was created.
    case inviteCreate = "INVITE_CREATE"
    
    /// Invite to a channel was deleted.
    case inviteDelete = "INVITE_DELETE"
    
    /// A new message was sent in a channel.
    case messageCreate = "MESSAGE_CREATE"
    
    /// Message was edited.
    case messageUpdate = "MESSAGE_UPDATE"
    
    /// Message was deleted.
    case messageDelete = "MESSAGE_DELETE"
    
    /// Multiple messages were deleted at once.
    case messageDeleteBulk = "MESSAGE_DELETE_BULK"
    
    /// User reacted to a message.
    case messageReactionAdd = "MESSAGE_REACTION_ADD"
    
    /// User removed a reaction from a message.
    case messageReactionRemove = "MESSAGE_REACTION_REMOVE"
    
    /// All reactions were explicitly removed from a message.
    case messageReactionRemoveAll = "MESSAGE_REACTION_REMOVE_ALL"
    
    /// All reactions for a given emoji were explicitly removed from a message.
    case messageReactionRemoveEmoji = "MESSAGE_REACTION_REMOVE_EMOJI"
    
    /// User was updated.
    case presenceUpdate = "PRESENCE_UPDATE"
    
    /// A new stage instance was created.
    case stageInstanceCreate = "STAGE_INSTANCE_CREATE"
    
    /// Stage instance was deleted or closed.
    case stageInstanceDelete = "STAGE_INSTANCE_DELETE"
    
    /// Stage instance was updated.
    case stageInstanceUpdate = "STAGE_INSTANCE_UPDATE"
    
    /// User started typing in a channel.
    case typingStart = "TYPING_START"
    
    /// Properties about the user changed.
    case userUpdate = "USER_UPDATE"
    
    /// Someone joined, left, or moved a voice channel.
    case voiceStateUpdate = "VOICE_STATE_UPDATE"
    
    /// Guild's voice server was updated.
    case voiceServerUpdate = "VOICE_SERVER_UPDATE"
    
    /// Guild channel webhook was created, update, or deleted.
    case webhooksUpdate = "WEBHOOKS_UPDATE"
}

/// Represents a group of events you can register to the bot.
open class EventListener {

    /// Name of the event listener.
    public let name: String
    
    /// Whether the listener is enabled.
    public var isEnabled: Bool
    
    /// Initialize a new event listener.
    /// - Parameters:
    ///   - name: Name of the event listener. Must be unique.
    ///   - isEnabled: Whether the event listener is enabled.
    public init(name: String, isEnabled: Bool = true) {
        self.name = name.lowercased()
        self.isEnabled = isEnabled
    }
    
    // MARK: Ready
    
    /// Dispatched when the bot has connected to Discord and the internal cache has finished its initial preperation.
    open func onReady() async {}
    
    /// Dispatched when the bot has connected to Discord. This is different from ``onReady()`` because this will dispatch as
    /// soon as the connection is successful. Meaning depending on how many guilds the bot is in, the internal cache may or may not be ready.
    /// - Parameter user: The bot user who connected.
    open func onConnect(user: ClientUser) async {}
    
    
    
    // MARK: Audit Log
    
    /// Dispatched when a audit log entry is created.
    /// - Parameter log: The newly created audit log.
    open func onAuditLogCreate(log: AuditLog) async {}
    
    
    
    // MARK: Application Command
    
    /// Dispatched when an application command permissions is updated.
    /// - Parameter permissions: The permiissions that were updated.
    open func onApplicationCommandPermissionsUpdate(permissions: GuildApplicationCommandPermissions) async {}
    
    
    
    // MARK: AutoModeration
    
    /// Dispatched when an auto-moderation rule is created.
    /// - Parameter rule: The rule that was created.
    /// - Requires: Intent ``Intents/autoModerationConfiguration``.
    open func onAutoModerationRuleCreate(rule: AutoModerationRule) async {}
    
    /// Dispatched when an auto-moderation rule is updated.
    /// - Parameter rule: The rule that was updated.
    /// - Requires: Intent ``Intents/autoModerationConfiguration``.
    open func onAutoModerationRuleUpdate(rule: AutoModerationRule) async {}
    
    /// Dispatched when an auto-moderation rule is deleted.
    /// - Parameter rule: The rule that was deleted.
    /// - Requires: Intent ``Intents/autoModerationConfiguration``.
    open func onAutoModerationRuleDelete(rule: AutoModerationRule) async {}
    
    /// Dispatched when a rule is triggered and an action is executed (e.g. when a message is blocked).
    /// - Parameter execution: The action that was executed.
    /// - Requires: Intent ``Intents/autoModerationExecution``.
    open func onAutoModerationRuleExecution(execution: AutoModerationRule.ActionExecution) async {}
    
    
    
    // MARK: Channel
    
    /// Dispatched when a guild channel is created.
    /// - Parameter channel: The guild channel that was created.
    /// - Requires: Intent ``Intents/guilds``.
    open func onChannelCreate(channel: GuildChannel) async {}
    
    /// Dispatched when a guild channel is updated.
    /// - Parameters:
    ///   - before: The guild channel before the update.
    ///   - after: The guild channel after the update.
    /// - Requires: Intent ``Intents/guilds``.
    open func onChannelUpdate(before: GuildChannel, after: GuildChannel) async {}
    
    /// Dispatched when a guild channel is deleted.
    /// - Parameter channel: The guild channel that was deleted.
    /// - Requires: Intent ``Intents/guilds``.
    open func onChannelDelete(channel: GuildChannel) async {}
    
    /// Dispatched when a message is pinned or unpinned in a text channel. This is not dispatched when a pinned message is deleted.
    /// - Parameters:
    ///   - channel: The channel the pin/unpin took place.
    ///   - pinnedAt: Time at which the most recent pinned message was pinned
    open func onChannelPinsUpdate(channel: GuildChannel, pinnedAt: Date?) async {}
    
    
    
    // MARK: Thread
    
    /// Dispatched when a thread is created.
    /// - Parameter thread: The thread that was created.
    /// - Requires: Intent ``Intents/guilds``.
    open func onThreadCreate(thread: ThreadChannel) async {}
    
    /// Dispatched when a thread is updated.
    /// - Parameters:
    ///   - before: The thread before the update.
    ///   - after: The thread after the update.
    /// - Requires: Intent ``Intents/guilds``.
    open func onThreadUpdate(before: ThreadChannel, after: ThreadChannel) async {}
    
    /// Dispatched when a thread is updated.
    ///
    /// The following are details of what `payload` contains:
    /// - `id`: The ID of the thread.
    /// - `guildId`: Guild ID of the thread.
    /// - `memberCount`: Approximate number of members in the thread, capped at 50.
    /// - `data`: The raw json data.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildMembers``.
    open func onRawThreadUpdate(payload: (id: Snowflake, guildId: Snowflake, memberCount: Int, data: [String: Any])) async {}
    
    /// Dispatched when a thread is deleted. This will not be dispacthed if the thread is not found in the bots internal cache. If this occurs, use ``onRawThreadDelete(payload:)`` instead.
    /// - Parameter thread: The thread that was deleted.
    /// - Requires: Intent ``Intents/guilds``.
    open func onThreadDelete(thread: ThreadChannel) async {}
    
    /// Dispatched when a thread is deleted. Unlike ``onThreadDelete(thread:)``, this is dispatched regardless of if the thread was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `id`: The ID of the thread.
    /// - `guildId`: Guild ID of the thread.
    /// - `parentId`: The ID of the channel hosting the thread.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guilds``.
    open func onRawThreadDelete(payload: (id: Snowflake, guildId: Snowflake, parentId: Snowflake)) async {}
    
    /// Dispatched when someone is added to a thread.
    /// - Parameter member: The member who was added.
    open func onThreadMemberAdd(member: ThreadChannel.ThreadMember) async {}
    
    /// Dispatched when member(s) are removed from a thread.
    /// - Parameter ids: The IDs of the members who were removed/left the thread.
    open func onRawThreadMemberRemove(ids: [Snowflake]) async {}
    
    /// Dispatched when the bot *gains* access to a channel.
    /// - Parameter threads: All active threads in the given channels that the bot can now access.
    open func onThreadListSync(threads: [ThreadChannel]) async {}
    
    
    
    // MARK: Guild
    
    /// Dispatched when a guild is created or when the bot joins a guild.
    /// - Parameter guild: The guild that was created.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildCreate(guild: Guild) async {}
    
    /// Dispatched when a guild is updated. For example, if the guild name or description was changed, etc.
    /// - Parameter guild: The guild that was updated.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildUpdate(guild: Guild) async {}
    
    /// Dispatched when the bot got banned, kicked, left the guild, or the guild owner deleted the guild.
    /// - Parameter guild: The guild that was deleted.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildDelete(guild: Guild) async {}
    
    /// Dispatched when a guild becomes available.
    /// - Parameter guild: The guild that is now available.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildAvailable(guild: Guild) async {}
    
    /// Dispatched when a guild becomes unavailable.
    /// - Parameter guild: The guild that is now unavailable.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildUnavailable(guild: Guild) async {}
    
    /// Dispatched when a guilds integration was updated.
    /// - Parameter guild: The guild the integration update took place.
    open func onGuildIntegrationUpdate(guild: Guild) async {}
    
    /// Dispatched when a user is banned from a guild.
    /// - Parameters:
    ///   - guild: The guild the user was banned from.
    ///   - user: User who was banned.
    /// - Requires: Intent ``Intents/guildModeration``.
    open func onGuildBan(guild: Guild, user: User) async {}
    
    /// Dispatched when a user is unbanned from a guild.
    /// - Parameters:
    ///   - guild: The guild the user was unbanned from.
    ///   - user: User who was unbanned.
    /// - Requires: Intent ``Intents/guildModeration``.
    open func onGuildUnban(guild: Guild, user: User) async {}
    
    /// Dispatched when guild emojis are updated.
    /// - Parameters:
    ///   - before: All emojis before the update.
    ///   - after: All emojis after the update.
    /// - Requires: Intent ``Intents/guildEmojisAndStickers``.
    open func onGuildEmojisUpdate(before: Set<Emoji>, after: Set<Emoji>) async {}
    
    /// Dispatched when guild stickers are updated.
    /// - Parameters:
    ///   - before: All stickers before the update.
    ///   - after: All stickers after the update.
    /// - Requires: Intent ``Intents/guildEmojisAndStickers``.
    open func onGuildStickersUpdate(before: [GuildSticker], after: [GuildSticker]) async {}
    
    
    
    // MARK: Member
    
    /// Dispatched when a member joins a guild.
    /// - Parameter member: The member who joined.
    /// - Requires: Intent ``Intents/guildMembers``.
    open func onGuildMemberJoin(member: Member) async {}
    
    /// Dispatched when a member leaves a guild. This will not be dispatched if the member was
    /// not found in the bots internal cache. If this occurs, use ``onRawGuildMemberRemove(payload:)`` instead.
    /// - Parameter member: The member that left.
    /// - Requires: Intent ``Intents/guildMembers``.
    open func onGuildMemberRemove(member: Member) async {}
    
    /// Dispatched when a member leaves a guild. Unlike ``onGuildMemberRemove(member:)``, this is dispatched regardless of if the member was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `guildId`: Guild ID of the member who left.
    /// - `user`: The user who left.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildMembers``.
    open func onRawGuildMemberRemove(payload: (guildId: Snowflake, user: User)) async {}
    
    /// Dispatched when a guild member is updated.
    /// - Parameters:
    ///   - before: The member before the update.
    ///   - after: The member after the update.
    /// - Requires: Intent ``Intents/guildMembers``.
    open func onGuildMemberUpdate(before: Member, after: Member) async {}
    
    
    
    // MARK: Role
    
    /// Dispatched when a role is created.
    /// - Parameter role: The role that was created.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildRoleCreate(role: Role) async {}
    
    /// Dispatched when a role is updated.
    /// - Parameters:
    ///   - before: The role before it was updated.
    ///   - after: The role after it was updated.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildRoleUpdate(before: Role, after: Role) async {}
    
    /// Dispatched when a role is deleted.
    /// - Parameter role: The role that was deleted.
    /// - Requires: Intent ``Intents/guilds``.
    open func onGuildRoleDelete(role: Role) async {}
    
    
    
    // MARK: Scheduled Event
    
    /// Dispatched when a scheduled event is created.
    /// - Parameter event: The event that was created.
    /// - Requires: Intent ``Intents/guildScheduledEvents``.
    open func onGuildScheduledEventCreate(event: Guild.ScheduledEvent) async {}
    
    /// Dispatched when a scheduled event is updated.
    /// - Parameters:
    ///   - before: The scheduled event before it was updated.
    ///   - after: The scheduled event after it was updated.
    /// - Requires: Intent ``Intents/guildScheduledEvents``.
    open func onGuildScheduledEventUpdate(before: Guild.ScheduledEvent, after: Guild.ScheduledEvent) async {}
    
    /// Dispatched when a scheduled event is deleted.
    /// - Parameter event: The event that was deleted.
    /// - Note: This requires intent ``Intents/guildScheduledEvents``.
    open func onGuildScheduledEventDelete(event: Guild.ScheduledEvent) async {}
    
    /// Dispatched when a user has subscribed to a guild scheduled event.
    /// - Parameters:
    ///   - event: The scheduled event the user subscriber to.
    ///   - user: The user who subscribed to the scheduled event.
    /// - Requires: Intent ``Intents/guildScheduledEvents``.
    open func onGuildScheduledEventUserAdd(event: Guild.ScheduledEvent, user: User) async {}
    
    /// Dispatched when a user has un-subscribed from a guild scheduled event.
    /// - Parameters:
    ///   - event: The scheduled event the user un-subscribed from.
    ///   - user: The user who un-subscribed from the scheduled event.
    /// - Requires: Intent ``Intents/guildScheduledEvents``.
    open func onGuildScheduledEventUserRemove(event: Guild.ScheduledEvent, user: User) async {}
    
    
    
    // MARK: Integration
    
    /// Dispatched when an integration is created.
    /// - Parameter integration: The integration that was created.
    open func onIntegrationCreate(integration: Guild.Integration) async {}
    
    /// Dispatched when an integration is updated.
    /// - Parameter integration: The integration that was updated.
    open func onIntegrationUpdate(integration: Guild.Integration) async {}
    
    /// Dispatched when an integration is deleted.
    /// - Parameter integration: The raw event payload information.
    open func onIntegrationDelete(payload: (id: Snowflake, guildId: Snowflake, applicationId: Snowflake)) async {}
    
    
    
    // MARK: Invite
    
    /// Dispatched when an invite is created.
    /// - Parameter invite: The invite that was created.
    /// - Requires: Intent ``Intents/guildInvites``.
    open func onInviteCreate(invite: Invite) async {}
    
    /// Dispatched when an invite is deleted.
    ///
    /// The following are details of what `payload` contains:
    /// - `channelId`: Channel ID of the invite.
    /// - `guildId`: Guild ID of the invite.
    /// - `code`: The invites code.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildInvites``.
    open func onRawInviteDelete(payload: (channelId: Snowflake, guildId: Snowflake?, code: String)) async {}
    
    
    
    // MARK: Messages
    
    /// Dispatched when a message is sent.
    /// - Parameter message: The message that was sent.
    /// - Requires: Intent ``Intents/dmMessages`` and or ``Intents/guildMessages``.
    open func onMessageCreate(message: Message) async {}
    
    /// Dispatched when a message is updated.
    ///
    /// The following are details of what `payload` contains:
    /// - `cachedMessage`: The message that was updated. Will be `nil` if the message was not found in the bots internal cache.
    /// - `guildId`: The guild ID the message belongs to. Will be `nil` if it's a DM.
    /// - `channelId`: The channel ID the message was sent in.
    /// - `data`: Raw information related to the message update.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/dmMessages`` and or ``Intents/guildMessages``.
    open func onRawMessageUpdate(payload: (cachedMessage: Message?, guildId: Snowflake?, channelId: Snowflake, data: [String: Any])) async {}
    
    
    /// Dispatched when a message is deleted. This will not be dispatched if the message is not found in the bots internal cache. If this occurs,
    /// use ``onRawMessageDelete(payload:)`` instead or increase the maximum message cache size.
    /// - Parameter message: The mesage that was deleted.
    /// - Requires: Intent ``Intents/dmMessages`` and or ``Intents/guildMessages``.
    open func onMessageDelete(message: Message) async {}
    
    /// Dispatched when a message is deleted. Unlike ``onMessageDelete(message:)``, this is dispatched regardless of if the message was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `messageId`: The ID of the message that was deleted.
    /// - `channelId`: The ID the channel the message was sent in.
    /// - `guildId`: The guild ID the message belongs to. Will be `nil` if it's a DM.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/dmMessages`` and or ``Intents/guildMessages``.
    open func onRawMessageDelete(payload: (messageId: Snowflake, channelId: Snowflake, guildId: Snowflake?)) async {}
    
    /// Dispatched when messages are bulk deleted. If there's at least one message that was found in the bots internal cache at the time of deletion this will be called. If no
    /// messages were found, this will not be called. If this occurs, use ``onRawMessageDeleteBulk(payload:)`` or increase the the maximum message cache size.
    /// - Parameter messages: The messages that were deleted.
    /// - Requires: Intent ``Intents/dmMessages`` and or ``Intents/guildMessages``.
    open func onMessageDeleteBulk(messages: [Message]) async {}
    
    /// Dispatched when messages are bulk deleted. Unlike ``onMessageDeleteBulk(messages:)``, this is dispatched regardless of if the messages were found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `messageIds`: The IDs of the messages that were deleted.
    /// - `channelId`: The channel ID the messages were deleted from.
    /// - `guildId`: The guild ID the messages that were deleted. Will be `nil` if it's a DM.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/dmMessages`` and or ``Intents/guildMessages``.
    open func onRawMessageDeleteBulk(payload: (messageIds: [Snowflake], channelId: Snowflake, guildId: Snowflake?)) async {}
    
    /// Dispatched when a reaction is added to a message.
    /// - Parameters:
    ///   - reaction: The reaction that was added.
    ///   - user: The user who added the reaction.
    /// - Requires: Intent ``Intents/guildMessageReactions`` and or ``Intents/dmReactions``.
    open func onMessageReactionAdd(reaction: Reaction, user: User) async {}
    
    /// Dispatched when a reaction is added to a message. Unlike ``onMessageReactionAdd(reaction:user:)``, this is dispatched regardless of if the message was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `userId`: The ID of the user who reacted.
    /// - `channelId`: The channel ID of the message containing the reaction.
    /// - `messageId`: The ID of the message that was reacted to.
    /// - `emoji`: The emoji that was added.
    /// - `guildId`: The guild ID where the reaction took place. Will be `nil` if it's a DM.
    /// - `member`: The member who reacted to the message. Will be `nil` if it's a DM.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildMessageReactions`` and or ``Intents/dmReactions``.
    open func onRawMessageReactionAdd(payload: (userId: Snowflake, channelId: Snowflake, messageId: Snowflake, emoji: PartialEmoji, guildId: Snowflake?, member: Member?)) async {}
    
    /// Dispatched when a reaction is removed from a message.
    /// - Parameters:
    ///   - reaction: The reaction that was removed.
    ///   - user: The user who removed the reaction.
    /// - Requires: Intent ``Intents/guildMessageReactions`` and or ``Intents/dmReactions``.
    open func onMessageReactionRemove(reaction: Reaction, user: User) async {}
    
    /// Dispatched when a reaction is removed from a message. Unlike ``onMessageReactionRemove(reaction:user:)``, this is dispatched regardless of if the message was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `userId`: The ID of the user who reacted.
    /// - `channelId`: The channel ID of the message containing the reaction.
    /// - `messageId`: The ID of the message that the reaction was removed from.
    /// - `emoji`: The emoji that was removed.
    /// - `guildId`: The guild ID where the reaction took place. Will be `nil` if it's a DM.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildMessageReactions`` and or ``Intents/dmReactions``.
    open func onRawMessageReactionRemove(payload: (userId: Snowflake, channelId: Snowflake, messageId: Snowflake, emoji: PartialEmoji, guildId: Snowflake?)) async {}
    
    /// Dispatched when all reactions are removed from a message at once. Typically via ``Message/removeAllReactions(emoji:)``.
    /// - Parameters:
    ///   - message: The message that all reactions were removed from.
    ///   - reactions: The reactions that were removed.
    /// - Requires: Intent ``Intents/guildMessageReactions`` and or ``Intents/dmReactions``.
    open func onMessageReactionRemoveAll(message: Message, reactions: [Reaction]) async {}
    
    /// Dispatched when all reactions are removed from a message. Typically via ``Message/removeAllReactions(emoji:)``.
    /// Unlike ``onMessageReactionRemoveAll(message:reactions:)``, this is dispatched regardless of if the message was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `channelId`: The channel ID of the message containing the reaction.
    /// - `messageId`: The ID of the message that the reaction was removed from.
    /// - `guildId`: The guild ID where the reaction removal took place. Will be `nil` if it's a DM.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildMessageReactions`` and or ``Intents/dmReactions``.
    open func onRawMessageReactionRemoveAll(payload: (channelId: Snowflake, messageId: Snowflake, guildId: Snowflake?)) async {}
    
    /// Dispatched when all reactions for a specific emoji are removed from a message.
    /// - Parameters reaction: The specific reaction that was removed.
    open func onMessageReactionRemoveEmoji(reaction: Reaction) async {}
    
    /// Dispatched when all reactions for a specific emoji are removed from a message.  Unlike ``onMessageReactionRemoveEmoji(reaction:)``,
    /// this is dispatched regardless of if the message was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `channelId`: The channel ID of the message containing the reaction that was removed.
    /// - `messageId`: The ID of the message that the reaction was removed from.
    /// - `emoji`: The emoji that was removed.
    /// - `guildId`: The guild ID where the reaction removal took place. Will be `nil` if it's a DM.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildMessageReactions`` and or ``Intents/dmReactions``.
    open func onRawMessageReactionRemoveEmoji(payload: (channelId: Snowflake, messageId: Snowflake, emoji: PartialEmoji, guildId: Snowflake?)) async {}
    
    
    
    // MARK: Stage
    
    /// Dispatched when a stage is created (i.e. the Stage is now "live").
    /// - Parameter instance: The stage that was created.
    open func onStageInstanceCreate(stageInstance: StageInstance) async {}
    
    /// Dispatched when a stage is deleted (i.e. the Stage has been closed).
    /// - Parameter instance: The stage that was deleted
    open func onStageInstanceDelete(stageInstance: StageInstance) async {}
    
    /// Dispatched when a stage is updated.
    /// - Parameter before: The stage instance before it was updated.
    /// - Parameter after: The stage instance after it was updated.
    open func onStageInstanceUpdate(before: StageInstance, after: StageInstance) async {}
    
    
    
    // MARK: Typing
    
    /// Dispatched when a user starts typing. If the channel is not found in the bots internal cache, this will not be called. Consider user ``onRawTypingStart(payload:)`` instead if this occurs.
    /// - Parameters:
    ///   - by: The user who started typing. Will be of type ``Member`` if this happened in a guild, or ``User`` if in a DM.
    ///   - at: When the user started typing.
    ///   - channel: The channel the user started typing in.
    /// - Requires: Intent ``Intents/guildMessageTyping`` and or ``Intents/dmTyping``.
    open func onTypingStart(by: Object, at: Date, in channel: Messageable) async {}
    
    /// Dispatched when a user starts typing. Unlike ``onTypingStart(by:at:in:)``, this is dispatched regardless of if the channel and user was found in the bots internal cache.
    ///
    /// The following are details of what `payload` contains:
    /// - `channelId`: The channel ID of the typing.
    /// - `guildId`: The guild D of the typing. Will be `nil` if the typing took place in a DM.
    /// - `userId`: The user ID for the user that started typing.
    /// - `timestamp`: When the user started typing.
    /// - `member`: The member object for the user that started typing. Will be `nil` if the typing took place in a DM.
    ///
    /// - Parameter payload: The raw event payload information.
    /// - Requires: Intent ``Intents/guildMessageTyping`` and or ``Intents/dmTyping``.
    open func onRawTypingStart(payload: (channelId: Snowflake, guildId: Snowflake?, userId: Snowflake, timestamp: Date, member: Member?)) async {}
    
    
    
    // MARK: Presence (user)
    
    // NOTE: This is really a presence update, but using "user update" makes more sense.
    /// Dispatched when a user is updated. Things such as their avatar, username, etc.
    /// - Parameter user: The updated user.
    open func onUserUpdate(user: User) async {}
    
    
    
    // MARK: Presence
    
    /// Dispatched when a users presence is updated.
    /// - Parameters:
    ///   - user: The user who's presence was updated.
    ///   - status: The users updated status.
    ///   - activities: The users updated activity. Will be `nil` if no activity was updated.
    /// - Requires: Intent ``Intents/guildPresences``.
    open func onPresenceUpdate(user: User, status: User.Status, activities: [User.Activity]?) async {}
    
    
    
    // MARK: Voice
    
    /// Dispatched when someone joins/leaves/moves voice channels.
    /// - Parameter voiceState: The updated voice state.
    open func onVoiceStateUpdate(voiceState: VoiceChannel.State) async {}
    
    /// Dispatched when a guild's voice server is updated. This is sent when initially connecting to voice, and when the current voice instance fails over to a new server.
    /// - Parameters:
    ///   - token: Voice connection token.
    ///   - guildId: Guild this voice server update is for.
    ///   - endpoint: Voice server host.
    open func onVoiceServerUpdate(token: String, guildId: Snowflake, endpoint: String?) async {}
    
    
    
    // MARK: Webhook
    
    /// Dispatched when a guild channel's webhook is created, updated, or deleted.
    /// - Parameter channel: The channel the webhook belongs to.
    open func onWebhooksUpdate(channel: GuildChannel) async {}
    
    
    
    // MARK: Interaction
    
    /// Dispatched when an interaction is created.
    /// - Parameter interaction: The interaction that was created.
    open func onInteractionCreate(interaction: Interaction) async {}
}
