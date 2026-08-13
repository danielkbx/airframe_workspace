import AirframeContainer
import BlackboxAnalysis
import BlackboxReader
import CryptoKit
import Foundation

enum FixtureError: Error, CustomStringConvertible {
    case usage
    case invalidManifest(String)
    case missingEntry(String)
    case digestMismatch(String)

    var description: String {
        switch self {
        case .usage: return "usage: screenshot-fixtures build|validate <fixture-manifest.json> | inventory <document.airframe>"
        case let .invalidManifest(message): return "invalid fixture manifest: \(message)"
        case let .missingEntry(path): return "missing container entry: \(path)"
        case let .digestMismatch(path): return "digest mismatch: \(path)"
        }
    }
}

struct FixtureManifest: Decodable {
    let schemaVersion: Int
    let document: Document
    let sources: [Source]
    let logs: [Log]
    let presets: [Preset]
    let futureUIStates: [String: FutureUIState]

    struct Document: Decodable {
        let filename: String
        let displayName: String
        let createdAt: String
        let aircraftSettings: AircraftSettings
    }
    struct AircraftSettings: Decodable { let propellerSize: String; let motorLayout: String }
    struct Source: Decodable { let id: String; let path: String; let sha256: String; let publicationApproved: Bool }
    struct Log: Decodable {
        let source: String
        let sourceLogIndex: Int
        let segment: Int
        let displayName: String
        let roles: [String]
        let propellerSize: String?
    }
    struct Preset: Decodable { let id: String; let name: String; let file: String }
    struct FutureUIState: Decodable {
        let logRole: String
        let view: String
        let preset: String?
        let sidebar: Panel
        let inspector: Panel
        let timeline: Timeline?
        let graphViewport: RangeSpec?
        let spectrumFrequencyWindow: RangeSpec?
        let mapCamera: MapCamera?
        let scrollTarget: String?
        let sheet: String?
        let popover: String?
        let expandedSections: [String]
        let readyElements: [String]
    }
    struct Panel: Decodable { let visible: Bool; let width: Double }
    struct Timeline: Decodable { let startMicros: Int; let endMicros: Int; let cursorMicros: Int }
    struct RangeSpec: Decodable { let lowerFraction: Double; let upperFraction: Double }
    struct MapCamera: Decodable { let latitude: Double; let longitude: Double; let distanceMeters: Double; let pitchDegrees: Double; let headingDegrees: Double }
}

struct ContainerManifest: Codable {
    var format: String
    var formatVersion: Int
    var entries: [Entry]
    struct Entry: Codable {
        var path: String
        var kind: UInt32
        var byteCount: UInt64
        var sha256: String
        var originalFilename: String?
        var mimeType: String?
    }
}

struct DocumentMetadata: Codable {
    var format: String
    var formatVersion: Int
    var createdAt: String
    var modifiedAt: String
    var logs: [Log]
    var state: State
    var indexes: [JSONValue]
    var document: JSONValue
    var filenameTimestampSource: String
    var notes: String?
    var tags: [String]
    var flightControllerImports: [JSONValue]
    var configurations: [Configuration]

    struct Log: Codable {
        var path: String
        var originalFilename: String
        var byteCount: Int
        var sha256: String
        var metadata: JSONValue
        var settings: JSONValue
        var segmentNames: [String: String]
        var importSource: String?
    }
    struct State: Codable {
        var selectedLog: String
        var selectedView: String
        var values: [String: JSONValue]
        var logs: [String: JSONValue]
    }
    struct Configuration: Codable { var path: String; var byteCount: Int; var sha256: String }
}

enum JSONValue: Codable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .null: try c.encodeNil(); case let .bool(v): try c.encode(v); case let .number(v): try c.encode(v); case let .string(v): try c.encode(v); case let .array(v): try c.encode(v); case let .object(v): try c.encode(v) }
    }
}

struct OpenSource {
    let config: FixtureManifest.Source
    let reader: ContainerReader
    let manifest: ContainerManifest
    let metadata: DocumentMetadata
    let references: [String: ContainerBlobReference]
}

func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func text(_ value: Double?) -> String { value.map { String($0) } ?? "none" }

func aircraftSelection(_ value: String, overrides: [String: JSONValue] = [:]) -> JSONValue {
    var raw: [String: JSONValue] = ["v": .number(1), "d": .string(value)]
    if !overrides.isEmpty { raw["o"] = .object(overrides) }
    return .object(raw)
}

