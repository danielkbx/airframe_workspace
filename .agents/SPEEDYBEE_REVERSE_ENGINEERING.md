# SpeedyBee Adapter 3 — Log Download Protocol (BLE and WiFi)

> **Airframe-internal document. Do not publish as-is.**
> These notes exist so Airframe can build a native SpeedyBee-Adapter-3 log importer
> without re-doing any of the investigation. Wording, scope, and the artifacts referenced
> here (private captures, download paths) are meant for internal use. Before any public
> release, this file must be rewritten with a neutral tone, cleared of internal paths and
> workspace-specific references, and reviewed for anything that should stay private.

Reverse-engineering notes for the blackbox-log download path of the SpeedyBee Adapter 3.
The goal is a clean-room, dependency-free reimplementation for Airframe. Everything an
implementer needs to build the importer without consulting any external source is captured
in this file (protocol bytes, exact ordering, timeouts, edge cases, test vectors, and the
compatibility scope). If you find yourself needing a fact that isn't in here, it is a bug
in this document — extend it rather than re-running the investigation.

- Method: passive 802.11 monitor-mode capture of the official SpeedyBee iOS app talking to
  a physical adapter (WiFi side), plus macOS HCI capture via PacketLogger (BLE side), plus
  offline analysis, plus an independent reimplementation (`tools/speedybee_wifi_probe.py`)
  that lists and downloads logs from a live adapter. No firmware was extracted and no
  source code was reused; the protocol is inferred purely from observed traffic.
- Confidence: the full flow — from BLE-triggered WiFi activation through the WiFi bulk
  download — is understood and independently verified. The probe downloaded
  `BTFL_001.BBL` (2,043,904 bytes) with all 1000 packets CRC-valid, and the BLE trigger
  bytes were captured end to end.
- Hardware under test: SpeedyBee Adapter 3, firmware/model id `ADPT03116`, adapter MAC
  `04:83:08:E8:C5:71` (Espressif OUI `04:83:08`, so an ESP32-class SoC), SSID
  `SBADAPTER3_C571`. Primary FC under test: SpeedyBee F435-AIO / F7 running Betaflight 4.5.0,
  MSP API 1.47, build date 2025.12.5.
- Second verified FC: a Flywoo F405S AIO running Betaflight 4.5.2 (MSP API 1.46), blackbox on
  onboard flash. A native reimplementation downloaded `BTFL_001.BBL` (391,168 bytes, all
  192 packets CRC-valid) end to end over WiFi. This combo behaves identically except for the
  "prepare" reply, which it does not return over the bridge (see section 5); the download
  still succeeds. It confirms the flow generalizes beyond the primary FC.
- Behaviour beyond these combos (other adapter firmware, INAV FCs, Betaflight variants that
  are not `BTFL`) has not been verified.

## 0. Compatibility scope

- **Adapter firmware**: model id string `ADPT03116` (returned in DEVICE_INFO). Other
  revisions are expected to be compatible but have not been tested.
- **Flight controller**: Betaflight (`MSP_FC_VARIANT` returns `"BTFL"`). Reject other
  variants; INAV and CleanFlight likely differ in MSP command 0x44.
- **Adapter BLE identity**: name pattern `SBADAPTER3_*` in the advertisement (last 4 hex
  digits of the MAC). MAC OUI `04:83:08` (Espressif). Advertised service UUID list may or
  may not include `0xABF0`; on macOS the discovery scans without a service filter and
  resolves the profile after connect, which is the pattern Airframe already uses.
- **BLE ATT MTU**: the adapter must negotiate an ATT MTU that fits the largest
  control-channel reply (DEVICE_INFO is up to ~250 bytes, observed value 249 with a 2-byte
  outer length; total 251 including ATT notify header). Modern iOS/macOS negotiate
  ≥ 251 automatically; if the negotiated MTU is smaller, the DEVICE_INFO notification will
  be truncated. Airframe's BLE stack should request the maximum MTU on connect.
- **WiFi AP**: 2.4 GHz, 802.11b/g/n, channel varies (channel 1 was observed here; do not
  hardcode). SSID pattern `SBADAPTER3_XXXX` where `XXXX` equals the last four uppercase
  hex digits of the adapter MAC; open security (no PSK). Gateway `192.168.1.1`, DHCP
  server on the adapter hands out `192.168.1.2..N`, DNS is the adapter (captive-portal
  style, answers any query).

## 1. Terminology and conventions

- "Adapter" = the SpeedyBee device (also the WiFi AP, DHCP server, DNS server, and the
  server side of every connection). Address `192.168.1.1`.
- "Client" = the app (phone). Address `192.168.1.2` in this capture.
- All multi-byte integers in the wire format are little-endian unless stated otherwise.
- Hex is shown space-separated, ASCII in double quotes, `\0` = NUL byte `0x00`.

## 2. Physical / network layer

- WiFi: 2.4 GHz, 802.11b/g/n, channel 1, SSID `SBADAPTER3_C571`, **open (no
  encryption)**. Any device in range can join and read all traffic.
- On join the adapter acts as DHCP server:
  - DISCOVER/OFFER/REQUEST/ACK observed; adapter assigns `192.168.1.2`,
    router = `192.168.1.1`, DNS = `192.168.1.1`.
- The adapter also answers DNS (captive-portal style): it responds to every name query
  (Apple connectivity checks, push, etc.) with `NOERROR` and either no A record or its own
  client address. Not required for the log download; noted for completeness.
- The adapter does **not** advertise any mDNS/Bonjour service. Service discovery is not
  used; the app connects to fixed ports on the fixed gateway IP.

## 3. BLE transport (how WiFi mode is entered)

