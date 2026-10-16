MH = MH or {}
MH.Data = {}

MH.Data.StartingCash = 100
MH.Data.StartingServerPrice = 1000

MH.Data.BtcBuyRate = 81650
MH.Data.BtcSellRate = 81624

function MH.Data.FmtCash(n)
    n = math.floor(tonumber(n) or 0)
    local neg = n < 0
    local str = tostring(math.abs(n))
    local out = ""
    local count = 0
    for i = #str, 1, -1 do
        out = string.sub(str, i, i) .. out
        count = count + 1
        if count % 3 == 0 and i > 1 then out = "," .. out end
    end
    return (neg and "-" or "") .. out
end

MH.Data.Certs = {
    {
        level = 1, name = "Basic tutorial", price = 0,
        briefing = [[Welcome to MetaHacker. Read this once and the rest of the menus will make more sense.

Your rig
    Your server is the server you are currently using in the world. Everything you own, every program you install, every file you store, lives on it. If someone else hacks it, they can see what is on it. Keep that in mind.

The OS menus
    Home        A snapshot of your cash, bitcoin, reputation and certification level.
    Task Manager   Every running process - scans, cracks, research, log edits. Pause, resume, cancel, or fast-finish from here.
    Software    Files on your disk. You can research new versions, install, uninstall, hide, seek, rename, or delete each one.
    Internet    Your browser. Point it at an IP, log in, and interact with that remote machine.
    Log File    Every machine keeps a log. Yours too. You can edit it or wipe it to cover your tracks.
    Hardware    Buy upgrades for the server you are looking at, buy a new server, or mount an external drive.
    University  This page. The gate for everything else.
    Finances    Cash, bitcoin, bank accounts, transfers, exchange rates.
    Hacked Database   Everyone you have cracked and every bank credential you have captured. Install viruses, siphon accounts, collect earnings.
    Missions    Contracts for cash and reputation. Read the briefing before accepting.
    Mail        Send and Recieve mail.

Press Complete at the bottom to acknowledge and finish this certification.]],
    },
    {
        level = 2, name = "Hacking 101", price = 0,
        briefing = [[Hacking in MetaHacker is a race between two programs:

Cracker (your attacker)     vs     Hasher (defender)

The attacker runs a Cracker at some version. The target has a Hasher. The higher your Cracker, the faster you compromise the target. The higher their Hasher, the longer it takes you.

Steps:
1. Open Internet, type the target IP, press Go.
2. If you do not have the password, click Bruteforce (or Exploit, if you have the right software and ammo). A hack process starts. Watch it in Task Manager.
3. When it completes, the password is captured into your Hacked Database. Come back to Internet, Login with the password, and you are in.
4. Once in, you can read and edit the target's log, browse its software, and install your viruses on it.

Tip:
    The first thing an attacker should do after logging in is edit the log file. Your handle shows up in there. Wipe it or edit it before you leave.

This cert unlocks the Internet tab for real work. Press Complete to acknowledge.]],
    },
    {
        level = 3, name = "Intermediate hacking", price = 50,
        briefing = [[Intermediate techniques:

Exploits
    Instead of a straight Bruteforce, you can use an Exploit against the target's firewall. Exploits are faster but require you to own the exploit software at a version equal or higher than the firewall. FTP Exploit and SSH Exploit are the two usual starters.

Hidden files
    Hidden files on a target do not appear in the Softwares panel until you run a Seek against them. You can Hide your own files for the same reason - make them harder to find after you plant them.

Processes
    Every meaningful action is a process. Processes consume CPU budget. If your rig is overloaded, pause one, run the urgent one, resume the rest. Fast-finish is reserved for genuine emergencies.

Press Complete to acknowledge.]],
    },
    {
        level = 4, name = "Advanced hacking", price = 200,
        briefing = [[Advanced work:

Viruses
    Install Spam, Warez, or Bitcoin Miner viruses on machines you have compromised. They sit on the victim and generate cash or BTC over time. Collect from the Hacked Database tab.

    Spam uses victim CPU. Warez uses victim NET and needs a Torrent installed. Miner uses CPU and credits BTC to your wallet.

Virus Collector
    If you own a Virus Collector, your collect yield is multiplied. Only your highest version counts.

Bank hacking
    Hacking a bank's own server (not just an account) captures one of its accounts into your Hacked Database automatically. From there you can siphon the balance into your wallet. Expect Sourcenet to notice transfers above the audit threshold.

Press Complete to acknowledge.]],
    },
    {
        level = 5, name = "DDoS security", price = 500,
        briefing = [[Distributed denial of service:

To launch a DDoS you need at least three active DDoS viruses planted across different victims. Each contributes power. Total power at launch time decides damage per round. An attack runs four rounds.

Defense:
    DDoS Breaker reduces incoming DDoS damage. Install it on servers you want to protect.

With this certification you have everything the game allows. From here on, your limits are hardware, patience, and whether the FBI knocks on your door first.

Press Complete to finish.]],
    },
}