func filteredImport(_ value: JSONValue, retainedLogHashes: Set<String>, retainedConfigurationHashes: Set<String>) -> JSONValue? {
    guard case var .object(raw) = value, case let .array(logValues)? = raw["logHashes"] else { return nil }
    let hashes = logValues.compactMap { value -> String? in
        guard case let .string(hash) = value, retainedLogHashes.contains(hash) else { return nil }
        return hash
    }
    guard !hashes.isEmpty else { return nil }
    raw["logHashes"] = .array(hashes.sorted().map(JSONValue.string))
    if case let .string(hash)? = raw["configurationHash"], !retainedConfigurationHashes.contains(hash) {
        raw["configurationHash"] = .null
    }
    return .object(raw)
}

func loadFixtureManifest(_ path: String) throws -> (FixtureManifest, URL) {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let value = try JSONDecoder().decode(FixtureManifest.self, from: Data(contentsOf: url))
    guard value.schemaVersion == 1 else { throw FixtureError.invalidManifest("unsupported schemaVersion") }
    return (value, url.deletingLastPathComponent())
}

func openSource(_ source: FixtureManifest.Source, relativeTo root: URL) throws -> OpenSource {
    guard source.publicationApproved else { throw FixtureError.invalidManifest("source \(source.id) lacks publication approval") }
    let url = URL(fileURLWithPath: source.path, relativeTo: root).standardizedFileURL
    let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
    guard digest(bytes) == source.sha256 else { throw FixtureError.digestMismatch(source.path) }
    let reader = try ContainerReader(opening: url, limits: .init(maximumReadLength: 1 << 30))
    let manifest = try JSONDecoder().decode(ContainerManifest.self, from: reader.readMetadata())
    guard manifest.format == "com.kumkju.airframe.container-manifest", manifest.formatVersion == 1 else { throw FixtureError.invalidManifest(source.path) }
    let refs = reader.blobs.filter { $0.identifier != 1 }
    guard refs.count == manifest.entries.count else { throw FixtureError.invalidManifest("entry count for \(source.path)") }
    let references = Dictionary(uniqueKeysWithValues: zip(manifest.entries, refs).map { ($0.path, $1) })
    guard let metadataEntry = manifest.entries.first(where: { $0.path == "metadata.json" }), let metadataRef = references[metadataEntry.path] else { throw FixtureError.missingEntry("metadata.json") }
    let metadataData = try reader.read(metadataRef)
    guard digest(metadataData) == metadataEntry.sha256 else { throw FixtureError.digestMismatch(metadataEntry.path) }
    let metadata = try JSONDecoder().decode(DocumentMetadata.self, from: metadataData)
    return OpenSource(config: source, reader: reader, manifest: manifest, metadata: metadata, references: references)
}