The adapter's WiFi AP is **off by default**. It is switched on by a single BLE write from
the app, delivered over the same GATT service that Airframe already uses for the classic
Betaflight MSP bridge. The full BLE surface of the adapter is:

Primary service `0xABF0` (full UUID `0000ABF0-0000-1000-8000-00805F9B34FB`, standard
Bluetooth-SIG 16-bit-to-128-bit expansion), four characteristics:

| Characteristic | Handle (this device) | Properties                | Role                                   |
|----------------|----------------------|---------------------------|----------------------------------------|
| `0xABF1`       | 0x002A               | read, write-without-response | MSP passthrough — **write** to FC   |
| `0xABF2`       | 0x002C               | read, notify              | MSP passthrough — **notify** from FC   |
| `0xABF3`       | 0x002F               | read, write-without-response | SpeedyBee control channel — **write** |
| `0xABF4`       | 0x0031               | read, notify              | SpeedyBee control channel — **notify** |

Handles are per-connection identifiers; portable code must resolve everything by UUID. All
four characteristics are 16-bit-form (`0xABFn` → `0000ABFn-0000-1000-8000-00805F9B34FB`).
The two notify characteristics each expose a standard CCCD (`0x2902`) descriptor; the
client must write `01 00` to both to enable notifications before sending any command,
otherwise replies are silently dropped. The write direction uses **write-without-response**
(ATT opcode `0x52`).

The `(ABF3, ABF4)` pair carries **exactly the same** protobuf-style protocol as TCP 4279
(see section 6) — same framing, same opcodes, same replies. Byte-for-byte identical: the
HELLO reply `05 00 04 08 03 10 02` was observed verbatim on both transports. The adapter
runs one control-channel protocol over two carriers.

**Sizing note.** ATT MTU must be large enough for the biggest reply. DEVICE_INFO on ABF4
is 248 bytes payload (`f6 00` outer + a varint + a 246-byte inner). At the default ATT MTU
of 23 you would receive only 20 bytes. The adapter/host on modern iOS and macOS negotiate
MTU 251, which is enough. If a smaller MTU is negotiated, DEVICE_INFO will be truncated
and there is no per-notification fragmentation defined at this layer. An implementer must
request maximum MTU on connect and refuse to proceed if the negotiated MTU is below ~252.

### 3.1 WiFi activation

Two BLE writes on `ABF3` turn the WiFi AP on. Byte-for-byte from a real capture:

```
--> ABF3 (0x002F)  02 00 08 17                        op 0x17 — GET WIFI INFO
<-- ABF4 (0x0031)  33 00 32 08 17 1a 2e
                    "SBADAPTER3_C571" 00 00 ... 00
                    "048308E8C571" a5                 SSID + adapter MAC in a 46-byte blob
--> ABF3 (0x002F)  02 00 08 18                        op 0x18 — START WIFI
```

After the second write the adapter brings up its open WiFi AP and the client can switch to
the WiFi transport for the actual download. Op `0x18` was not observed to produce a reply
on ABF4 in this capture; if one is sent it arrives after the client has already left BLE
for WiFi. A working sequence therefore treats op `0x18` as a fire-and-forget trigger and
proves success by finding the SSID on the air a few seconds later.

**BLE ⇄ WiFi handoff:**

- After op `0x18` the BLE connection may drop on its own (the Espressif SoC re-purposes the
  radio for AP mode). Do not treat that disconnect as an error; if it doesn't happen on its
  own, actively disconnect from the BLE peripheral before scanning for the WiFi AP. Holding
  the BLE connection while the adapter is trying to serve WiFi has been observed to slow
  AP bring-up.
- The AP is available typically 2–4 seconds after op `0x18`. Poll for the SSID (from the
  WIFI_INFO reply) with a 10 s budget before declaring failure.
- Once the client is on WiFi, it does the entire WiFi flow (section 6 onwards) without ever
  touching BLE again.
- Re-issuing op `0x18` when the AP is already up appears to be safe but is not necessary.
- There is no observed "stop WiFi" command. The adapter appears to fall back to BLE-only
  automatically when it is power-cycled or after some inactivity timeout on WiFi. Treat WiFi
  mode as a one-shot session per power cycle.

**Parsing the WIFI_INFO blob** (`08 17 1a 2e <46 bytes>`): the 46-byte payload contains
NUL-padded ASCII fields laid out as a fixed-width struct. Concretely, the first non-empty
NUL-terminated run is the SSID (e.g. `SBADAPTER3_C571`), the next non-empty run is the
uppercase MAC without separators (e.g. `048308E8C571`, 12 chars). A tolerant parser splits
on NUL, drops empties, and takes the first two entries. There is no explicit length prefix
inside the 46 bytes; rely on NUL termination.

Two new opcodes on the control channel:

| op   | name (assigned) | request body                    | reply body                                     |
|------|-----------------|----------------------------------|------------------------------------------------|
| 0x17 | WIFI_INFO       | `08 17`                          | `08 17 1a <len> <SSID nul-pad MAC>` — 46 bytes |
| 0x18 | WIFI_START      | `08 18`                          | none observed (fire-and-forget)                |

The WIFI_INFO blob is convenient for a UI that tells the user *which* network to join
without hardcoding; parse it as ASCII, split on `\0`, take the first non-empty as SSID and
the next as the MAC (formatted uppercase hex without separators).

### 3.2 BLE preamble observed before op 0x17 / 0x18

The app runs a standard Betaflight MSP identification round on `ABF1/ABF2` before it
touches WiFi. Not required for the WiFi trigger itself, but useful for a client that also
wants to identify the FC:

