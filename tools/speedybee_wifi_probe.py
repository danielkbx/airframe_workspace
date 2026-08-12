#!/usr/bin/env python3
"""SpeedyBee Adapter 3 WiFi log-download probe / client.

Replays the control-channel handshake and UDP bulk transfer documented in
knowledge/SPEEDYBEE_REVERSE_ENGINEERING.md against a live adapter. It is both a working
downloader and a diagnostic instrument: every byte in and out of the control channel is
logged, and the UDP receive loop reports sequence gaps and loss-recovery behaviour so the
one remaining open question (how missing packets are re-requested) can be resolved from a
real, lossless session.

Requirements: the machine must already be joined to the adapter's open WiFi
(SBADAPTER3_*, gateway 192.168.1.1). No third-party packages; standard library only.

Usage:
    python3 speedybee_wifi_probe.py                 # list files only
    python3 speedybee_wifi_probe.py --get BTFL_001.BBL --out ./BTFL_001.BBL
    python3 speedybee_wifi_probe.py --host 192.168.1.1 --get BTFL_001.BBL

This tool only reads from the adapter. It never writes to or reconfigures the device.
"""

from __future__ import annotations

import argparse
import socket
import struct
import sys
import time
from dataclasses import dataclass, field

HOST = "192.168.1.1"
MSP_PORT = 4278
CONTROL_PORT = 4279
DATA_PORT = 4281
UDP_TRIGGER = b"SPEEDYBEE\0"

# MSP command the app issues on 4278 after the status handshake and before listing. It
# prepares the FC/adapter to expose the blackbox flash; without it the LIST reply never
# populates. Command 0x44 with a single payload byte 0x02 (captured verbatim).
MSP_PREPARE_CMD = 0x44
MSP_PREPARE_PAYLOAD = b"\x02"

PACKET_SIZE = 2048
DATA_PER_PACKET = 2044  # PACKET_SIZE - 4-byte header

# Opcodes (see protocol doc section 5.3).
OP_HELLO = 0x03
OP_SESSION = 0x04
OP_DEVICE_INFO = 0x0D
OP_STATUS = 0x73
OP_LIST = 0x6E
OP_STAT = 0x6F
OP_SELECT = 0x70


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def hexs(b: bytes, limit: int = 64) -> str:
    shown = b[:limit]
    tail = "" if len(b) <= limit else f" ... (+{len(b) - limit} B)"
    return shown.hex(" ") + tail


# --- CRC-16/MODBUS -----------------------------------------------------------------------

def crc16_modbus(data: bytes) -> int:
    crc = 0xFFFF
    for x in data:
        crc ^= x
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc


# --- minimal protobuf-style codec --------------------------------------------------------

def put_varint(value: int) -> bytes:
    out = bytearray()
    while True:
        b = value & 0x7F
        value >>= 7
        out.append(b | (0x80 if value else 0))
        if not value:
            return bytes(out)


def read_varint(buf: bytes, pos: int) -> tuple[int, int]:
    shift = 0
    value = 0
    while True:
        b = buf[pos]
        pos += 1
        value |= (b & 0x7F) << shift
        if not (b & 0x80):
            return value, pos
        shift += 7


def build_message(op: int, string_arg: bytes | None = None) -> bytes:
    """Client message: field1 varint op, optional field2 length-delimited string."""
    body = bytes([0x08]) + put_varint(op)
    if string_arg is not None:
        body += bytes([0x12]) + put_varint(len(string_arg)) + string_arg
    return body


def frame_client(message: bytes) -> bytes:
    return struct.pack("<H", len(message)) + message


@dataclass
class Fields:
    op: int | None = None
    ints: dict[int, int] = field(default_factory=dict)      # field number -> varint value
    blobs: dict[int, bytes] = field(default_factory=dict)   # field number -> bytes


def parse_message(message: bytes) -> Fields:
    """Parse the small protobuf-ish body. Handles tags 0x08/0x10 (varint) and
    0x12/0x1a (length-delimited)."""
    f = Fields()
    pos = 0
    while pos < len(message):
        tag = message[pos]
        pos += 1
        field_no = tag >> 3
        wire = tag & 0x07
        if wire == 0:  # varint
            value, pos = read_varint(message, pos)
            if field_no == 1:
                f.op = value
            else:
                f.ints[field_no] = value
        elif wire == 2:  # length-delimited
            length, pos = read_varint(message, pos)
            f.blobs[field_no] = message[pos:pos + length]
            pos += length
        else:
            raise ValueError(f"unsupported wire type {wire} at pos {pos}")
    return f