func makePresetFiles(_ manifest: FixtureManifest, root: URL) throws {
    let presetRoot = root.appendingPathComponent("presets", isDirectory: true)
    try FileManager.default.createDirectory(at: presetRoot, withIntermediateDirectories: true)
    let timestamp = 1_788_739_200.0
    let defaultGraph: [String: Any] = ["v": 1, "g": [
        ["n": "Gyros", "s": ["reader:I:gyroADC[0]:25", "reader:I:gyroADC[1]:26", "reader:I:gyroADC[2]:27"], "c": ["reader:I:gyroADC[0]:25": 0, "reader:I:gyroADC[1]:26": 1, "reader:I:gyroADC[2]:27": 2]],
        ["n": "Setpoint", "s": ["reader:I:setpoint[0]:17", "reader:I:setpoint[1]:18", "reader:I:setpoint[2]:19"], "c": ["reader:I:setpoint[0]:17": 0, "reader:I:setpoint[1]:18": 1, "reader:I:setpoint[2]:19": 2]],
        ["n": "Motors", "s": ["reader:I:motor[0]:37", "reader:I:motor[1]:38", "reader:I:motor[2]:39", "reader:I:motor[3]:40"], "c": ["reader:I:motor[0]:37": 0, "reader:I:motor[1]:38": 1, "reader:I:motor[2]:39": 2, "reader:I:motor[3]:40": 3]]
    ], "t": []]
    let spectrum: [String: Any] = ["v": 4, "m": "frequencyVsRPM", "f": ["gyro", "gyroPrefilter"], "ft": ["gyro"], "fr": ["gyro", "gyroPrefilter"], "i": 120.0, "h": true, "o": ["dtermLPF1", "rpmNotch1", "rpmNotch2", "rpmNotch3"]]
    let map: [String: Any] = [
        "mapType": "standard", "followsCraftDuringPlayback": false, "showsCraftPreview": true, "showsHeading": true,
        "showsHomePoint": true, "showsEvents": true, "showsAltitudeInstrument": true, "showsSpeedInstrument": true,
        "showsHeadingInstrument": true, "showsAttitudeInstrument": true, "groundSpeedUnit": "kilometersPerHour", "timelineSource": "gpsAltitude"
    ]
    let response: [String: Any] = ["v": 6, "rc": "all", "qc": true, "sm": true, "frv": "response", "fgh": [], "frgh": []]
    for preset in manifest.presets {
        var settings: [String: Any] = [:]
        switch preset.name {
        case "Flight Review": settings = ["g": defaultGraph, "z": 2.0, "m": map]
        case "Control Response": settings = ["g": defaultGraph, "z": 5.0]
        case "Filter Analysis": settings = ["s": spectrum, "w": [0.0, 0.55]]
        case "CHIRP Analysis": settings = ["r": response]
        case "Flight Map": settings = ["m": map]
        default: throw FixtureError.invalidManifest("unknown preset \(preset.name)")
        }
        let archive: [String: Any] = ["format": "com.kumkju.airframe.presets", "version": 1, "presets": [["i": preset.id, "n": preset.name, "u": timestamp, "s": settings]]]
        let data = try JSONSerialization.data(withJSONObject: archive, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: root.appendingPathComponent(preset.file), options: .atomic)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard decoded?["format"] as? String == "com.kumkju.airframe.presets" else { throw FixtureError.invalidManifest(preset.file) }
    }
}

