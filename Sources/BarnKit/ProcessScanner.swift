import AppKit
import Darwin

/// One row of the process table.
struct ProcInfo {
    var pid: pid_t
    var ppid: pid_t
    var uid: uid_t
    var comm: String
    var tty: String?
}

/// Finds agent CLIs in the process table. Not thread-safe: use from one queue.
final class ProcessScanner {
    struct Found {
        var pid: pid_t
        var kind: AgentKind
        var cwd: String
        var tty: String?
        var host: HostApp?
        /// CPU fraction of one core since the previous scan.
        var cpu: Double
        var ppid: pid_t = 0
    }

    private let uid = getuid()
    private static let interpreters: Set<String> = ["node", "bun", "deno", "python", "python3"]
    private var argsCache: [pid_t: (comm: String, args: [String])] = [:]
    private var hostCache: [pid_t: HostApp?] = [:]
    private var cpuSamples: [pid_t: (cpuNs: UInt64, at: UInt64)] = [:]
    private lazy var argBuffer = [UInt8](repeating: 0, count: Self.argMax())
    private let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    /// Kinds to look for; set from Settings (built-ins the user left on + custom ones).
    var kinds: [AgentKind] = AgentKind.builtIns

    /// pid → parent pid from the most recent scan.
    private(set) var parents: [pid_t: pid_t] = [:]

    /// `pid` itself or its nearest ancestor that is in `targets`.
    func nearest(_ pid: pid_t, in targets: Set<pid_t>) -> pid_t? {
        var cur = pid
        for _ in 0..<16 {
            if targets.contains(cur) { return cur }
            guard let parent = parents[cur], parent > 1 else { return nil }
            cur = parent
        }
        return nil
    }

