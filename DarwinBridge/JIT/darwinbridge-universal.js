// DarwinBridge JIT26 launch script - LiveContainer-safe v2
// Key rule: do NOT re-inject the initial vAttach stop signal.
// The attach response is only logged; execution starts with a clean 'c'.

const CMD_DETACH = 0n;
const CMD_PREPARE_REGION = 1n;
const BRK_IMMEDIATE = 0xf00d;

function leHexToBigInt(hex) {
    if (typeof hex !== "string" || (hex.length & 1) !== 0) return null;
    let value = 0n;
    const bytes = [];
    for (let i = 0; i < hex.length; i += 2) {
        const v = parseInt(hex.slice(i, i + 2), 16);
        if (Number.isNaN(v)) return null;
        bytes.push(v);
    }
    for (let i = bytes.length - 1; i >= 0; --i) {
        value = (value << 8n) | BigInt(bytes[i]);
    }
    return value;
}

function bigIntToLE64(value) {
    let n = BigInt.asUintN(64, value);
    const out = [];
    for (let i = 0; i < 8; ++i) {
        out.push(Number(n & 0xffn).toString(16).padStart(2, "0"));
        n >>= 8n;
    }
    return out.join("");
}

function littleEndianU32(hex) {
    if (typeof hex !== "string" || hex.length !== 8) return null;
    const bytes = [];
    for (let i = 0; i < 4; ++i) {
        const v = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
        if (Number.isNaN(v)) return null;
        bytes.push(v);
    }
    return (bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)) >>> 0;
}

function parseThread(stop) {
    const m = /thread:(?<tid>[0-9a-f]+);/i.exec(stop || "");
    return m ? m.groups.tid : null;
}

function parseRegister(stop, number) {
    const key = number.toString(16).padStart(2, "0");
    const m = new RegExp("(?:^|;)" + key + ":(?<reg>[0-9a-f]{16});", "i").exec(stop || "");
    return m ? leHexToBigInt(m.groups.reg) : null;
}

function parseSignal(stop) {
    const m = /^T(?<sig>[0-9a-f]{2})/i.exec(stop || "");
    return m ? m.groups.sig : null;
}

function writeRegister(number, value, tid) {
    return send_command(`P${number.toString(16)}=${bigIntToLE64(value)};thread:${tid};`);
}

const pid = get_pid();
log(`DBJIT26-v2: pid=${pid}`);

const attachResponse = send_command(`vAttach;${pid.toString(16)}`);
log(`DBJIT26-v2: attach=${attachResponse}`);

// IMPORTANT: ignore the attach stop packet. Start execution normally.
let stop = send_command("c");

while (true) {
    if (typeof stop !== "string" || stop.length === 0) {
        stop = send_command("c");
        continue;
    }

    if (/^[WX]/.test(stop)) {
        log(`DBJIT26-v2: process ended: ${stop}`);
        break;
    }

    const tid = parseThread(stop);
    const pc = parseRegister(stop, 0x20);
    const x0 = parseRegister(stop, 0x00);
    const x1 = parseRegister(stop, 0x01);
    const x16 = parseRegister(stop, 0x10);

    if (!tid || pc === null || x16 === null) {
        log("DBJIT26-v2: unparsed stop; continuing");
        stop = send_command("c");
        continue;
    }

    const raw = send_command(`m${pc.toString(16)},4`);
    const insn = littleEndianU32(raw);
    const isBRK = insn !== null && (((insn & 0xffe0001f) >>> 0) === 0xd4200000);

    if (!isBRK) {
        // For ordinary debugger stops, continue without re-injecting the attach
        // stop signal. Only forward a signal after the app has actually run.
        const sig = parseSignal(stop);
        if (sig === "05") {
            // SIGTRAP unrelated to our BRK: resume cleanly.
            stop = send_command("c");
        } else if (sig) {
            stop = send_command(`vCont;S${sig}:${tid}`);
        } else {
            stop = send_command("c");
        }
        continue;
    }

    const imm = (insn >>> 5) & 0xffff;

    if (imm !== BRK_IMMEDIATE) {
        // Do not consume unknown app breakpoints by delivering SIGTRAP.
        // Advance past the instruction and resume.
        writeRegister(0x20, pc + 4n, tid);
        stop = send_command("c");
        continue;
    }

    // DarwinBridge owns BRK #0xf00d.
    writeRegister(0x20, pc + 4n, tid);

    if (x16 === CMD_PREPARE_REGION) {
        if (x1 === null || x1 <= 0n) {
            writeRegister(0x00, 0n, tid);
            stop = send_command("c");
            continue;
        }

        let rx = x0 === null ? 0n : x0;

        if (rx === 0n) {
            const response = send_command(`_M${x1.toString(16)},rx`);
            log(`DBJIT26-v2: RX alloc => ${response}`);

            if (typeof response !== "string" || !/^[0-9a-f]+$/i.test(response)) {
                writeRegister(0x00, 0n, tid);
                stop = send_command("c");
                continue;
            }

            rx = BigInt("0x" + response);
        }

        try {
            const result = prepare_memory_region(rx, x1);
            log(`DBJIT26-v2: prepare 0x${rx.toString(16)} => ${result}`);
            writeRegister(0x00, rx, tid);
        } catch (e) {
            log(`DBJIT26-v2: prepare failed: ${e}`);
            writeRegister(0x00, 0n, tid);
        }

        stop = send_command("c");
        continue;
    }

    if (x16 === CMD_DETACH) {
        send_command("D");
        break;
    }

    writeRegister(0x00, 0n, tid);
    stop = send_command("c");
}