func build(_ manifestPath: String) throws {
    let (fixture, root) = try loadFixtureManifest(manifestPath)
    let sources = try Dictionary(uniqueKeysWithValues: fixture.sources.map { ($0.id, try openSource($0, relativeTo: root)) })
    var selectedBySource: [String: [FixtureManifest.Log]] = [:]
    for log in fixture.logs { selectedBySource[log.source, default: []].append(log) }
    var outputLogs: [DocumentMetadata.Log] = []
    var outputConfigurations: [DocumentMetadata.Configuration] = []
    var outputImports: [JSONValue] = []
    var payloads: [(String, ContainerBlobKind, Data)] = []
    var seenPaths = Set<String>()
    for sourceConfig in fixture.sources {
        guard let source = sources[sourceConfig.id], let selections = selectedBySource[sourceConfig.id] else { continue }
        for selection in selections {
            guard source.metadata.logs.indices.contains(selection.sourceLogIndex) else { throw FixtureError.invalidManifest("sourceLogIndex") }
            let descriptor = source.metadata.logs[selection.sourceLogIndex]
            if !seenPaths.contains(descriptor.path) {
                guard let reference = source.references[descriptor.path] else { throw FixtureError.missingEntry(descriptor.path) }
                let data = try source.reader.read(reference)
                guard digest(data) == descriptor.sha256 else { throw FixtureError.digestMismatch(descriptor.path) }
                var copy = descriptor
                copy.originalFilename = "Basher Flights." + URL(fileURLWithPath: descriptor.originalFilename).pathExtension.lowercased()
                copy.segmentNames = [:]
                outputLogs.append(copy)
                payloads.append((descriptor.path, .log, data))
                seenPaths.insert(descriptor.path)
            }
            guard let index = outputLogs.firstIndex(where: { $0.sha256 == descriptor.sha256 }) else { continue }
            outputLogs[index].segmentNames[String(selection.segment)] = selection.displayName
        }
        for descriptor in source.metadata.configurations where !seenPaths.contains(descriptor.path) {
            guard let reference = source.references[descriptor.path] else { throw FixtureError.missingEntry(descriptor.path) }
            let data = try source.reader.read(reference)
            guard digest(data) == descriptor.sha256 else { throw FixtureError.digestMismatch(descriptor.path) }
            outputConfigurations.append(descriptor)
            payloads.append((descriptor.path, .configuration, data))
            seenPaths.insert(descriptor.path)
        }
        let retainedLogs = Set(selections.map { source.metadata.logs[$0.sourceLogIndex].sha256 })
        let retainedConfigurations = Set(outputConfigurations.map(\.sha256))
        outputImports.append(contentsOf: source.metadata.flightControllerImports.compactMap {
            filteredImport($0, retainedLogHashes: retainedLogs, retainedConfigurationHashes: retainedConfigurations)
        })
    }
    guard !outputLogs.isEmpty else { throw FixtureError.invalidManifest("no logs") }
    let created = fixture.document.createdAt
    let selected = fixture.logs[0]
    guard let firstDescriptor = outputLogs.first(where: { sources[selected.source]?.metadata.logs[selected.sourceLogIndex].sha256 == $0.sha256 }) else { throw FixtureError.invalidManifest("selected log") }
    let propellerOverrides = Dictionary(uniqueKeysWithValues: fixture.logs.compactMap { log -> (String, JSONValue)? in
        guard let propellerSize = log.propellerSize, let source = sources[log.source], source.metadata.logs.indices.contains(log.sourceLogIndex) else { return nil }
        let descriptor = source.metadata.logs[log.sourceLogIndex]
        return ("source:\(descriptor.sha256):\(log.segment)", .string(propellerSize))
    })
    let metadata = DocumentMetadata(
        format: "com.kumkju.airframe.document", formatVersion: 2, createdAt: created, modifiedAt: created,
        logs: outputLogs,
        state: .init(
            selectedLog: "source:\(firstDescriptor.sha256):\(selected.segment)", selectedView: "overview",
            values: [
                "aircraftPropellerSizes": aircraftSelection(fixture.document.aircraftSettings.propellerSize, overrides: propellerOverrides),
                "aircraftMotorLayouts": aircraftSelection(fixture.document.aircraftSettings.motorLayout),
            ],
            logs: [:]
        ),
        indexes: [], document: .object([:]), filenameTimestampSource: "systemAtImport", notes: nil,
        tags: ["Screenshot Fixture"], flightControllerImports: outputImports, configurations: outputConfigurations
    )
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let metadataData = try encoder.encode(metadata)
    payloads.append(("metadata.json", .metadata, metadataData))
    let entries = payloads.map { ContainerManifest.Entry(path: $0.0, kind: $0.1.rawValue, byteCount: UInt64($0.2.count), sha256: digest($0.2), originalFilename: nil, mimeType: nil) }.sorted { $0.path < $1.path }
    let containerManifest = ContainerManifest(format: "com.kumkju.airframe.container-manifest", formatVersion: 1, entries: entries)
    let manifestData = try JSONEncoder().encode(containerManifest)
    let ordered = payloads.sorted { $0.0 < $1.0 }.map { ContainerBlob(kind: $0.1, data: $0.2) }
    let destination = root.appendingPathComponent(fixture.document.filename)
    let temporary = root.appendingPathComponent(".\(fixture.document.filename).tmp")
    try? FileManager.default.removeItem(at: temporary)
    _ = try ContainerWriter.write(to: temporary, metadata: manifestData, blobs: ordered)
    _ = try openSource(.init(id: "built", path: temporary.path, sha256: digest(try Data(contentsOf: temporary)), publicationApproved: true), relativeTo: root)
    if FileManager.default.fileExists(atPath: destination.path) {
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: .usingNewMetadataOnly)
    } else {
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
    try makePresetFiles(fixture, root: root)
    print("Built \(destination.path) with \(fixture.logs.count) named segments in \(outputLogs.count) log sources and \(fixture.presets.count) presets")
}