# --- control channel ---------------------------------------------------------------------

class Control:
    def __init__(self, host: str):
        self.sock = socket.create_connection((host, CONTROL_PORT), timeout=10)
        self.sock.settimeout(10)
        self.rx = bytearray()

    def close(self) -> None:
        try:
            self.sock.close()
        except OSError:
            pass

    def send(self, op: int, string_arg: bytes | None = None) -> None:
        msg = build_message(op, string_arg)
        frame = frame_client(msg)
        arg = f" arg={string_arg!r}" if string_arg is not None else ""
        log(f"C->S op=0x{op:02x}{arg}  raw={hexs(frame)}")
        self.sock.sendall(frame)

    def _fill(self, n: int) -> None:
        while len(self.rx) < n:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("control channel closed by adapter")
            self.rx.extend(chunk)

    def recv(self) -> Fields:
        """Read one adapter frame: [u16 outer_len][varint inner_len][message]."""
        self._fill(2)
        outer_len = struct.unpack_from("<H", self.rx, 0)[0]
        self._fill(2 + outer_len)
        payload = bytes(self.rx[2:2 + outer_len])
        del self.rx[:2 + outer_len]
        inner_len, off = read_varint(payload, 0)
        message = payload[off:]
        if inner_len != len(message):
            log(f"  note: inner_len={inner_len} but message is {len(message)} B "
                f"(continuing)")
        f = parse_message(message)
        log(f"S->C op=0x{(f.op or 0):02x} ints={f.ints} "
            f"blobs={{ {', '.join(f'{k}:{len(v)}B' for k, v in f.blobs.items())} }}  "
            f"raw={hexs(payload)}")
        return f

    def request(self, op: int, string_arg: bytes | None = None) -> Fields:
        self.send(op, string_arg)
        return self.recv()


class MSP:
    """MSPv1 passthrough on TCP 4278 (transparent bridge to the flight controller)."""

    def __init__(self, host: str):
        self.sock = socket.create_connection((host, MSP_PORT), timeout=10)
        self.sock.settimeout(10)

    def close(self) -> None:
        try:
            self.sock.close()
        except OSError:
            pass

    @staticmethod
    def _frame(cmd: int, payload: bytes) -> bytes:
        size = len(payload)
        checksum = size ^ cmd
        for b in payload:
            checksum ^= b
        return b"$M<" + bytes([size, cmd]) + payload + bytes([checksum])

    def command(self, cmd: int, payload: bytes = b"") -> bytes:
        frame = self._frame(cmd, payload)
        log(f"MSP-> cmd=0x{cmd:02x} payload={payload.hex()}  raw={hexs(frame)}")
        self.sock.sendall(frame)
        # Read one MSPv1 reply: $M> <size> <cmd> <payload...> <crc>.
        header = self._recv_exact(5)
        if header[:3] != b"$M>":
            raise ValueError(f"bad MSP reply header: {header!r}")
        size = header[3]
        rest = self._recv_exact(size + 1)  # payload + crc
        payload_out = rest[:size]
        log(f"MSP<- cmd=0x{header[4]:02x} payload={payload_out.hex()}")
        return payload_out

    def _recv_exact(self, n: int) -> bytes:
        buf = bytearray()
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("MSP channel closed by adapter")
            buf.extend(chunk)
        return bytes(buf)


