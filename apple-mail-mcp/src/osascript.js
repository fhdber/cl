import { execFile } from 'node:child_process';

const TIMEOUT_MS = Number(process.env.APPLE_MAIL_MCP_TIMEOUT_MS) || 120_000;

/** Führt ein Skript per osascript aus. Argumente gehen als argv rein, nie in den Quelltext. */
export function osascript(lang, script, args = []) {
  return new Promise((resolve, reject) => {
    execFile(
      'osascript',
      ['-l', lang, '-e', script, ...args],
      { timeout: TIMEOUT_MS, maxBuffer: 50 * 1024 * 1024 },
      (err, stdout, stderr) => {
        if (err) return reject(new Error(explain(stderr || err.message, err)));
        resolve(stdout.trim());
      },
    );
  });
}

export async function jxa(script, params = {}) {
  const out = await osascript('JavaScript', script, [JSON.stringify(params)]);
  return out ? JSON.parse(out) : null;
}

function explain(msg, err) {
  if (err?.killed) return `Zeitüberschreitung nach ${TIMEOUT_MS / 1000}s. Suche eingrenzen (Zeitraum, Postfach, Account).`;
  if (/-1743|Not authori[sz]ed/i.test(msg)) {
    return 'Kein Zugriff auf Mail. Systemeinstellungen → Datenschutz & Sicherheit → Automation: ' +
      'der App, die den MCP startet (Claude, Terminal …), den Zugriff auf „Mail“ erlauben.';
  }
  if (/-1728|Can.t get|Kann .* nicht/i.test(msg)) {
    return 'Nachricht/Postfach nicht gefunden (evtl. verschoben oder gelöscht). Neu suchen. Details: ' + clean(msg);
  }
  return clean(msg);
}

const clean = (s) => String(s).replace(/^.*execution error: /s, '').trim();
