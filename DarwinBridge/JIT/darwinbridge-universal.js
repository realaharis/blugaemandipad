// DarwinBridge JIT26 launch script - minimal/stable
// LiveContainer + StikDebug, iOS/iPadOS 26+.
//
// DarwinBridge protocol:
//   BRK #0xf00d, x16=1 -> allocate/prepare RX region
//   BRK #0xf00d, x16=0 -> optional detach
//
// This version intentionally removes legacy/dynamic script handlers and avoids
// issuing a second continue after vCont already resumed the inferior.

const CMD_DETACH = 0n;
const CMD_PREPARE_REGION = 1n;
const BRK_IMMEDIATE = 0xf00d;

function leHexToBigInt(hex) {
    if (typeof hex !== "string" || (hex.length & 1) !== 0) return null;
    const bytes = [];
    for (let i = 0; i < hex.length; i += 2) {
        const v = parseInt(hex.slice(i, i + 2), 16);
        if (Number.isNaN(v)) return null;
        bytes.push(v);
    }

    let value = 0n;
    for (let i = bytes.length - 1; i >= 0; --i) {
        value = (value << 8n) | BigInt(bytes[i]);
    }
    return value;
}

function bigIntToLE64(value) {
    let n = BigInt.asUintN(64, value);
    const bytes = [];
    for (let i = 0; i < 8; ++i) {
        bytes.push(Number(n & 0xffn).toString(16).padStart(2, "0"));
        n >>= 8n;
    }
    return bytes.join("");
}

function littleEndianU32(hex) {
    if (typeof hex !== "string" || hex.length !== 8) return null;
    const b0 = parseInt(hex.slice(0, 2), 16);
    const b1 = parseInt(hex.slice(2, 4), 16);
    const b2 = parseInt(hex.slice(4, 6), 16);
    const b3 = parseInt(hex.slice(6, 8), 16);
    if ([b0, b1, b2, b3].some(Number.isNaN)) return null;
    return ((b0) | (b1 << 8) | (b2 << 16) | (b3 << 24)) >>> 0;
}

function extractBRKImmediate(insn) {
    return (insn >>> 5) & 0xffff;
}

function parseThread(stop) {
    const m = /thread:(?<tid>[0-9a-f]+);/i.exec(stop || "");
    return m ? m.groups.tid : null;
}

function parseRegister(stop, regNumber) {
    const key = regNumber.toString(16).padStart(2, "0");
    const re = new RegExp("(?:^|;)" + key + ":(?<reg>[0-9a-f]{16});", "i");
    const m = re.exec(stop || "");
    return m ? leHexToBigInt(m.groups.reg) : null;
}

function parseSignal(stop) {
    const m = /^T(?<sig>[0-9a-f]{2})/i.exec(stop || "");
    return m ? m.groups.sig : null;
}

function writeRegister(regNumber, value, tid) {
    const reg = regNumber.toString(16);
    return send_command(`P${reg}=${bigIntToLE64(value)};thread:${tid};`);
}

const pid = get_pid();
log(`DBJIT26: pid=${pid}`);

let stop = send_command(`vAttach;${pid.toString(16)}`);
log(`DBJIT26: attach=${stop}`);

let running = true;

while (running) {
    if (typeof stop !== "string" || stop.length === 0) {
        stop = send_command("c");
        continue;
    }

    if (/^[WX]/.test(stop)) {
        log(`DBJIT26: inferior ended: ${stop}`);
        break;
    }

    const tid = parseThread(stop);
    const pc = parseRegister(stop, 0x20);
    const x0 = parseRegister(stop, 0x00);
    const x1 = parseRegister(stop, 0x01);
    const x16 = parseRegister(stop, 0x10);

    if (!tid || pc === null || x16 === null) {
        log("DBJIT26: incomplete stop packet; resuming normally");
        stop = send_command("c");
        continue;
    }

    const rawInstruction = send_command(`m${pc.toString(16)},4`);
    const instruction = littleEndianU32(rawInstruction);
    const isBRK = instruction !== null &&
        (((instruction & 0xffe0001f) >>> 0) === 0xd4200000);

    if (!isBRK) {
        // vCont itself resumes and waits for the next stop. Use that returned
        // stop directly; do NOT issue another 'c' before processing it.
        const sig = parseSignal(stop);
        if (sig) {
            log(`DBJIT26: forwarding signal 0x${sig}`);
            stop = send_command(`vCont;S${sig}:${tid}`);
        } else {
            stop = send_command("c");
        }
        continue;
    }

    const imm = extractBRKImmediate(instruction);
    if (imm !== BRK_IMMEDIATE) {
        // An unrelated debugger breakpoint should not be consumed by our JIT
        // protocol. Advance past it without injecting SIGTRAP into the app.
        log(`DBJIT26: skipping unrelated BRK #0x${imm.toString(16)}`);
        writeRegister(0x20, pc + 4n, tid);
        stop = send_command("c");
        continue;
    }

    // DarwinBridge owns BRK #0xf00d. Move PC past the breakpoint first.
    const pcResponse = writeRegister(0x20, pc + 4n, tid);
    log(`DBJIT26: pc+4=${pcResponse}`);

    if (x16 === CMD_PREPARE_REGION) {
        if (x1 === null || x1 <= 0n) {
            log("DBJIT26: invalid prepare size");
            writeRegister(0x00, 0n, tid);
            stop = send_command("c");
            continue;
        }

        let rx = x0 === null ? 0n : x0;

        if (rx === 0n) {
            const command = `_M${x1.toString(16)},rx`;
            const response = send_command(command);
            log(`DBJIT26: ${command} => ${response}`);

            if (typeof response !== "string" ||
                !/^[0-9a-f]+$/i.test(response)) {
                log("DBJIT26: RX allocation failed");
                writeRegister(0x00, 0n, tid);
                stop = send_command("c");
                continue;
            }

            rx = BigInt("0x" + response);
        }

        try {
            const prepareResult = prepare_memory_region(rx, x1);
            log(`DBJIT26: prepare 0x${rx.toString(16)} size=0x${x1.toString(16)} => ${prepareResult}`);
        } catch (error) {
            log(`DBJIT26: prepare_memory_region failed: ${error}`);
            writeRegister(0x00, 0n, tid);
            stop = send_command("c");
            continue;
        }

        const x0Response = writeRegister(0x00, rx, tid);
        log(`DBJIT26: return RX 0x${rx.toString(16)} => ${x0Response}`);

        stop = send_command("c");
        continue;
    }

    if (x16 === CMD_DETACH) {
        log("DBJIT26: detach requested");
        send_command("D");
        running = false;
        break;
    }

    log(`DBJIT26: unknown command x16=${x16.toString()}`);
    writeRegister(0x00, 0n, tid);
    stop = send_command("c");
}