class DataChannel:
    """Owns the UDP receive socket for the whole session. The adapter learns the client's
    receive port from the source port of the SPEEDYBEE trigger datagram, and the session
    state machine (STATUS / LIST) only advances once this port is registered, so the socket
    is opened early and the trigger is (re)sent throughout the session."""

    def __init__(self, host: str):
        self.host = host
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # A large receive buffer prevents drops during the ~150 KiB/s burst; without it the
        # kernel discards packets faster than the Python loop drains them.
        try:
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 * 1024 * 1024)
        except OSError:
            pass
        self.sock.bind(("", 0))
        self.port = self.sock.getsockname()[1]
        self.sock.settimeout(2.0)
        actual = self.sock.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
        log(f"  UDP receive port = {self.port} (rcvbuf {actual // 1024} KiB)")

    def trigger(self) -> None:
        self.sock.sendto(UDP_TRIGGER, (self.host, DATA_PORT))
        log(f"  sent UDP trigger {UDP_TRIGGER!r} -> {self.host}:{DATA_PORT} (port {self.port})")

    def close(self) -> None:
        try:
            self.sock.close()
        except OSError:
            pass


def handshake(ctrl: Control, data: DataChannel, msp: MSP) -> None:
    log("--- handshake ---")
    ctrl.request(OP_HELLO)
    ctrl.request(OP_SESSION, b"3197")
    info = ctrl.request(OP_DEVICE_INFO, b"1784904552")
    blob = info.blobs.get(3, b"")
    segments = [s for s in blob.split(b"\x00") if s]
    log(f"  device-info segments: {[s.decode('latin1') for s in segments[:5]]}")
    # Register the UDP receive port before polling status. In the reference capture the
    # STATUS field2 ("busy", 54) only cleared to a bare ack (08 73) after the SPEEDYBEE
    # trigger had been sent, so the trigger is a session prerequisite, not just a bulk-
    # transfer step. Re-send it on every poll until status settles.
    data.trigger()
    for i in range(20):
        reply = ctrl.request(OP_STATUS)
        if 2 not in reply.ints:
            log(f"  status settled to bare ack after {i + 1} poll(s)")
            break
        log(f"  status busy (attempt {i + 1}/20, value={reply.ints.get(2)}); waiting")
        data.trigger()
        time.sleep(0.7)
    # The app now issues an MSP command that makes the FC expose its blackbox flash. Without
    # it the LIST reply never populates (stays at the "busy" value 22). The FC can be slow
    # to answer right after a prior session, so retry on timeout.
    log("--- prepare (MSP) ---")
    for attempt in range(3):
        try:
            msp.command(MSP_PREPARE_CMD, MSP_PREPARE_PAYLOAD)
            return
        except (socket.timeout, TimeoutError):
            log(f"  MSP prepare timed out (attempt {attempt + 1}/3); retrying")
            time.sleep(1.0)
    raise ConnectionError("MSP prepare command got no reply after 3 attempts")


def list_files(ctrl: Control, attempts: int = 20, delay: float = 0.7) -> list[str]:
    log("--- list ---")
    # The adapter needs time to enumerate the FC flash. Early LIST replies carry only
    # field2 (a not-ready status/count, seen as 22) with an empty blob; the filename blob
    # appears once enumeration finishes. Poll until the blob is populated.
    names: list[str] = []
    for i in range(attempts):
        reply = ctrl.request(OP_LIST)
        names = _extract_list(reply)
        if names:
            break
        status = reply.ints.get(2)
        log(f"  list not ready (attempt {i + 1}/{attempts}, status={status}); waiting")
        time.sleep(delay)
    log(f"  files: {names}")
    return names


def _extract_list(f: Fields) -> list[str]:
    blob = f.blobs.get(3, b"")
    if not blob:
        return []
    return [n for n in blob.decode("latin1").split("\\") if n]


def stat_file(ctrl: Control, name: str) -> int:
    log(f"--- stat {name} ---")
    f = ctrl.request(OP_STAT, name.encode())
    raw = f.blobs.get(3, b"")
    if len(raw) < 4:
        raise ValueError(f"stat reply too short: {raw!r}")
    size = struct.unpack_from("<I", raw, 0)[0]
    log(f"  size = {size} bytes ({size / 1024:.1f} KiB)")
    return size


# --- UDP bulk transfer -------------------------------------------------------------------

