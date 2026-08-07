// T-Motor FFE0 BLE UART probe.
// Standalone experiment harness for the intermittent MSP availability on TMOTORFC_* controllers.
// Runs several connect sessions in a row, retries MSP_API_VERSION with escalating variants,
// logs every notification byte, and passively listens on the JieLi AE02 channel (no AE01 writes).
//
// Build: swiftc -O tools/tmotor_ble_probe.swift -o /tmp/tmotor_ble_probe -framework CoreBluetooth
// Run:   /tmp/tmotor_ble_probe [sessions] [initialDelayMs] [optional framed CLI command or @command-file] [ffe1|ff02ff03]

import CoreBluetooth
import CryptoKit
import Foundation

let sessionsRequested = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 3 : 3
let initialDelayMs = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 500 : 500
let cliArgument = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : nil
let cliCommands: [String] = {
    guard let cliArgument else { return [] }
    guard cliArgument.hasPrefix("@") else { return [cliArgument] }
    let path = String(cliArgument.dropFirst())
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
    return contents.split(whereSeparator: \Character.isNewline).map(String.init).filter { !$0.isEmpty }
}()
let usesAlternateUART = CommandLine.arguments.count > 4 && CommandLine.arguments[4].lowercased() == "ff02ff03"

let serviceUART = CBUUID(string: "FFE0")
let charUART = CBUUID(string: "FFE1")
let charAlternateWrite = CBUUID(string: "FF02")
let charAlternateNotify = CBUUID(string: "FF03")
let serviceJieLi = CBUUID(string: "AE00")
let charJieLiNotify = CBUUID(string: "AE02")

let startDate = Date()
func log(_ message: String) {
    let t = String(format: "%8.3f", Date().timeIntervalSince(startDate))
    print("[\(t)] \(message)")
    fflush(stdout)
}

func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined(separator: " ") }

func mspV1Request(command: UInt8) -> Data {
    var bytes: [UInt8] = [0x24, 0x4d, 0x3c, 0x00, command]
    bytes.append(0x00 ^ command)
    return Data(bytes)
}

func mspV2Request(command: UInt16) -> Data {
    var payload: [UInt8] = [0x00, UInt8(command & 0xff), UInt8(command >> 8), 0x00, 0x00]
    var crc: UInt8 = 0
    for byte in payload {
        crc ^= byte
        for _ in 0..<8 { crc = (crc & 0x80) != 0 ? (crc << 1) ^ 0xd5 : crc << 1 }
    }
    payload.append(crc)
    return Data([0x24, 0x58, 0x3c] + payload)
}

/// Scans an accumulated notification buffer for a complete MSP v1 response frame.
func containsMSPv1Response(_ buffer: Data) -> Bool {
    let bytes = [UInt8](buffer)
    guard bytes.count >= 6 else { return false }
    for start in 0...(bytes.count - 6) {
        if bytes[start] == 0x24, bytes[start + 1] == 0x4d, bytes[start + 2] == 0x3e {
            let length = Int(bytes[start + 3])
            if bytes.count >= start + 6 + length { return true }
        }
    }
    return false
}

func firstMSPv1Response(_ buffer: Data) -> (code: UInt8, payload: Data)? {
    let bytes = [UInt8](buffer)
    guard bytes.count >= 6 else { return nil }
    for start in 0...(bytes.count - 6) {
        guard bytes[start] == 0x24, bytes[start + 1] == 0x4d, bytes[start + 2] == 0x3e else { continue }
        let declaredLength = Int(bytes[start + 3])
        let headerLength: Int
        let payloadLength: Int
        if declaredLength == 255 {
            guard bytes.count >= start + 7 else { continue }
            headerLength = 7
            payloadLength = Int(bytes[start + 5]) | (Int(bytes[start + 6]) << 8)
        } else {
            headerLength = 5
            payloadLength = declaredLength
        }
        let checksumIndex = start + headerLength + payloadLength
        guard checksumIndex < bytes.count else { continue }
        let expected = bytes[(start + 3)..<checksumIndex].reduce(0, ^)
        guard expected == bytes[checksumIndex] else { continue }
        return (bytes[start + 4], Data(bytes[(start + headerLength)..<checksumIndex]))
    }
    return nil
}

func containsCompleteFramedCLIResponse(_ buffer: Data) -> Bool {
    let bytes = [UInt8](buffer)
    guard let start = bytes.firstIndex(of: 0x02), start + 1 < bytes.count else { return false }
    return bytes[(start + 1)...].contains(0x03)
}