MH.Data.Hardware = {
    cpu = {
        { name = "Commander 64", mhz = 500, price = 99 },
        { name = "Potato", mhz = 1000, price = 99 },
        { name = "Toaster", mhz = 1500, price = 150 },
        { name = "Calculator", mhz = 2000, price = 300 },
        { name = "Dual Core", mhz = 2500, price = 600 },
        { name = "Quad Core", mhz = 3000, price = 1500 },
        { name = "AMD SX 8350", mhz = 3500, price = 2000 },
        { name = "i7 7700K", mhz = 4000, price = 5000 },
        { name = "i9 13990X", mhz = 5000, price = 12000 },
        { name = "Ryzen 9 7950X", mhz = 6000, price = 30000 },
        { name = "Threadwrecker 8900X3D", mhz = 7000, price = 75000 },
        { name = "Epic Hyperion 9900XXX", mhz = 8000, price = 200000 },
    },
    ram = {
        { name = "Alzheimer", mb = 256, price = 100 },
        { name = "Goldfish", mb = 512, price = 99 },
        { name = "Summit", mb = 1024, price = 500 },
        { name = "Raspboori", mb = 2048, price = 2500 },
        { name = "Temu", mb = 4096, price = 6000 },
        { name = "Chonker", mb = 8192, price = 15000 },
        { name = "Tarbov", mb = 16384, price = 40000 },
        { name = "Gamer", mb = 32768, price = 100000 },
        { name = "Nuck Chorris", mb = 65536, price = 250000 },
    },
    hdd = {
        { name = "Grandpa 100M", mb = 100, price = 99 },
        { name = "Grandpa 500M", mb = 500, price = 99 },
        { name = "SSD 1G", mb = 1000, price = 300 },
        { name = "SSD 2G", mb = 2000, price = 1000 },
        { name = "SSD 5G", mb = 5000, price = 3000 },
        { name = "SSD 10G", mb = 10000, price = 8000 },
        { name = "SSD 100G", mb = 100000, price = 120000 },
    },
    net = {
        { name = "NET1", mbps = 1, price = 100 },
        { name = "NET2", mbps = 2, price = 50 },
        { name = "NET4", mbps = 4, price = 99 },
        { name = "MEGA10", mbps = 10, price = 250 },
        { name = "MEGA25", mbps = 25, price = 1000 },
        { name = "MEGA50", mbps = 50, price = 2500 },
        { name = "BROAD100", mbps = 100, price = 10000 },
        { name = "BROAD250", mbps = 250, price = 25000 },
        { name = "ULTRA500", mbps = 500, price = 50000 },
        { name = "ULTRA1000", mbps = 1000, price = 100000 },
    },
}