def download(ctrl: Control, data: DataChannel, name: str, size: int) -> bytes:
    packet_count = (size + DATA_PER_PACKET - 1) // DATA_PER_PACKET
    log(f"--- download {name}: {size} B, expecting {packet_count} packets ---")

    udp = data.sock

    # SELECT begins the transfer; its reply arrives only after streaming completes, so send
    # it without blocking on the reply, then re-arm the (already registered) UDP port.
    def start_burst() -> None:
        ctrl.send(OP_SELECT, name.encode())
        data.trigger()

    start_burst()

    buffer: dict[int, bytes] = {}
    bad_crc = 0
    reburst = 0
    last_progress = time.monotonic()
    last_count = 0

    while len(buffer) < packet_count:
        try:
            datagram, _ = udp.recvfrom(PACKET_SIZE + 64)
        except socket.timeout:
            missing = [s for s in range(packet_count) if s not in buffer]
            # A bare SPEEDYBEE re-trigger after a finished burst is ignored by the adapter;
            # only a fresh SELECT restarts the stream. Re-run the whole burst and let the
            # sequence-number dedupe fill the gaps. With the large receive buffer, losses
            # are rare, so this fallback normally runs zero or one time.
            reburst += 1
            log(f"  stall: have {len(buffer)}/{packet_count}, missing {len(missing)} "
                f"(first: {missing[:8]}). re-issuing SELECT (reburst {reburst}).")
            if reburst > 5:
                log("  giving up after 5 rebursts")
                break
            start_burst()
            continue

        if len(datagram) < 4:
            log(f"  short datagram ({len(datagram)} B) raw={hexs(datagram)}")
            continue
        seq, crc = struct.unpack_from("<HH", datagram, 0)
        payload = datagram[4:]
        if crc16_modbus(payload[:DATA_PER_PACKET]) != crc:
            bad_crc += 1
            continue
        if seq not in buffer:
            buffer[seq] = payload[:DATA_PER_PACKET]

        now = time.monotonic()
        if now - last_progress >= 1.0:
            rate = (len(buffer) - last_count) * DATA_PER_PACKET / (now - last_progress)
            log(f"  {len(buffer)}/{packet_count} packets  {rate / 1024:.0f} KiB/s")
            last_progress = now
            last_count = len(buffer)

    # Drain the SELECT completion ack if it arrives.
    try:
        ctrl.recv()
    except (socket.timeout, ConnectionError):
        pass

    missing = [s for s in range(packet_count) if s not in buffer]
    log(f"  done: {len(buffer)}/{packet_count} packets, bad_crc={bad_crc}, "
        f"rebursts={reburst}, missing={len(missing)}")
    if missing:
        log(f"  WARNING incomplete, missing seqs: {missing[:32]}")

    out = bytearray()
    for s in range(packet_count):
        out += buffer.get(s, b"\x00" * DATA_PER_PACKET)
    return bytes(out[:size])


# --- main --------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="SpeedyBee Adapter 3 WiFi log probe")
    ap.add_argument("--host", default=HOST)
    ap.add_argument("--get", metavar="FILENAME", help="download this log file")
    ap.add_argument("--out", metavar="PATH", help="output path (default: ./<FILENAME>)")
    args = ap.parse_args()

    try:
        ctrl = Control(args.host)
        msp = MSP(args.host)
    except OSError as e:
        log(f"cannot reach adapter at {args.host}: {e}")
        log("is the machine joined to the SBADAPTER3 WiFi?")
        return 1

    data = DataChannel(args.host)
    try:
        handshake(ctrl, data, msp)
        names = list_files(ctrl)
        if not args.get:
            log("listing only; pass --get <FILENAME> to download")
            return 0
        if args.get not in names:
            log(f"'{args.get}' not in file list {names}")
            return 1
        size = stat_file(ctrl, args.get)
        # Stat the remaining files too, matching the observed app behaviour, is optional;
        # skipped here to keep the probe focused.
        file_bytes = download(ctrl, data, args.get, size)
        out_path = args.out or f"./{args.get}"
        with open(out_path, "wb") as fh:
            fh.write(file_bytes)
        log(f"wrote {len(file_bytes)} bytes to {out_path}")
        head = file_bytes[:60].decode("latin1", "replace")
        log(f"head: {head!r}")
        if not file_bytes.startswith(b"H Product:"):
            log("WARNING: output does not start with a Betaflight blackbox header")
        return 0
    except (OSError, ValueError, ConnectionError) as e:
        log(f"error: {e}")
        return 1
    finally:
        ctrl.close()
        msp.close()
        data.close()


if __name__ == "__main__":
    sys.exit(main())
