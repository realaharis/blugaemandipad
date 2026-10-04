// DarwinBridge StikDebug attachment helper.
// Keep the debugger attached to the current DarwinBridge process while it runs.
const pid = get_pid();
log(`DarwinBridge JIT: pid=${pid}`);
const attached = send_command(`vAttach;${pid.toString(16)}`);
log(`DarwinBridge JIT: attach=${attached}`);

while (true) {
    const response = send_command("c");
    if (typeof response === "string" && /^[WX]/.test(response)) {
        log(`DarwinBridge JIT: process ended (${response})`);
        break;
    }
}