MH.Data.Puzzles = {
    { id = 1,  kind = "tictactoe",   name = "Tic Tac Toe", question = "Beat the house. Play O. Win a round and the terminal unlocks." },
    { id = 2,  kind = "qa", question = "Decode: 68 61 63 6b", hint = "Each pair of hex digits is one ASCII character." },
    { id = 3,  kind = "qa", question = "SSH listens on port 22. Write that port in binary.", hint = "22 in base 2." },
    { id = 4,  kind = "qa", question = "What single word (four letters) is a Unix command that prints its arguments AND a sound reflected off a surface?" },
    { id = 5,  kind = "lightsout",   name = "Lights Out",  question = "Turn off every light. Clicking a cell toggles it and its four neighbors." },
    { id = 6,  kind = "qa", question = "I move through wires but am not electricity. I carry speech but have no mouth. What am I?" },
    { id = 7,  kind = "qa", question = "Two processes share the same CPU. Solo times: 30s and 20s. Running both at once with equal slices, how long before both finish?", hint = "The shorter one finishes first, then the longer runs solo for the remainder." },
    { id = 8,  kind = "qa", question = "What is the default port for HTTPS?" },
    { id = 9,  kind = "qa", question = "In base 10, what is 0x1F?" },
    { id = 10, kind = "qa", question = "Convert the binary 1010 to base 10." },
    { id = 11, kind = "memsequence", name = "Memory Sequence", question = "Watch the sequence and repeat it. Grow it to length 6 to clear." },
    { id = 12, kind = "qa", question = "What is the first prime number greater than 20?" },
    { id = 13, kind = "qa", question = "How many bytes in a 32-bit word?" },
    { id = 14, kind = "qa", question = "What port does DNS use?" },
    { id = 15, kind = "qa", question = "The square root of 196." },
    { id = 16, kind = "qa", question = "Decode base64: aGFjaw==" },
    { id = 17, kind = "qa", question = "Hex 'DEAD' as decimal." },
    { id = 18, kind = "qa", question = "A programmer walks into a bar, orders 1 beer, 2 beers, 4 beers, 8 beers... what's the next number?" },
    { id = 19, kind = "qa", question = "What is 2 to the 10th power?" },
    { id = 20, kind = "qa", question = "What Linux file lists mounted filesystems?" },
    { id = 21, kind = "tictactoe",   name = "Tic Tac Toe", question = "Round two. Play O again." },
    { id = 22, kind = "qa", question = "0xFF in binary." },
    { id = 23, kind = "qa", question = "What classic hash function was broken by the SHAttered collision in 2017?" },
    { id = 24, kind = "qa", question = "The year ARPANET sent its first message." },
    { id = 25, kind = "qa", question = "What command prints the current working directory on Linux?" },
    { id = 26, kind = "qa", question = "How many bits in a nibble?" },
    { id = 27, kind = "qa", question = "What port is used by SMTP by default?" },
    { id = 28, kind = "qa", question = "Convert 1 KiB to bytes." },
    { id = 29, kind = "qa", question = "Three sockets listening on 80, 443, 22. Which one is HTTP?" },
    { id = 30, kind = "lightsout",   name = "Lights Out",  question = "The grid again. Clear it." },
    { id = 31, kind = "qa", question = "What is the IP of localhost?" },
    { id = 32, kind = "qa", question = "Decode hex: 68 65 78" },
    { id = 33, kind = "qa", question = "0b1010 + 0b0101 in binary." },
    { id = 34, kind = "qa", question = "What encoding uses 64 characters to represent binary data as text?" },
    { id = 35, kind = "qa", question = "In cryptography, what does the C in CBC stand for?" },
    { id = 36, kind = "qa", question = "Reverse the string 'star' and type it." },
    { id = 37, kind = "qa", question = "What four-letter name is given to the loop count variable almost universally?" },
    { id = 38, kind = "memsequence", name = "Memory Sequence", question = "Final sequence. Length 6 to clear." },
    { id = 39, kind = "qa", question = "What TCP flag initiates a connection?" },
    { id = 40, kind = "qa", question = "The maximum value of an unsigned 8-bit integer." },
    { id = 41, kind = "qa", question = "What command in Linux kills a process by its PID?" },
    { id = 42, kind = "qa", question = "What is 7! (seven factorial)?" },
    { id = 43, kind = "qa", question = "What is the result of XOR between 0b1101 and 0b1011?" },
    { id = 44, kind = "qa", question = "What is the smallest Fibonacci number greater than 100?" },
    { id = 45, kind = "qa", question = "Which language's logo is a gopher?" },
    { id = 46, kind = "qa", question = "A trojan hides inside this common gift from Greek mythology." },
    { id = 47, kind = "tictactoe",   name = "The Final Puzzle", question = "Final round. Beat the house one last time." },
}