func validate(_ manifestPath: String) throws {
    let (fixture, root) = try loadFixtureManifest(manifestPath)
    let destination = root.appendingPathComponent(fixture.document.filename)
    let source = try openSource(.init(id: "fixture", path: destination.path, sha256: digest(try Data(contentsOf: destination)), publicationApproved: true), relativeTo: root)
    let names = Set(source.metadata.logs.flatMap { $0.segmentNames.values })
    guard Set(fixture.logs.map(\.displayName)).isSubset(of: names) else { throw FixtureError.invalidManifest("missing segment names") }
    let expectedPropellerOverrides = try Dictionary(uniqueKeysWithValues: fixture.logs.compactMap { log -> (String, JSONValue)? in
        guard let propellerSize = log.propellerSize, let sourceConfig = fixture.sources.first(where: { $0.id == log.source }) else { return nil }
        let original = try openSource(sourceConfig, relativeTo: root)
        guard original.metadata.logs.indices.contains(log.sourceLogIndex) else { throw FixtureError.invalidManifest("propeller override sourceLogIndex") }
        return ("source:\(original.metadata.logs[log.sourceLogIndex].sha256):\(log.segment)", .string(propellerSize))
    })
    guard source.metadata.state.values["aircraftPropellerSizes"] == aircraftSelection(fixture.document.aircraftSettings.propellerSize, overrides: expectedPropellerOverrides),
          source.metadata.state.values["aircraftMotorLayouts"] == aircraftSelection(fixture.document.aircraftSettings.motorLayout) else {
        throw FixtureError.invalidManifest("aircraft settings")
    }
    let logHashes = Set(source.metadata.logs.map(\.sha256))
    let configurationHashes = Set(source.metadata.configurations.map(\.sha256))
    for value in source.metadata.flightControllerImports {
        guard case let .object(raw) = value, case let .array(values)? = raw["logHashes"] else { throw FixtureError.invalidManifest("flightControllerImports") }
        let importedHashes = values.compactMap { value -> String? in if case let .string(hash) = value { return hash }; return nil }
        guard importedHashes.allSatisfy(logHashes.contains) else { throw FixtureError.invalidManifest("import references missing log") }
        if case let .string(hash)? = raw["configurationHash"], !configurationHashes.contains(hash) { throw FixtureError.invalidManifest("import references missing configuration") }
    }
    for preset in fixture.presets {
        let data = try Data(contentsOf: root.appendingPathComponent(preset.file))
        guard let archive = try JSONSerialization.jsonObject(with: data) as? [String: Any], archive["format"] as? String == "com.kumkju.airframe.presets",
              let values = archive["presets"] as? [[String: Any]], values.count == 1, values[0]["i"] as? String == preset.id else { throw FixtureError.invalidManifest(preset.file) }
    }
    for log in fixture.logs where log.roles.contains("chirp-complete") || log.roles.contains("motor-problem") {
        guard let sourceConfig = fixture.sources.first(where: { $0.id == log.source }) else { throw FixtureError.invalidManifest("CHIRP source") }
        let sourceFixture = try openSource(sourceConfig, relativeTo: root)
        guard sourceFixture.metadata.logs.indices.contains(log.sourceLogIndex) else { throw FixtureError.invalidManifest("CHIRP sourceLogIndex") }
        let descriptor = sourceFixture.metadata.logs[log.sourceLogIndex]
        guard let reference = sourceFixture.references[descriptor.path] else { throw FixtureError.missingEntry(descriptor.path) }
        let data = try sourceFixture.reader.read(reference)
        let reader = BlackboxReader(configuration: .init(compatibilityMode: .bestEffortDataVersion2))
        let importSet = try reader.open(data: data, sourceName: descriptor.originalFilename)
        let decodedLogs = reader.decodedLogs(in: importSet)
        guard let decodedLog = decodedLogs.first(where: { $0.id.segmentIndex == log.segment }) else {
            throw FixtureError.invalidManifest("CHIRP segment \(log.segment); available indices: \(decodedLogs.map { $0.id.segmentIndex })")
        }
        let flightInfo = try decodedLog.flightInfo()
        let overview = DecodedLogFlightOverviewBuilder.build(from: flightInfo).flight
        guard overview.firstArmVoltage != nil, overview.averageCurrentAmps != nil, overview.consumedMilliampHours != nil else {
            throw FixtureError.invalidManifest("Power capability for \(log.displayName)")
        }
        guard log.roles.contains("chirp-complete") else { continue }
        let status = AnalysisChirpStatus.resolve(flightInfo: flightInfo)
        let isScreenshotReady = status == .available(.complete) || (status == .incomplete(.legacyPhase) && (flightInfo.durationSeconds ?? 0) >= 80)
        guard isScreenshotReady else {
            var candidates: [String] = []
            for (index, candidateDescriptor) in sourceFixture.metadata.logs.enumerated() {
                guard let candidateReference = sourceFixture.references[candidateDescriptor.path] else { continue }
                let candidateData = try sourceFixture.reader.read(candidateReference)
                let candidateImport = try reader.open(data: candidateData, sourceName: candidateDescriptor.originalFilename)
                if let candidateLog = reader.decodedLogs(in: candidateImport).first(where: { decoded in
                    let value = decoded.headerInfo.integerValue(for: ReaderHeaderKey(rawValue: "debug_mode"))
                    return value.flatMap { ReaderDebugMode.name(for: $0, firmwareVersion: decoded.headerInfo.firmwareRevision?.version) } == "CHIRP"
                }) {
                    candidates.append("\(index)=\(AnalysisChirpStatus.resolve(flightInfo: try candidateLog.flightInfo()))")
                }
            }
            throw FixtureError.invalidManifest("CHIRP capability for \(log.displayName): \(status); CHIRP debug candidates: \(candidates)")
        }
    }
    print("Validated \(fixture.document.displayName): \(fixture.logs.count) named segments, \(fixture.presets.count) presets, \(fixture.futureUIStates.count) future UI states")
}

