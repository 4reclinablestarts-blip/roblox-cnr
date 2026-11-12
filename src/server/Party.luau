-- Parties of up to MAX_PARTY players, formed in the Motel. The leader takes the party into a raid.
-- shortcut: a party lives only in one Motel server and ends when its members leave it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local Party = {}

type PartyData = { leader: Player, members: { Player } }

local parties: { [Player]: PartyData } = {}
local invites: { [Player]: Player } = {} -- invitee -> who invited them

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function sendState(player: Player)
	local party = parties[player]
	local members = {}
	for _, member in party and party.members or {} do
		table.insert(members, { userId = member.UserId, name = member.DisplayName })
	end
	local inviter = invites[player]
	Remotes.PartyChanged:FireClient(player, {
		leader = party and party.leader.UserId,
		members = members,
		invitedBy = inviter and { userId = inviter.UserId, name = inviter.DisplayName },
	})
end

local function broadcast(party: PartyData)
	for _, member in party.members do
		sendState(member)
	end
end

function Party.of(player: Player): PartyData?
	return parties[player]
end

-- Who travels with this player: the whole party for its leader, else just them.
function Party.travellers(player: Player): ({ Player }, number?)
	local party = parties[player]
	if party and party.leader == player then
		return table.clone(party.members), player.UserId
	end
	return { player }, nil
end

function Party.leave(player: Player)
	local party = parties[player]
	if not party then
		return
	end
	parties[player] = nil
	table.remove(party.members, table.find(party.members, player))
	if #party.members <= 1 then
		for _, member in party.members do
			parties[member] = nil
			sendState(member)
		end
	else
		if party.leader == player then
			party.leader = party.members[1]
		end
		broadcast(party)
	end
	sendState(player)
end

local function invite(player: Player, target: Player)
	local party = parties[player]
	if party and party.leader ~= player then
		notify(player, "Only the party leader can invite.")
	elseif party and #party.members >= Config.MAX_PARTY then
		notify(player, `Parties are limited to {Config.MAX_PARTY} players.`)
	elseif parties[target] then
		notify(player, `{target.DisplayName} is already in a party.`)
	else
		invites[target] = player
		notify(target, `{player.DisplayName} invited you to a party. Press P to accept.`)
		sendState(target)
		notify(player, `Invited {target.DisplayName}.`)
	end
end

local function accept(player: Player)
	local inviter = invites[player]
	invites[player] = nil
	if not inviter or not inviter.Parent then
		sendState(player)
		return
	end
	Party.leave(player)
	local party = parties[inviter]
	if not party then
		party = { leader = inviter, members = { inviter } }
		parties[inviter] = party
	end
	if #party.members >= Config.MAX_PARTY then
		notify(player, "That party is full.")
		sendState(player)
		return
	end
	table.insert(party.members, player)
	parties[player] = party
	broadcast(party)
end

function Party.start()
	Remotes.Party.OnServerEvent:Connect(function(player, action, target)
		if action == "invite" and typeof(target) == "Instance" and target:IsA("Player") and target ~= player then
			invite(player, target)
		elseif action == "accept" then
			accept(player)
		elseif action == "leave" then
			Party.leave(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Party.leave(player)
		invites[player] = nil
	end)
end

return Party