MH.Data.Soft = {
    [1]  = { name = "Cracker",         ext = ".crc",    research = 25 },
    [2]  = { name = "Hasher",          ext = ".pec",    research = 23 },
    [3]  = { name = "Port Scan",       ext = ".psc",    research = 15 },
    [4]  = { name = "Firewall",        ext = ".fwl",    research = 21 },
    [5]  = { name = "Hider",           ext = ".hdr",    research = 15 },
    [6]  = { name = "Seeker",          ext = ".skr",    research = 15 },
    [7]  = { name = "Antivirus",       ext = ".av",     research = 16 },
    [8]  = { name = "Spam virus",      ext = ".vspam",  research = 12 },
    [9]  = { name = "Warez virus",     ext = ".vwarez", research = 12 },
    [10] = { name = "DDoS virus",      ext = ".vddos",  research = 13 },
    [11] = { name = "Virus Collector", ext = ".vcol",   research = 14 },
    [12] = { name = "DDoS Breaker",    ext = ".vbrk",   research = 14 },
    [13] = { name = "FTP Exploit",     ext = ".exp",    research = 19 },
    [14] = { name = "SSH Exploit",     ext = ".exp",    research = 19 },
    [15] = { name = "Nmap",            ext = ".nmap",   research = 16 },
    [16] = { name = "Analyzer",        ext = ".anl",    research = 15 },
    [17] = { name = "Torrent",         ext = ".tor",    research = 15 },
    [18] = { name = "Web Server",      ext = ".web",    research = 15 },
    [19] = { name = "Bitcoin Wallet",  ext = ".btc",    research = 15 },
    [20] = { name = "Bitcoin Miner",   ext = ".vminer", research = 15 },
    [26] = { name = "Riddle",          ext = ".rdl",    research = 0  },
    [29] = { name = "Doom",            ext = ".doom",   research = 0  },
    [30] = { name = "Text",            ext = ".txt",    research = 0  },
    [31] = { name = "Folder",          ext = "",        research = 0  },
    [96] = { name = "Doom virus",      ext = ".vdoom",  research = 0  },
}

MH.Data.Rep = {
    LOGIN = 1,
    EDIT_LOG_LOCAL = 1,
    EDIT_LOG_REMOTE = 3,
    HACK_BASE = 50,
    CERT = 100,
    RESET_IP = 50,
    RESET_PASS = 15,
    PUZZLE = 25,
    ANALYZE = 15,
    DOOM = 10000,
}

function MH.Data.NextCpu(currentIdx)   return MH.Data.Hardware.cpu[currentIdx + 1] end
function MH.Data.NextRam(currentIdx)   return MH.Data.Hardware.ram[currentIdx + 1] end
function MH.Data.NextHdd(currentIdx)   return MH.Data.Hardware.hdd[currentIdx + 1] end
function MH.Data.NextNet(currentIdx)   return MH.Data.Hardware.net[currentIdx + 1] end

function MH.Data.LicenseFee(softType, softVersion)
    local v = tonumber(softVersion) or 1
    if v < 1 then v = 1 end
    local cte
    if v < 20 then cte = 10
    elseif v < 50 then cte = 40
    elseif v < 100 then cte = 60
    elseif v < 200 then cte = 80
    elseif v < 300 then cte = 110
    else cte = 150 end
    local multiplier = 1
    if softType == 29 then return 100000 end
    return v * cte * multiplier * 2
end

function MH.Data.ResearchCost(softType, currentVersion)
    local mult = (MH.Data.Soft[softType] or { research = 10 }).research
    local curV = tonumber(currentVersion) or 0
    local v = curV + 1
    if v < 1 then v = 1 end
    local price
    if v >= 100 then
        price = math.ceil(v * (mult * ((v - 90) / 100) - 10) + 3000 - (25 - mult) * 80)
    else
        price = math.ceil((v * v - 9 * v) / 100 * mult)
    end
    return math.max(1, price)
end

function MH.Data.DotVersion(v)
    v = tonumber(v) or 0
    if v <= 0 then return "0.0" end
    local minor = v % 10
    local major = (v - minor) / 10
    return major .. "." .. minor
end

function MH.Data.SoftName(softType)
    local s = MH.Data.Soft[softType]
    return s and s.name or ("Soft#" .. tostring(softType))
end