    func scan() -> [Found] {
        let procs = Self.listProcesses()
        let byPID = Dictionary(procs.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        parents = byPID.mapValues(\.ppid)

        var matches: [pid_t: AgentKind] = [:]
        for p in procs where p.tty != nil && p.uid == uid {
            if let kind = classify(p) { matches[p.pid] = kind }
        }
        let live = Set(byPID.keys)
        argsCache = argsCache.filter { live.contains($0.key) }
        hostCache = hostCache.filter { live.contains($0.key) }
        cpuSamples = cpuSamples.filter { live.contains($0.key) }

        var found: [Found] = []
        for (pid, kind) in matches {
            // An agent launched through a wrapper (node → native binary) shows up
            // twice; keep the outermost process.
            if hasAncestor(pid, in: matches, byPID: byPID) { continue }
            guard let p = byPID[pid], let cwd = Self.cwd(of: pid) else { continue }
            found.append(Found(pid: pid, kind: kind, cwd: cwd, tty: p.tty,
                               host: host(for: pid, byPID: byPID), cpu: cpuFraction(pid), ppid: p.ppid))
        }
        return found
    }

    /// Describe a pid that wasn't matched by name (an IDE-launched Claude session, or anything
    /// that reports itself through ~/.barn/status).
    func describe(_ pid: pid_t, as kind: AgentKind) -> Found? {
        let byPID = Dictionary(Self.listProcesses().map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        guard let p = byPID[pid] else { return nil }
        return Found(pid: pid, kind: kind, cwd: Self.cwd(of: pid) ?? "", tty: p.tty,
                     host: host(for: pid, byPID: byPID), cpu: cpuFraction(pid), ppid: p.ppid)
    }

    // MARK: Classification

    private func classify(_ p: ProcInfo) -> AgentKind? {
        let args: [String]
        if let cached = argsCache[p.pid], cached.comm == p.comm {
            args = cached.args
        } else {
            args = arguments(of: p.pid) ?? []
            argsCache[p.pid] = (p.comm, args)
        }
        return Self.classify(args: args, kinds: kinds)
    }

    /// Match argv against agent kinds: argv[0]'s basename, or for interpreters (node, bun,
    /// python…) the script or module in the next few args (`node …/@openai/codex/bin/codex.js`,
    /// `python -m aider`).
    static func classify(args: [String], kinds: [AgentKind]) -> AgentKind? {
        guard let argv0 = args.first else { return nil }
        let exe = stem(argv0)
        if let kind = kinds.first(where: { $0.executableNames.contains(exe) }) {
            return kind
        }
        guard interpreters.contains(exe) || exe.hasPrefix("python3") else { return nil }
        for arg in args.dropFirst().prefix(3) {
            let s = stem(arg)
            if let kind = kinds.first(where: { $0.executableNames.contains(s) }) { return kind }
            if let kind = kinds.first(where: { k in k.packageFragments.contains { arg.contains($0) } }) {
                return kind
            }
        }
        return nil
    }

    private static func stem(_ path: String) -> String {
        var name = (path as NSString).lastPathComponent
        if name.hasPrefix("-") { name.removeFirst() } // login shells: "-zsh"
        for ext in [".js", ".mjs", ".cjs", ".ts"] where name.hasSuffix(ext) {
            name.removeLast(ext.count)
        }
        return name
    }

    private func hasAncestor(_ pid: pid_t, in matches: [pid_t: AgentKind], byPID: [pid_t: ProcInfo]) -> Bool {
        var cur = byPID[pid]?.ppid ?? 0
        var hops = 0
        while cur > 1, hops < 32 {
            if matches[cur] != nil { return true }
            cur = byPID[cur]?.ppid ?? 0
            hops += 1
        }
        return false
    }

    private func host(for pid: pid_t, byPID: [pid_t: ProcInfo]) -> HostApp? {
        if let cached = hostCache[pid] { return cached }
        var result: HostApp?
        var viaTmux = false
        var cur = byPID[pid]?.ppid ?? 0
        var hops = 0
        while cur > 1, hops < 32 {
            if byPID[cur]?.comm.hasPrefix("tmux") == true { viaTmux = true }
            if let app = NSRunningApplication(processIdentifier: cur), app.bundleIdentifier != nil {
                result = HostApp(bundleID: app.bundleIdentifier, name: app.localizedName ?? "App", pid: cur)
                break
            }
            cur = byPID[cur]?.ppid ?? 0
            hops += 1
        }
        if result == nil, viaTmux { result = HostApp(bundleID: nil, name: "tmux", pid: 0, viaTmux: true) }
        hostCache[pid] = result
        return result
    }

    // MARK: CPU

    private func cpuFraction(_ pid: pid_t) -> Double {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { return 0 }
        let ticks = info.pti_total_user + info.pti_total_system
        let cpuNs = ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC)
        defer { cpuSamples[pid] = (cpuNs, now) }
        guard let prev = cpuSamples[pid], now > prev.at, cpuNs >= prev.cpuNs else { return 0 }
        return Double(cpuNs - prev.cpuNs) / Double(now - prev.at)
    }

    // MARK: libproc / sysctl

    static func listProcesses() -> [ProcInfo] {
        // All users: terminal ancestry passes through root-owned `login`.
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [] }
        size += size / 4
        let stride = MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / stride)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }
        return procs.prefix(size / stride).map { kp in
            var comm = kp.kp_proc.p_comm
            let name = withUnsafePointer(to: &comm) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
            }
            let tdev = kp.kp_eproc.e_tdev
            var tty: String?
            if tdev != -1 { tty = ttyName(tdev) }
            return ProcInfo(pid: kp.kp_proc.p_pid, ppid: kp.kp_eproc.e_ppid, uid: kp.kp_eproc.e_ucred.cr_uid,
                            comm: name, tty: tty)
        }
    }

    /// devname() lstat-walks /dev on every call, so memoize per device number.
    private static var ttyNames: [dev_t: String] = [:]

    private static func ttyName(_ dev: dev_t) -> String? {
        if let name = ttyNames[dev] { return name }
        guard let dn = devname(dev, S_IFCHR) else { return nil }
        let name = "/dev/" + String(cString: dn)
        ttyNames[dev] = name
        return name
    }

    static func cwd(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return path.isEmpty ? nil : path
    }

    static func isAlive(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 || errno == EPERM }

    private static func argMax() -> Int {
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctl(&mib, 2, &value, &size, nil, 0) == 0 ? Int(value) : 256 * 1024
    }

    /// argv via KERN_PROCARGS2: [argc:int32][exec path\0][\0 padding][argv0\0][argv1\0]…
    private func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = argBuffer.count
        guard sysctl(&mib, 3, &argBuffer, &size, nil, 0) == 0, size > 4 else { return nil }
        let argc = argBuffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var i = 4
        while i < size, argBuffer[i] != 0 { i += 1 }
        while i < size, argBuffer[i] == 0 { i += 1 }
        var args: [String] = []
        while args.count < argc, i < size {
            let start = i
            while i < size, argBuffer[i] != 0 { i += 1 }
            args.append(String(decoding: argBuffer[start..<i], as: UTF8.self))
            i += 1
        }
        return args
    }
}