```
$M< 00 02 02          MSP_FC_VARIANT     -> "BTFL"
$M< 00 a0 a0          MSP (0xA0 = 160)    -> board info blob
$M< 00 01 01          MSP_API_VERSION    -> 00 01 2f  (api 1.47)
$M< 00 03 03          MSP_FC_VERSION     -> 4.5.0
$M< 00 04 04          MSP_BUILD_INFO     -> build date/time + git hash
$M< 00 46 46          MSP (0x46 = 70)    -> feature/status blob
$M< 00 4f 4f          MSP_BOXNAMES (79)  -> box names / empty here
```

Then a control-channel HELLO/SESSION/DEVICE_INFO round on `ABF3/ABF4` (the same handshake
as on TCP 4279, section 5), followed immediately by ops `0x17` and `0x18` above.

## 4. Port map (WiFi transport)

Once WiFi is up, a full TCP scan (1–65535) shows only two permanently listening TCP ports:

| Port     | Transport | Role                                                        |
|----------|-----------|-------------------------------------------------------------|
| 4278/tcp | TCP       | MSP passthrough to the flight controller (see section 5)    |
| 4279/tcp | TCP       | Control channel: handshake, file list, stat, select         |
| 4281/tcp | TCP       | Opened during download but carries no payload in this capture |
| 4281/udp | UDP       | Bulk data channel: the actual file bytes                    |

4281/tcp and 4281/udp share the port number but are independent sockets. The bulk transfer
uses UDP; the TCP 4281 connection is opened (SYN/ACK) but never carries data here, so it is
either vestigial or used only in other modes.

## 5. TCP 4278 — MSP passthrough and the "prepare" command

TCP 4278 is a transparent bridge to the FC's MSP interface. It carries one **required**
command in the download flow — do not treat it as a mere probe. The observed exchange on the
primary FC is:

```
client -> adapter : 24 4D 3C 01 44 02 47    $M<  size=1 cmd=0x44 payload=0x02 crc=0x47
adapter -> client : 24 4D 3E 02 44 02 01 45  $M>  size=2 cmd=0x44 payload=02 01 crc=0x45
```

MSPv1 framing: `$M<` (request) / `$M>` (reply), one byte payload length, one byte command,
payload, one byte XOR checksum over (length ^ command ^ payload...). Command `0x44` = 68
with a one-byte payload `0x02`.

**Command identity.** Command 68 is `MSP_SET_REBOOT`, and payload `0x02` is reboot mode 2 =
mass storage (MSC). So "prepare" is literally "reboot the flight controller into mass-storage
mode": the FC re-presents its blackbox storage as a filesystem, which the adapter then reads
and serves over WiFi (LIST/STAT on TCP 4279, bulk data on UDP 4281). The reply payload is the
standard `MSP_SET_REBOOT` shape `[rebootMode, readiness]`, so `02 01` means reboot mode 2 with
readiness 1.

This command is the hard prerequisite for listing: **without it, LIST (op 0x6e) never
populates and keeps returning the "busy" value 22.** It must be sent after the control-channel
status handshake settles and before LIST (see the flow in section 9). Confirmed on both FCs:
skipping it leaves LIST stuck at 22 indefinitely; sending it makes the file list appear within
about a second.

**The reply is NOT guaranteed — do not require it.** Because this is a reboot-class command,
firmware behaviour varies:

- Primary FC (BF 4.5.0, API 1.47): replies `[2, 1]` (readiness 1) before rebooting.
- Second FC (Flywoo F405S, BF 4.5.2, API 1.46): returns **no reply at all** over the bridge,
  yet still reboots and exposes the flash; the download succeeds. An implementation that waits
  for the prepare reply before continuing (as an early version of ours did) fails here with a
  false timeout even though the FC is healthy (its MSP answers ordinary queries such as
  `MSP_API_VERSION` and `MSP_FC_VARIANT` fine on the same socket).

Correct handling, verified on both FCs:

- Send `MSP_SET_REBOOT` mode 2 and read a reply with a short timeout, but treat a **missing
  reply as success** (the FC rebooted without acking over the bridge). Prove readiness later by
  polling LIST, not by this reply.
- If a reply **is** present, inspect its readiness byte (`payload[1]`). Readiness 0 means the
  FC declined because its filesystem was briefly busy (common right after boot); resend a few
  times (about 4 attempts, ~0.4 s apart) before giving up. Any nonzero readiness means accepted.
- After a successful prepare the FC has effectively left normal MSP operation, so do not expect
  further MSP replies on 4278; everything else happens over the control and data channels.

The FC can also be slow to answer ordinary queries right after WiFi comes up (first reply seen
after ~3 s on the second FC), so keep per-exchange timeouts generous.

## 6. TCP 4279 — control channel

### 5.1 Frame structure

The control channel is asymmetric.

Client → adapter frame:

```
[ outer_len : uint16 LE ] [ message ]
```

`outer_len` counts only `message`. `message` is a protobuf-style body (section 5.2).

Adapter → client frame:

```
[ outer_len : uint16 LE ] [ inner_len : varint ] [ message ]
```

The adapter adds a redundant `inner_len` (a protobuf-style base-128 varint) that always
equals `outer_len - sizeof(inner_len)`, i.e. it counts everything after itself. `message`
then follows and has the same shape as the client's. When implementing, read `outer_len`,
then on the adapter side skip the leading varint (or validate that it equals
`outer_len - varint_size`).

### 5.2 Message encoding

Each `message` is a minimal protobuf-like structure. Only three wire constructs appear:

- Field 1, varint (`tag 0x08`): the **opcode**, a single byte we call `op`. Always the
  first field of every message.