function MH.Data.PCPrice(totalOwned)
    if totalOwned <= 2 then return 10 ^ (totalOwned + 2) end
    if totalOwned == 3 then return 50000 end
    if totalOwned == 4 then return 100000 end
    return 500000
end

function MH.Data.ServerCPU(srv)
    local tier = MH.Data.Hardware.cpu[tonumber(srv and srv.cpu_tier) or 1] or MH.Data.Hardware.cpu[1]
    return tier.mhz or 500
end

function MH.Data.ServerNET(srv)
    local tier = MH.Data.Hardware.net[tonumber(srv and srv.net_tier) or 1] or MH.Data.Hardware.net[1]
    return tier.mbps or 1
end

MH.Data.Dur = {}

function MH.Data.Dur.delete(size, cpu, isLocal)
    local d = (tonumber(size) or 10) - (tonumber(cpu) or 500) / 50
    if isLocal then d = d * 0.5 end
    return math.max(10, math.floor(d))
end

function MH.Data.Dur.hide(size, cpu, isLocal)
    local d = math.floor((tonumber(size) or 10) * 1.5 - (tonumber(cpu) or 500) / 9)
    if isLocal then d = d * 0.5 end
    return math.max(4, d)
end

function MH.Data.Dur.seek(size, cpu, hiddenWithVer, isLocal)
    local base = math.floor((tonumber(size) or 10) * 1.5 - (tonumber(cpu) or 500) / 9) +
        math.max(0, (tonumber(hiddenWithVer or 10) - 10)) * 2
    if isLocal then base = base * 0.5 end
    return math.max(4, base)
end

function MH.Data.Dur.install(size, cpu, isLocal)
    local d = math.floor((tonumber(size) or 10) * 2 - (tonumber(cpu) or 500) / 9)
    if isLocal then d = d * 0.5 end
    return math.max(4, d)
end

function MH.Data.Dur.uninstall(size, cpu, isLocal)
    return math.max(4, math.floor(MH.Data.Dur.install(size, cpu, false) * 0.85 * (isLocal and 0.5 or 1)))
end

function MH.Data.Dur.research(nextVer)
    local v = tonumber(nextVer) or 1
    if v < 30 then return 280 + 20 * (v - 10) end
    if v < 50 then return 660 + 10 * (v - 29) end
    if v < 75 then return 900 end
    if v < 100 then return 1200 end
    if v < 150 then return 1500 end
    return 1800
end

function MH.Data.Dur.crack(crackerV, hasherV)
    hasherV = tonumber(hasherV) or 0
    crackerV = tonumber(crackerV) or 0
    if hasherV == 0 then return 4 end
    local diff = crackerV - hasherV
    if diff == 0 then
        if hasherV < 30 then return 30 end
        if hasherV < 50 then return 40 end
        if hasherV < 75 then return 50 end
        return 60
    end
    if diff == 1 then
        if hasherV < 30 then return 20 end
        if hasherV < 50 then return 30 end
        if hasherV < 75 then return 40 end
        return 50
    end
    if diff >= 20 then
        if hasherV < 30 then return 4 end
        if hasherV < 50 then return 10 end
        if hasherV < 75 then return 15 end
        return 30
    end
    return math.max(4, math.floor(diff + hasherV / math.max(1, diff)))
end

function MH.Data.Dur.edit_log(curLen, tmpLen, cpu, isLocal)
    local d = math.floor(math.max(tonumber(curLen) or 0, tonumber(tmpLen) or 0) / 20 - (tonumber(cpu) or 500) / 6)
    if isLocal then d = d * 0.5 end
    return math.min(60, math.max(4, d))
end

function MH.Data.Dur.download(size, attNet, tgtNet)
    local eff = math.max(1, math.min((tonumber(attNet) or 1) / 8, (tonumber(tgtNet) or 1) / 16))
    return math.max(3, math.floor((tonumber(size) or 10) / eff))
end

function MH.Data.Dur.upload(size, attNet, tgtNet)
    local eff = math.max(1, math.min((tonumber(attNet) or 1) / 16, (tonumber(tgtNet) or 1) / 8))
    return math.max(3, math.floor((tonumber(size) or 10) / eff))
end

function MH.Data.Dur.scan() return 30 end
function MH.Data.Dur.exploit() return 60 end
function MH.Data.Dur.av() return 200 end