struct AttemptPlan {
    let label: String
    let payload: Data
    let preferWithResponse: Bool
}

func attemptPlan(for attempt: Int) -> AttemptPlan {
    let apiVersion = mspV1Request(command: 1)
    switch attempt {
    case 1...3: return AttemptPlan(label: "v1 API_VERSION, write-without-response", payload: apiVersion, preferWithResponse: false)
    case 4...5: return AttemptPlan(label: "v1 API_VERSION, write-with-response", payload: apiVersion, preferWithResponse: true)
    case 6: return AttemptPlan(label: "v1 API_VERSION doubled in one write", payload: apiVersion + apiVersion, preferWithResponse: false)
    case 7: return AttemptPlan(label: "CRLF wake then v1 API_VERSION", payload: Data([0x0d, 0x0a]) + apiVersion, preferWithResponse: false)
    case 8: return AttemptPlan(label: "v2 API_VERSION (MSP v2 framing)", payload: mspV2Request(command: 1), preferWithResponse: false)
    default: return AttemptPlan(label: "v1 API_VERSION, write-without-response (late retry)", payload: apiVersion, preferWithResponse: false)
    }
}

final class Probe: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var uartWriteCharacteristic: CBCharacteristic?
    private var uartNotifyCharacteristic: CBCharacteristic?
    private var jieliCharacteristic: CBCharacteristic?

    private var session = 0
    private var attempt = 0
    private var received = Data()
    private var attemptStart = Date()
    private var sessionResults: [String] = []
    private var scanDeadline: DispatchWorkItem?

    func start() {
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("Central powered on, scanning for TMOTORFC_* (no service filter)")
            beginScan()
        case .unauthorized:
            log("FATAL: Bluetooth permission denied for this process (grant the terminal Bluetooth access in System Settings > Privacy)")
            finish(code: 2)
        default:
            log("Central state: \(central.state.rawValue)")
        }
    }

    private func beginScan() {
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        let deadline = DispatchWorkItem { [weak self] in
            guard let self, self.peripheral == nil else { return }
            log("Scan timeout after 25 s: no TMOTORFC_* advertisement seen. Is the FC powered and in range?")
            self.finish(code: 3)
        }
        scanDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: deadline)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        guard name.hasPrefix("TMOTORFC") else { return }
        scanDeadline?.cancel()
        log("Discovered \(name) RSSI \(RSSI), advertised services: \(advertisementData[CBAdvertisementDataServiceUUIDsKey] ?? "none")")
        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        session = 1
        log("=== Session \(session)/\(sessionsRequested): connecting ===")
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected. maximumWriteValueLength withoutResponse=\(peripheral.maximumWriteValueLength(for: .withoutResponse)) withResponse=\(peripheral.maximumWriteValueLength(for: .withResponse))")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("Connect failed: \(error?.localizedDescription ?? "unknown")")
        nextSession(result: "session \(session): connect failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Disconnected (\(error?.localizedDescription ?? "clean"))")
        if session > 0 && session <= sessionsRequested && uartWriteCharacteristic != nil {
            // Disconnect we requested at end of a session is handled in nextSession already.
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { log("Service discovery error: \(error.localizedDescription)"); return }
        let services = peripheral.services ?? []
        log("Services: \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")
        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { log("Characteristic discovery error on \(service.uuid): \(error.localizedDescription)"); return }
        for characteristic in service.characteristics ?? [] {
            log("  \(service.uuid)/\(characteristic.uuid) properties raw=\(characteristic.properties.rawValue)")
            if service.uuid == serviceUART && !usesAlternateUART && characteristic.uuid == charUART {
                uartWriteCharacteristic = characteristic
                uartNotifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if service.uuid == serviceUART && usesAlternateUART && characteristic.uuid == charAlternateWrite {
                uartWriteCharacteristic = characteristic
            }
            if service.uuid == serviceUART && usesAlternateUART && characteristic.uuid == charAlternateNotify {
                uartNotifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if service.uuid == serviceJieLi && characteristic.uuid == charJieLiNotify {
                jieliCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Notify enable failed on \(characteristic.uuid): \(error.localizedDescription)"); return }
        log("Notifications enabled on \(characteristic.uuid)")
        if characteristic.uuid == uartNotifyCharacteristic?.uuid {
            log("Waiting \(initialDelayMs) ms before first MSP attempt")
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(initialDelayMs)) { [weak self] in
                self?.attempt = 0
                self?.startNextAttempt()
            }
        }
    }

    private func startNextAttempt() {
        guard let peripheral, let characteristic = uartWriteCharacteristic else { return }
        attempt += 1
        if attempt > 12 {
            log("Session \(session): NO MSP response after 12 attempts")
            nextSession(result: "session \(session): FAILED (no MSP response, 12 attempts)")
            return
        }
        received.removeAll()
        attemptStart = Date()
        let plan = attemptPlan(for: attempt)
        let supportsWithResponse = characteristic.properties.contains(.write)
        let writeType: CBCharacteristicWriteType = (plan.preferWithResponse && supportsWithResponse) ? .withResponse : .withoutResponse
        log("Attempt \(attempt): \(plan.label) -> \(hex(plan.payload)) [\(writeType == .withResponse ? "with-response" : "without-response")]")
        peripheral.writeValue(plan.payload, for: characteristic, type: writeType)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.evaluateAttempt()
        }
    }

    private func evaluateAttempt() {
        if containsMSPv1Response(received) {
            let latency = Date().timeIntervalSince(attemptStart)
            log("Session \(session): API_VERSION ok on attempt \(attempt) (\(String(format: "%.0f", latency * 1000)) ms window), reply: \(hex(received))")
            apiAttempts = attempt
            handshakeIndex = 0
            handshakeRetried = false
            startNextHandshakeStep()
        } else {
            if !received.isEmpty { log("Attempt \(attempt): non-MSP bytes received: \(hex(received))") }
            startNextAttempt()
        }
    }

    // MARK: Full handshake after API version

    private var apiAttempts = 0
    private var handshakeIndex = 0
    private var handshakeRetried = false
    private var waitingForCLI = false
    private var cliCommandIndex = 0
    private var cliTotalBytes = 0
    private var cliMaximumBytes = 0
    private var cliDeadline: DispatchWorkItem?

    private struct HandshakeStep {
        let label: String
        let payload: Data
        let expectedMinimumLength: Int
    }

    private func dataflashReadRequest(address: UInt32, length: UInt16) -> Data {
        var payload: [UInt8] = []
        payload.append(contentsOf: withUnsafeBytes(of: address.littleEndian, Array.init))
        payload.append(contentsOf: withUnsafeBytes(of: length.littleEndian, Array.init))
        payload.append(0)
        var bytes: [UInt8] = [0x24, 0x4d, 0x3c, UInt8(payload.count), 71]
        bytes.append(contentsOf: payload)
        var crc: UInt8 = UInt8(payload.count) ^ 71
        for byte in payload { crc ^= byte }
        bytes.append(crc)
        return Data(bytes)
    }

    private var handshakeSteps: [HandshakeStep] {
        [
            HandshakeStep(label: "FC_VARIANT (2)", payload: mspV1Request(command: 2), expectedMinimumLength: 4),
            HandshakeStep(label: "FC_VERSION (3)", payload: mspV1Request(command: 3), expectedMinimumLength: 3),
            HandshakeStep(label: "BOARD_INFO (4)", payload: mspV1Request(command: 4), expectedMinimumLength: 4),
            HandshakeStep(label: "BUILD_INFO (5)", payload: mspV1Request(command: 5), expectedMinimumLength: 11),
            HandshakeStep(label: "DATAFLASH_SUMMARY (70)", payload: mspV1Request(command: 70), expectedMinimumLength: 13),
            HandshakeStep(label: "DATAFLASH_READ 2048 B @0 uncompressed (71)", payload: dataflashReadRequest(address: 0, length: 2_048), expectedMinimumLength: 7),
        ]
    }

    private func startNextHandshakeStep() {
        guard let peripheral, let characteristic = uartWriteCharacteristic else { return }
        let steps = handshakeSteps
        if handshakeIndex >= steps.count {
            if !cliCommands.isEmpty {
                cliCommandIndex = 0
                cliTotalBytes = 0
                cliMaximumBytes = 0
                startCLICommand(cliCommands[0])
                return
            }
            log("Session \(session): FULL SUCCESS (api attempt \(apiAttempts), all \(steps.count) handshake steps)")
            nextSession(result: "session \(session): FULL SUCCESS (api attempt \(apiAttempts))")
            return
        }
        let step = steps[handshakeIndex]
        received.removeAll()
        attemptStart = Date()
        log("Handshake \(handshakeIndex + 1)/\(steps.count): \(step.label) -> \(hex(step.payload))")
        peripheral.writeValue(step.payload, for: characteristic, type: .withoutResponse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.evaluateHandshakeStep()
        }
    }

    private func startCLICommand(_ command: String) {
        guard let peripheral, let characteristic = uartWriteCharacteristic else { return }
        received.removeAll()
        waitingForCLI = true
        attemptStart = Date()
        let framed = Data([0x02]) + Data(command.utf8) + Data([0x0A, 0x03])
        log("Framed CLI: \(command) (\(framed.count) request bytes)")
        peripheral.writeValue(framed, for: characteristic, type: .withoutResponse)
        let deadline = DispatchWorkItem { [weak self] in self?.evaluateCLICommand() }
        cliDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: deadline)
    }

    private func evaluateCLICommand() {
        guard waitingForCLI else { return }
        waitingForCLI = false
        cliDeadline?.cancel()
        cliDeadline = nil
        let complete = containsCompleteFramedCLIResponse(received)
        let latency = Date().timeIntervalSince(attemptStart)
        let digest = SHA256.hash(data: received).map { String(format: "%02x", $0) }.joined()
        log("Framed CLI result \(cliCommandIndex + 1)/\(cliCommands.count) complete=\(complete) bytes=\(received.count) elapsed=\(String(format: "%.2f", latency))s sha256=\(digest)")
        guard complete else {
            nextSession(result: "session \(session): CLI FAILED command=\(cliCommandIndex + 1) \(received.count) B")
            return
        }
        cliTotalBytes += received.count
        cliMaximumBytes = max(cliMaximumBytes, received.count)
        cliCommandIndex += 1
        if cliCommandIndex < cliCommands.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                self.startCLICommand(cliCommands[self.cliCommandIndex])
            }
        } else {
            nextSession(result: "session \(session): CLI SUCCESS commands=\(cliCommands.count) total=\(cliTotalBytes) B maximum=\(cliMaximumBytes) B")
        }
    }

    private func evaluateHandshakeStep() {
        let step = handshakeSteps[handshakeIndex]
        if containsMSPv1Response(received) {
            let latency = Date().timeIntervalSince(attemptStart)
            log("  \(step.label) ok, \(received.count) B in \(String(format: "%.0f", latency * 1000)) ms window: \(hex(received.prefix(48)))\(received.count > 48 ? " …" : "")")
            if step.label.hasPrefix("DATAFLASH_READ"),
               let response = firstMSPv1Response(received), response.code == 71, response.payload.count >= 7 {
                let raw = response.payload.dropFirst(7)
                let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
                log("  Uncompressed dataflash bytes=\(raw.count) sha256=\(digest)")
            }
            handshakeIndex += 1
            handshakeRetried = false
            startNextHandshakeStep()
        } else if !handshakeRetried {
            log("  \(step.label): no reply, retrying once (buffer: \(hex(received)))")
            handshakeRetried = true
            startNextHandshakeStep()
        } else {
            log("Session \(session): handshake FAILED at \(step.label)")
            nextSession(result: "session \(session): FAILED at \(step.label) (api attempt \(apiAttempts))")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Value update error on \(characteristic.uuid): \(error.localizedDescription)"); return }
        guard let data = characteristic.value, !data.isEmpty else { return }
        if characteristic.uuid == uartNotifyCharacteristic?.uuid {
            received.append(data)
            if waitingForCLI {
                if received.count % 512 < data.count || data.contains(0x03) {
                    log("  <- FFE1 CLI total=\(received.count) B")
                }
                if containsCompleteFramedCLIResponse(received) {
                    evaluateCLICommand()
                }
            } else {
                log("  <- FFE1 \(data.count) B: \(hex(data))")
            }
        } else {
            log("  <- \(characteristic.uuid) (passive) \(data.count) B: \(hex(data))")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Write (with response) failed: \(error.localizedDescription)") }
    }

    private func nextSession(result: String) {
        sessionResults.append(result)
        uartWriteCharacteristic = nil
        uartNotifyCharacteristic = nil
        jieliCharacteristic = nil
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        if session >= sessionsRequested {
            log("=== All sessions done ===")
            for line in sessionResults { log(line) }
            finish(code: 0)
            return
        }
        session += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, let peripheral = self.peripheral else { return }
            log("=== Session \(self.session)/\(sessionsRequested): reconnecting ===")
            self.central.connect(peripheral, options: nil)
        }
    }

    private func finish(code: Int32) {
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exit(code) }
    }
}

let probe = Probe()
probe.start()
RunLoop.main.run()