- Field 2 (`tag 0x12`, length-delimited): an ASCII **string argument** (e.g. a filename),
  encoded as `12 <len:varint> <bytes>`.
- Field 2, varint (`tag 0x10`): a small integer value in some replies.
- Field 3 (`tag 0x1a`, length-delimited): a **bytes/string blob** (device info, file
  list), encoded as `1a <len:varint> <bytes>`.

You do not need a full protobuf library; the messages are tiny and fixed-shape. A minimal
hand-rolled reader for tags `0x08`, `0x10`, `0x12`, `0x1a` suffices.

### 5.3 Opcode reference

`op` is the varint after the leading `0x08`.

| op   | name (assigned)   | request body                         | reply body                                  |
|------|-------------------|--------------------------------------|---------------------------------------------|
| 0x03 | HELLO             | `08 03`                              | `08 03 10 02` (field2 varint = 2)           |
| 0x04 | SESSION           | `08 04 12 04 "3197"`                 | `08 04`                                      |
| 0x0d | DEVICE_INFO       | `08 0d 12 0a "1784904552"`           | `08 0d 1a <len> <blob>` (section 5.4)        |
| 0x73 | STATUS / KEEPALIVE| `08 73`                              | `08 73 10 36` then `08 73`                   |
| 0x6e | LIST              | `08 6e`                              | 1st: `08 6e 10 16 1a 00`; 2nd: file list     |
| 0x6f | STAT              | `08 6f 12 0c "<filename>"`           | `08 6f 1a 04 <size:uint32 LE>`               |
| 0x70 | SELECT / DOWNLOAD | `08 70 12 0c "<filename>"`           | `08 70` (sent only after UDP transfer ends)  |

Notes:

- The `"3197"` (SESSION) and `"1784904552"` (DEVICE_INFO) arguments look like a session id
  and a numeric token. Their derivation is unknown, but **the exact captured values can be
  replayed verbatim** and the adapter accepts them (confirmed by the probe). They do not
  need to be freshly generated per session.
- STATUS (0x73): the first reply carries field2 = 54 ("busy"); the client must keep polling
  (and must already have registered the UDP port, section 6.1) until STATUS returns a bare
  ack (`08 73`, no field2). Only then does the session advance.
- LIST (0x6e): while not ready the reply carries field2 = 22 with an empty blob. This is a
  "not ready / flash not yet enumerated" state — **not** a file count. It clears (blob
  populates with the filename string) only after the MSP prepare command (section 4). Poll
  LIST until the blob is non-empty.
- The SELECT reply (`08 70`) is not sent until the entire UDP bulk transfer has completed
  (see timeline, section 8). Treat SELECT as "begin download; ack on completion", not as an
  immediate acknowledgement. Re-issuing SELECT restarts the burst (section 6.1.1).

### 5.4 DEVICE_INFO blob (op 0x0d)

The reply blob (field 3, 239 bytes in this capture) is a set of NUL-separated ASCII fields
followed by a semi-binary tail. Decoded segments:

```
"ADPT03116"          model / firmware id
"048308E8C571"       adapter MAC, uppercase hex, no separators
"SBADAPTER3_C571"     SSID
"SBWiFi"             mode / interface label
"178490455"          numeric id (relates to the SESSION/DEVICE_INFO tokens)
c2 01                small binary field
2d f4 51 58 01 84 2d fd fd 64 32 84   binary preamble, then ASCII digits follow
"13333953673183413" ...
... further NUL-separated numeric/short-code fields (counters, ids); not needed for
    log download.
```

Only the model id, MAC, SSID, and mode label are meaningful for identification. The trailing
fields are not required to list or download logs.

### 5.5 File listing (op 0x6e)

