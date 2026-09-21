// Local Source 2 console client. Usage:
// node tools/epic_only/vconsole.js 'echo hello' 'script_reload_code epic_only_smoke'
// Options: --port 29000 --wait-ms 5000 --listen-ms 0
// Protocol reference (independent framing implementation):
// https://github.com/Demon673/dota2-mcp/blob/master/src/tools/vcon-bridge.ts
const net = require('node:net');

function commandFrame(command) {
  if (command.includes('\0')) throw new Error('Console commands cannot contain NUL');
  const body = Buffer.from(command + '\0', 'utf8');
  const frame = Buffer.alloc(12 + body.length);
  frame.write('CMND', 0, 4, 'ascii');
  frame.writeUInt16BE(212, 4);
  frame.writeUInt32BE(frame.length, 6);
  frame.writeUInt16BE(0, 10);
  body.copy(frame, 12);
  return frame;
}

function run(commands, { port = 29000, waitMs = 5000, listenMs = 0 } = {}) {
  return new Promise((resolve, reject) => {
    const socket = new net.Socket();
    let buffered = Buffer.alloc(0);
    let sending = false;
    let complete = false;
    let acknowledged = false;
    let closeTimer;
    let sendTimer;
    const marker = '__epic_only_vconsole_' + process.pid + '_' + Date.now() + '__';
    const deadline = setTimeout(() => finish(new Error('Timed out waiting for console command echo')), waitMs + listenMs);
    function finish(error) {
      if (complete) return;
      complete = true;
      clearTimeout(deadline);
      clearTimeout(closeTimer);
      clearTimeout(sendTimer);
      socket.destroy();
      if (error) reject(error); else resolve();
    }
    socket.setNoDelay(true);
    socket.on('error', finish);
    socket.on('close', () => {
      if (!complete) finish(acknowledged ? undefined : new Error('Console disconnected before acknowledging commands'));
    });
    socket.on('data', chunk => {
      buffered = Buffer.concat([buffered, chunk]);
      while (buffered.length >= 12) {
        const size = buffered.readUInt32BE(6);
        if (size < 12 || size > 16 * 1024 * 1024) {
          finish(new Error('Invalid VConsole frame length ' + size));
          return;
        }
        if (buffered.length < size) return;
        const type = buffered.toString('ascii', 0, 4);
        const payload = buffered.subarray(12, size);
        buffered = buffered.subarray(size);
        if (type !== 'PRNT' || payload.length < 28 || !sending) continue;
        const text = payload.subarray(28).toString('utf8').replace(/\0/g, '');
        if (text.includes(marker)) {
          acknowledged = true;
          if (!closeTimer) closeTimer = setTimeout(() => finish(), Math.max(100, listenMs));
        } else if (text) {
          process.stdout.write(text.endsWith('\n') ? text : text + '\n');
        }
      }
    });
    socket.connect(port, '127.0.0.1', () => {
      // Let the initial channel/CVar dump finish before printing command output.
      sendTimer = setTimeout(() => {
        sending = true;
        for (const command of commands) socket.write(commandFrame(command));
        socket.write(commandFrame('echo ' + marker));
      }, 250);
    });
  });
}

module.exports = { commandFrame, run };
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {};
  const commands = [];
  const optionNames = { '--port': 'port', '--wait-ms': 'waitMs', '--listen-ms': 'listenMs' };
  for (let i = 0; i < args.length; i++) {
    if (optionNames[args[i]]) {
      const key = optionNames[args[i]];
      const value = Number(args[++i]);
      if (!Number.isInteger(value) || value < 0) throw new Error('Invalid ' + key);
      options[key] = value;
    } else {
      commands.push(args[i]);
    }
  }
  if (!commands.length) {
    console.error('Usage: node tools/epic_only/vconsole.js [--wait-ms 5000] [--listen-ms 0] "echo hello"');
    process.exitCode = 1;
  } else {
    run(commands, options).catch(error => { console.error(error.message); process.exitCode = 1; });
  }
}