func inventory(_ documentPath: String) throws {
    let url = URL(fileURLWithPath: documentPath).standardizedFileURL
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    if url.pathExtension.lowercased() != "airframe" {
        let reader = BlackboxReader(configuration: .init(compatibilityMode: .bestEffortDataVersion2))
        let importSet = try reader.open(data: data, sourceName: url.lastPathComponent)
        for decoded in reader.decodedLogs(in: importSet) {
            let info = try decoded.flightInfo()
            print("segment=\(decoded.id.segmentIndex) duration=\(info.durationSeconds ?? 0) CHIRP=\(AnalysisChirpStatus.resolve(flightInfo: info)) maxima=\(info.scan.overview.chirpDebugSummary.maximumFrequencyDecihertzByAxis) filename=\(url.lastPathComponent)")
        }
        return
    }
    let source = try openSource(.init(id: "inventory", path: url.path, sha256: digest(data), publicationApproved: true), relativeTo: url.deletingLastPathComponent())
    let reader = BlackboxReader(configuration: .init(compatibilityMode: .bestEffortDataVersion2))
    for (index, descriptor) in source.metadata.logs.enumerated() {
        let configurationHash = source.metadata.flightControllerImports.compactMap { value -> String? in
            guard case let .object(raw) = value, case let .array(logHashes)? = raw["logHashes"],
                  logHashes.contains(.string(descriptor.sha256)), case let .string(hash)? = raw["configurationHash"] else { return nil }
            return hash
        }.first
        guard let reference = source.references[descriptor.path] else { continue }
        let importSet = try reader.open(data: source.reader.read(reference), sourceName: descriptor.originalFilename)
        for decoded in reader.decodedLogs(in: importSet) {
            let fields = Set(decoded.headerInfo.mainFrameFields)
            let power = ["vbat": fields.contains("vbat") || fields.contains("vbatLatest"), "current": fields.contains("amperage") || fields.contains("amperageLatest")]
            let rawDebugMode = decoded.headerInfo.integerValue(for: ReaderHeaderKey(rawValue: "debug_mode"))
            let debugMode = rawDebugMode.flatMap { ReaderDebugMode.name(for: $0, firmwareVersion: decoded.headerInfo.firmwareRevision?.version) }
            guard debugMode == "CHIRP" else {
                let overview = DecodedLogFlightOverviewBuilder.build(from: try decoded.flightInfo()).flight
                print("sourceLogIndex=\(index) segment=\(decoded.id.segmentIndex) power=\(power) voltage=\(text(overview.firstArmVoltage)) current=\(text(overview.averageCurrentAmps)) usedMah=\(text(overview.consumedMilliampHours)) config=\(configurationHash ?? "none") filename=\(descriptor.originalFilename)")
                continue
            }
            let info = try decoded.flightInfo()
            print("sourceLogIndex=\(index) segment=\(decoded.id.segmentIndex) duration=\(info.durationSeconds ?? 0) power=\(power) config=\(configurationHash ?? "none") CHIRP=\(AnalysisChirpStatus.resolve(flightInfo: info)) maxima=\(info.scan.overview.chirpDebugSummary.maximumFrequencyDecihertzByAxis) filename=\(descriptor.originalFilename)")
        }
    }
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2 else { throw FixtureError.usage }
    switch args[0] {
    case "build": try build(args[1])
    case "validate": try validate(args[1])
    case "inventory": try inventory(args[1])
    default: throw FixtureError.usage
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