Second LIST reply blob is a single string: filenames separated by backslash `\`, with a
trailing backslash:

```
BTFL_001.BBL\BTFL_002.BBL\BTFL_ALL.BBL\PADDING.TXT\
```

Parse: split on `\`, drop empty tokens. Filename semantics:

- `BTFL_NNN.BBL` — a real per-flight blackbox log. Ordering by NNN matches recording order.
  Download these.
- `BTFL_ALL.BBL` — adapter-synthesized concatenation of every BTFL_NNN log. Its size equals
  the sum of the individual sizes. Do **not** offer it as an import target: individual
  files are what users want, and the aggregate wastes bandwidth. It exists so the SpeedyBee
  app can offer a "download everything" shortcut.
- `PADDING.TXT` — filler that pads the FC flash to a fixed size. Not a real log. Ignore.
- Any other filename — treat as a real BBL if it ends in `.BBL`; skip otherwise.

If the FC has no logs, the list still contains `BTFL_ALL.BBL` (empty) and `PADDING.TXT`.
A UI should surface "no logs" when no `BTFL_NNN.BBL` entries are present.

Recommended filter for the import UI: `name` matches `^BTFL_\d+\.BBL$` (case-sensitive).

### 5.6 File stat (op 0x6f)

- Request: `08 6f 12 0c "BTFL_001.BBL"` (`0x0c` = 12 = filename length).
- Reply: `08 6f 1a 04 <size:uint32 LE>`.

Observed:

| File          | size bytes (hex `1a 04` payload) | decimal      |
|---------------|----------------------------------|--------------|
| BTFL_001.BBL  | `00 30 1f 00`                    | 2,043,904    |
| BTFL_002.BBL  | `00 d0 e0 00`                    | 14,733,312   |

The stat size is authoritative and is used to truncate the padded UDP payload
(section 6.3).

### 5.7 File select (op 0x70)

- Request: `08 70 12 0c "<filename>"`.
- Reply: `08 70`, delivered only after the UDP transfer completes.

This is the trigger that makes the adapter start streaming the selected file over UDP.

## 7. UDP 4281 — bulk data channel

### 6.1 Client trigger and port registration

The client sends a UDP datagram to `192.168.1.1:4281` with exactly this 10-byte payload:

```
53 50 45 45 44 59 42 45 45 00   =  "SPEEDYBEE\0"
```

The datagram's UDP source port is the port the adapter then streams the file to, so
`"SPEEDYBEE\0"` doubles as "register my receive port / I am ready". Confirmed behaviour:

- The trigger must be sent **early**, during the control-channel status handshake, not just
  before the bulk transfer. The STATUS field2 "busy" value (54) only clears to a bare ack
  once the UDP port has been registered via this trigger; the session will not advance
  otherwise.
- The actual burst begins only after the SELECT (op 0x70) request. SELECT + one trigger
  starts it.

### 6.1.1 Packet-loss recovery (confirmed)

UDP has no built-in retransmission and the adapter does not implement selective repeat:

- Re-sending a bare `"SPEEDYBEE\0"` after a burst has finished is **ignored** by the
  adapter (verified: 20+ re-triggers produced zero packets).
- The only way to recover missing packets is to **re-issue SELECT (op 0x70)**, which
  restarts the whole burst from sequence 0. The client keeps a `seq -> data` map and
  deduplicates, so a reburst only fills the gaps (already-received sequences are ignored).
- In practice, observed losses were receiver-side (the client's UDP socket buffer
  overflowing during the ~150 KiB/s burst), not on-air. Setting a large `SO_RCVBUF`
  (e.g. 8 MiB) reduces this to zero or one missing packet per download, so at most one
  reburst is needed. A pure-Python per-packet CRC is enough to keep up at this rate.
- Throughput observed: ~150 KiB/s (roughly 75 packets/s). A ~2 MB log takes ~14 s.

There may be a smarter targeted re-request we have not found, but re-SELECT is confirmed to
work and always converges.

### 6.2 Data packet layout

Every adapter → client data datagram has a 2048-byte payload:

```
offset 0..1     : sequence number   uint16 LE   (0, 1, 2, ... , N-1)
offset 2..3     : CRC-16/MODBUS      uint16 LE   over bytes 4..2047
offset 4..2047  : file data          2044 bytes
```

- CRC parameters (verified against every captured packet): CRC-16/MODBUS — polynomial
  `0x8005` reflected (`0xA001`), init `0xFFFF`, input and output reflected, no final XOR,
  result stored little-endian. Computed over the 2044-byte data region only.
- Sequence numbers are contiguous from 0. For `BTFL_001.BBL` the range was 0..999
  (1000 packets).

### 6.3 Sizing and the final packet

- File size (from STAT) = 2,043,904 bytes.
- 2,043,904 = 999 × 2044 + 1948. So packets 0..998 carry 2044 real bytes each, and packet
  999 carries 1948 real bytes.
- The last packet's data region is still transmitted as a full 2044 bytes (padded). The
  client truncates the reassembled stream to the STAT size to drop the padding.
- General rule: `packet_count = ceil(file_size / 2044)`; the last packet has
  `file_size - (packet_count-1)*2044` real bytes; discard the rest.

### 6.4 Reassembly algorithm

```
open UDP socket, note local port P
send "SPEEDYBEE\0" to 192.168.1.1:4281 from port P
buffer = {}                       # seq -> 2044-byte data region
while len(buffer) < packet_count:
    datagram = recv()             # expect 2048 bytes
    seq = u16le(datagram[0:2])
    crc = u16le(datagram[2:4])
    data = datagram[4:2048]
    if crc16_modbus(data) != crc: continue      # drop corrupt
    buffer[seq] = data
    # (loss recovery: see section 9)
file = concat(buffer[s] for s in range(packet_count))
file = file[:file_size]           # truncate padding on last packet
```

This procedure applied to the capture (944 of 1000 packets; 56 dropped by the passive
sniffer, all captured packets passing CRC) produced a valid Betaflight log beginning:

```
H Product:Blackbox flight data recorder by Nicholas Sherlock
H Data version:2
H Field I name:loopIteration,time,axisP[0],...
```

### 7.6 TCP 4281 (co-located, unused)

The port 4281 is also open as a TCP listener. During the bulk transfer the app opens two
TCP connections to `192.168.1.1:4281` but never sends payload on them; only SYN/ACK/FIN.
Airframe should ignore this port entirely. It is documented here so an implementation does
not wait on it or interpret its openness as meaningful.

## 8. Full annotated timeline (this capture)

Times are seconds relative to capture start.

```
32.83   DHCP DISCOVER/OFFER/REQUEST/ACK  (adapter leases 192.168.1.2; GW+DNS 192.168.1.1)
35.83   TCP SYN -> 4279 and 4278
35.84   C->S 4279  08 03                         HELLO
35.95   S->C 4279  08 03 10 02                    hello reply (val 2)
35.95   C->S 4279  08 04 12 04 "3197"             SESSION
35.96   S->C 4279  08 04                          session ack
35.97   C->S 4279  08 0d 12 0a "1784904552"       DEVICE_INFO request
35.99   S->C 4279  08 0d 1a ef01 <239-byte blob>  device info
36.09   C->S 4279  08 73                          STATUS poll
36.09   C->S UDP   "SPEEDYBEE\0" -> :4281         register UDP port 57035  (#1)
36.35   C->S 4279  08 73                          STATUS poll (retry, still no reply)
41.10   S->C 4279  08 73 10 36                    status reply (val 0x36)
41.11   C->S 4279  08 73                          STATUS poll
41.11   C->S UDP   "SPEEDYBEE\0" -> :4281         register UDP port (#2)
41.13   S->C 4279  08 73                          status ack
41.15   C->S 4278  $M< 01 44 02 47                MSP prepare (cmd 0x44 payload 0x02)
41.18   S->C 4278  $M> 02 44 02 01 45             MSP prepare reply
41.20   C->S 4279  08 6e                          LIST request #1
41.21   S->C 4279  08 6e 10 16 1a 00              list reply #1 (val 22, not ready)
42.26   C->S 4279  08 6e                          LIST request #2
42.38   S->C 4279  08 6e 1a 33 "BTFL_001.BBL\..." file list
42.39   TCP SYN -> 4281                           (unused)
43.39   TCP SYN -> 4281                           (unused)
43.44   C->S 4279  08 6f 12 0c "BTFL_001.BBL"     STAT
43.86   S->C 4279  08 6f 1a 04 00301f00           size = 2,043,904
43.88   C->S 4279  08 6f 12 0c "BTFL_002.BBL"     STAT
44.28   S->C 4279  08 6f 1a 04 00d0e000           size = 14,733,312
45.82   C->S 4279  08 70 12 0c "BTFL_001.BBL"     SELECT / start download
46.29 .. 59.26     S->C UDP burst on :4281 -> client :57035   (seq 0..999, 2048 B each)
59.27   S->C 4279  08 70                          SELECT reply / transfer-complete ack
```

## 9. Open questions

None remain for the log-download workflow. Everything from BLE-triggered WiFi activation
through the WiFi bulk transfer to a byte-valid `.BBL` file has been captured, reproduced,
and verified. Ideas worth exploring later if we go deeper:

- Op-code map beyond what we use (0x05..0x0c, 0x10..0x16, 0x19..0x6d, 0x71..0x72, 0x74..0x7f
  are unassigned in what we have seen). Some likely cover firmware update, reboot, disable
  WiFi, and adapter-side settings that Airframe does not need for imports.

Resolved during this work:

- **BLE trigger for WiFi mode: op `0x18` on ABF3** (section 3). Preceded by an optional op
  `0x17` to obtain the SSID + MAC.
- Packet-loss recovery: a bare `"SPEEDYBEE\0"` re-trigger after a finished burst is ignored;
  recovery is done by re-issuing SELECT (op 0x70), which restarts the burst from sequence 0,
  with client-side dedupe. No selective NACK exists.
- The MSP "prepare" command on 4278 is required before listing. It is `MSP_SET_REBOOT`
  (code 68) with reboot mode 2 (mass storage), so it reboots the FC into MSC and the adapter
  serves the exposed filesystem over WiFi. Its `[rebootMode, readiness]` reply is optional:
  one FC returned `[2, 1]`, another returned nothing yet still exposed the flash and downloaded
  successfully. Do not require the reply; retry only while a present reply reports readiness 0.
  The implicit "release" is a normal FC reboot back to firmware or a power cycle; no explicit
  dismount command is needed for the import workflow.
- Session tokens (`"3197"`, `"1784904552"`) can be replayed verbatim.
- STATUS must settle to a bare ack, and the UDP port must be registered early, before the
  session advances.

## 10. Reference-implementation notes (Airframe)

- Pure TCP + UDP sockets; no third-party dependencies.
- Control channel: implement the `[u16 len]` framer (with the adapter-side leading varint)
  and a tiny protobuf reader/writer for tags `0x08`, `0x10`, `0x12`, `0x1a`. A full
  protobuf runtime is unnecessary.
- CRC-16/MODBUS is a few lines; reuse for per-packet integrity.
- Two sockets plus one MSP connection: control (TCP 4279), MSP (TCP 4278), and the UDP data
  socket (4281). Open the UDP socket and send the trigger early (during status polling).
- Model the transfer as an explicit state machine — `idle → handshaking → registering(UDP) →
  statusSettling → preparing(MSP) → listing → stat → selected → streaming → complete` — with
  a typed error enum (connection, framing, checksumMismatch, incompleteAfterRebursts,
  unexpectedOpcode, prepareTimeout). This matches Airframe's "make invalid states
  unrepresentable" and typed-error rules.
- Give the UDP socket a large receive buffer (`SO_RCVBUF`, several MiB) to avoid
  receiver-side drops; recover any remaining gaps by re-issuing SELECT.
- The resulting bytes are a raw `.BBL` and feed directly into the existing blackbox parser.
- Security note (for any publication): the WiFi AP is open and unauthenticated; anyone in
  range can enumerate and download logs. Worth stating; not an Airframe bug to fix.

## 11. Live probe script

`tools/speedybee_wifi_probe.py` (in this workspace) implements the full flow against a live
adapter the machine is joined to, logging every byte in and out. It is a working download
client, not just a probe: it was used to verify this document end to end (listed the files
and downloaded `BTFL_001.BBL` complete and CRC-valid). Standard library only. See the script
header for usage.

## 12. Full working sequence (confirmed)

BLE phase (only needed if WiFi is not already up):

1. Discover and connect to the adapter over BLE. Its advertised name is `SBADAPTER3_*`; the
   MAC is stable per device. Discover service `0xABF0`, subscribe to notifications on
   `0xABF2` and `0xABF4`.
2. Optional: run the standard MSP identification round on `ABF1/ABF2` (`MSP_FC_VARIANT`,
   `MSP_API_VERSION`, ...) — this is what the app does, but the WiFi trigger works without it.
3. Control channel over `ABF3/ABF4`: HELLO (0x03), SESSION (0x04, `"3197"`), DEVICE_INFO
   (0x0d, `"1784904552"`). Same protocol as TCP 4279 (section 6).
4. Write `02 00 08 17` to `ABF3` → receive WIFI_INFO on `ABF4`: adapter SSID and MAC in a
   46-byte blob. Useful to display to the user or auto-join.
5. Write `02 00 08 18` to `ABF3` → adapter brings up its open WiFi AP within a few seconds.
   No reply is expected on BLE; disconnect BLE and switch transports.

WiFi phase:

6. Join adapter WiFi (`SBADAPTER3_*`, open); DHCP assigns the client an address.
7. TCP connect 4279 (control) and 4278 (MSP).
8. Open a UDP socket; note its local port.
9. Control: HELLO (0x03), SESSION (0x04, `"3197"`), DEVICE_INFO (0x0d, `"1784904552"`).
10. Send `"SPEEDYBEE\0"` to `:4281` from the UDP socket, then poll STATUS (0x73), re-sending
    the trigger each poll, until STATUS returns a bare ack.
11. MSP: send `$M< cmd=0x44 payload=0x02` on 4278 (`MSP_SET_REBOOT` mode 2, mass storage).
    Treat a missing reply as success; if a reply arrives, resend only while its readiness byte
    is 0. Do not block the flow on the reply (see section 5).
12. Poll LIST (0x6e) until the reply blob is non-empty; parse backslash-separated names.
13. STAT (0x6f) the target file to get its uint32 size.
14. SELECT (0x70) the file and send one `"SPEEDYBEE\0"`; the UDP burst begins.
15. Receive 2048-byte datagrams: seq (u16 LE) + CRC16/MODBUS (u16 LE) + 2044 data. Verify
    CRC, store by seq, dedupe. On stall, re-issue SELECT to reburst until all seqs present.
16. Concatenate data by seq and truncate to the STAT size. Result is a raw `.BBL`.

## 13. Test vectors (for unit tests)

Real byte sequences from the capture, safe to hardcode in tests:

```
# BLE control channel (ABF3 write, ABF4 notify)
BLE WIFI_INFO request      : 02 00 08 17                              (write to ABF3)
BLE WIFI_INFO reply        : 33 00 32 08 17 1a 2e "SBADAPTER3_C571"
                             00 00 ... 00 "048308E8C571" a5           (notify from ABF4)
BLE WIFI_START request     : 02 00 08 18                              (write to ABF3)

# WiFi control channel (TCP 4279)
HELLO request              : 02 00 08 03
HELLO reply                : 05 00 04 08 03 10 02
SESSION request            : 08 00 08 04 12 04 33 31 39 37            ("3197")
MSP prepare request        : 24 4d 3c 01 44 02 47                     ($M< cmd 0x44 pl 0x02)
MSP prepare reply          : 24 4d 3e 02 44 02 01 45                  ($M> payload 02 01)
LIST reply (file list body): 08 6e 1a 33 42 54 46 4c 5f 30 30 31 2e 42 42 4c 5c ...
STAT reply (BTFL_001)      : 09 00 08 08 6f 1a 04 00 30 1f 00         (size 2,043,904)
UDP trigger                : 53 50 45 45 44 59 42 45 45 00            ("SPEEDYBEE\0")
UDP data packet 0 (head)   : 00 00 e0 ff 48 20 50 72 6f 64 75 63 74 3a ...  ("H Product:")
  seq = 0x0000, crc = 0xffe0 = CRC16/MODBUS(data[0:2044])
```

## 14. Implementation checklist and gotchas

Everything below has already caused a wasted iteration during this reverse-engineering
work. Consult this list before writing code and again before declaring the importer done.

### 14.1 BLE

- [ ] Discover by service UUID `0000ABF0-0000-1000-8000-00805F9B34FB`, resolve
      characteristics by UUID (`0xABF1`–`0xABF4`), never by handle.
- [ ] Request the maximum ATT MTU on connect (iOS/macOS: CoreBluetooth negotiates
      automatically; verify `maximumWriteValueLength(for:)` is ≥ 248 and refuse to
      proceed otherwise).
- [ ] Write `01 00` to the CCCD (`0x2902`) of both `ABF2` and `ABF4` **before** sending
      any command. On CoreBluetooth this is `setNotifyValue(true, for:)` on both
      characteristics.
- [ ] Use write-without-response (`CBCharacteristicWriteType.withoutResponse`) for all
      writes to `ABF1` and `ABF3`.
- [ ] Run the control-channel handshake HELLO → SESSION → DEVICE_INFO **on BLE** exactly
      as on WiFi. Same bytes, same framing. Session tokens (`"3197"`, `"1784904552"`) can
      be replayed verbatim.
- [ ] Send `02 00 08 17` (WIFI_INFO); parse SSID + MAC out of the reply. Show them to the
      user so they know which network the device is bringing up.
- [ ] Send `02 00 08 18` (WIFI_START); do **not** wait for a reply.
- [ ] Disconnect BLE before the WiFi join. The Espressif SoC time-shares the radio; the
      AP comes up faster and more reliably without a lingering BLE link.

### 14.2 WiFi

- [ ] Scan/join the SSID from WIFI_INFO. Open, no PSK. Do not hardcode the channel.
- [ ] On iOS use `NEHotspotConfiguration` with `joinOnce = true`; on macOS use the
      `CWWiFiClient` join API. Both must handle the case where the user's current WiFi is
      needed elsewhere — Airframe should offer to rejoin the prior network after the
      import.
- [ ] The adapter is always at `192.168.1.1`; do **not** discover via mDNS (the adapter
      advertises nothing).
- [ ] Open the UDP receive socket **early**, before starting STATUS polling. The adapter
      only leaves STATUS "busy" (field2 = 54) once it has seen a `"SPEEDYBEE\0"` datagram
      from the client on port 4281. Send that datagram between STATUS polls too.
- [ ] Set `SO_RCVBUF` on the UDP socket to at least 4 MiB (8 MiB is safer). Without this,
      the ~150 KiB/s burst overruns the default socket buffer and dozens of packets are
      lost.
- [ ] After STATUS settles to a bare ack, send the MSP prepare command `$M< 01 44 02 47` on
      TCP 4278 (`MSP_SET_REBOOT` mode 2, mass storage). Do **not** require the reply: one FC
      returns `$M> 02 44 02 01 45`, another returns nothing yet still exposes the flash. Treat a
      missing reply as success; if a reply arrives with readiness 0 (`payload[1] == 0`), resend
      a few times (the filesystem can be briefly busy right after boot) before failing. Without
      this step, LIST never populates. Prove success by LIST, not by this reply (see section 5).
- [ ] Poll LIST (op 0x6e) with ~0.7 s delay until the reply blob is non-empty. Filter
      filenames by `^BTFL_\d+\.BBL$` before offering them to the user; skip
      `BTFL_ALL.BBL`, `PADDING.TXT`, and anything else.
- [ ] STAT (op 0x6f) each file the user selected to get its uint32 size. This size is
      authoritative and is used to truncate the final packet's padding.
- [ ] SELECT (op 0x70) to start the burst; the reply on TCP 4279 does **not** come back
      until the transfer completes. Don't block on it while receiving UDP data.
- [ ] Receive UDP packets; verify each one's CRC-16/MODBUS over the 2044-byte data
      region; keep a `seq → bytes` map to deduplicate. If a stall of ≥ 2 s occurs and
      packets are missing, re-issue SELECT (bare `"SPEEDYBEE\0"` triggers are ignored
      after a burst finishes).
- [ ] Cap rebursts at ~5. Beyond that, surface a "download failed" typed error rather
      than looping forever.
- [ ] Concatenate the data regions in seq order and truncate to the STAT size. Result is
      a raw Betaflight `.BBL`; it feeds the existing blackbox pipeline unchanged.
- [ ] After completion, treat WiFi mode as one-shot: don't re-issue op 0x18 across
      imports in the same power cycle unless the AP is actually gone.

### 14.3 Error surfaces (typed)

Model the transfer as a state machine and use a typed error enum. All the failure modes
that were observed:

- `bleMtuTooSmall(negotiated: Int)` — MTU < 248 after connect.
- `bleNotifyEnableFailed(characteristic: UUID)` — CCCD write failed.
- `bleTriggerNotAcked` — the app-side timeout waiting for the WiFi AP after WIFI_START.
- `wifiJoinFailed(underlying: Error)` — could not join the adapter's SSID.
- `controlFrameMalformed(offset: Int)` — parser hit an unexpected wire tag / length.
- `statusStuckBusy` — STATUS never settled to a bare ack.
- `prepareTimeout` — MSP prepare got no reply after N retries.
- `listStuckBusy` — LIST never populated after M polls.
- `unknownOpcode(op: UInt8)` — reply carried an op we did not send.
- `checksumMismatch(seq: UInt16, expected: UInt16, got: UInt16)` — a UDP packet failed
  CRC (rare with proper `SO_RCVBUF`; ignore and dedupe the retry).
- `incompleteAfterRebursts(missingCount: Int)` — recovery gave up.
- `unexpectedFileTruncation(expected: Int, got: Int)` — final byte count didn't match
  STAT; the truncation-to-STAT rule should prevent this if the burst completed, so this
  indicates a bug in the client.

### 14.4 Timeouts (values that worked in practice)

- Control-channel single-request/reply on BLE and TCP: 2 s per exchange.
- STATUS poll interval: 0.7 s; overall STATUS-settle budget: 15 s.
- MSP prepare: 2 s per attempt, 3 attempts.
- LIST poll interval: 0.7 s; overall budget: 15 s.
- UDP receive: 2 s inactivity → stall → reburst.
- Reburst cap: 5.
- WiFi AP appearance after WIFI_START: 10 s scan budget.

### 14.5 Do not

- Do not hardcode the SSID or the WiFi channel. Both come from WIFI_INFO / scan.
- Do not hardcode the adapter MAC. Read it from WIFI_INFO or from the BLE peripheral.
- Do not try to speak MSP over WiFi's TCP 4278 for anything other than the prepare
  command. The port is a transparent bridge and the FC responds through it, but the
  official app only issues the single prepare there during a WiFi session.
- Do not try to enumerate more opcodes at runtime as part of the product. Fuzzing the
  adapter can crash it or corrupt FC flash. Keep experimentation confined to the probe.
- Do not publish captures that contain user-identifying MAC addresses, SSIDs, DNS
  queries, or DHCP hostnames.

## 15. Artifacts (temporary, not committed)

Under `/tmp/sb_adapter/`:
- `capture.pcapng` — full 802.11 monitor-mode capture of the WiFi transport.
- `srv_payloads.hex` — one hex line per UDP data packet.
- `reassembled_partial.bbl` — contiguous prefix reassembled from the (lossy) capture.

Under `~/Downloads/`:
- `SB-BT-Log1.pklg` — PacketLogger HCI capture of the BLE side that contains the
  `ABF3` writes for `WIFI_INFO` (op 0x17) and `WIFI_START` (op 0x18) and the `ABF4`
  reply carrying the SSID and MAC. Read with `tshark -r SB-BT-Log1.pklg -Y btatt`.

Under `/tmp/`:
- `dl.bbl` — complete `BTFL_001.BBL` downloaded live by the probe (2,043,904 bytes, all
  packets CRC-valid).
