// Skripte, die per `osascript` in Apple Mail laufen.
// Parameter kommen immer als argv (JSON bzw. einzelne Strings) – nie per String-Verkettung
// in den Quelltext. So kann kein Betreff, keine Adresse und kein Pfad Code einschleusen.

// Gemeinsame JXA-Helfer: Postfächer auflösen, Nachricht per Referenz finden.
const JXA_HELPERS = `
const Mail = Application('Mail');

const SPECIAL = {
  inbox:  ['inbox', 'posteingang', 'eingang'],
  sent:   ['sent', 'sent messages', 'sent items', 'sent mail', 'gesendet', 'gesendete objekte', 'gesendete e-mails'],
  drafts: ['drafts', 'entwürfe', 'entwurf'],
  trash:  ['trash', 'deleted messages', 'deleted items', 'papierkorb', 'gelöschte objekte', 'gelöschte e-mails'],
  junk:   ['junk', 'spam', 'junk e-mail', 'werbung'],
  archive:['archive', 'archiv', 'all mail', 'alle nachrichten'],
};

function specialKey(name) {
  const n = String(name).toLowerCase();
  for (const k in SPECIAL) if (k === n || SPECIAL[k].indexOf(n) !== -1) return k;
  return null;
}

// Liefert [{account, mailbox, spec}] für die gewünschten Postfächer.
function resolveMailboxes(accountName, mailboxName, allMailboxes) {
  const accounts = Mail.accounts();
  const out = [];
  let accountFound = !accountName;
  for (const acc of accounts) {
    const accName = acc.name();
    if (accountName && accName.toLowerCase() !== String(accountName).toLowerCase()) continue;
    accountFound = true;
    if (!acc.enabled()) continue;
    const names = acc.mailboxes.name();
    const target = mailboxName || 'inbox';
    const key = specialKey(target);
    for (let i = 0; i < names.length; i++) {
      const n = names[i];
      const lower = n.toLowerCase();
      let hit;
      if (allMailboxes) hit = true;
      else if (key) hit = SPECIAL[key].indexOf(lower) !== -1 || lower === key;
      else hit = lower === String(target).toLowerCase();
      if (hit) out.push({ account: accName, mailbox: n, spec: acc.mailboxes[i] });
    }
  }
  if (!accountFound) throw new Error('Account nicht gefunden: ' + accountName);
  return out;
}

function getMessage(p) {
  const acc = Mail.accounts.byName(p.account);
  const mb = acc.mailboxes.byName(p.mailbox);
  const msg = mb.messages.byId(Number(p.id));
  msg.subject(); // wirft, falls nicht vorhanden
  return msg;
}
`;

export const LIST_ACCOUNTS = `${JXA_HELPERS}
function run(argv) {
  const accounts = Mail.accounts();
  return JSON.stringify(accounts.map(a => {
    const mbs = a.mailboxes;
    const names = mbs.name();
    const unread = mbs.unreadCount();
    return {
      name: a.name(),
      enabled: a.enabled(),
      emailAddresses: a.emailAddresses(),
      fullName: a.fullName(),
      mailboxes: names.map((n, i) => ({ name: n, unread: unread[i] })),
    };
  }));
}`;

export const SEARCH = `${JXA_HELPERS}
function run(argv) {
  const p = JSON.parse(argv[0]);
  const boxes = resolveMailboxes(p.account, p.mailbox, p.allMailboxes);
  if (!boxes.length) throw new Error('Kein passendes Postfach gefunden. Tipp: list_accounts zeigt alle Postfächer.');

  const conds = [];
  if (p.query) conds.push({ _or: [ { subject: { _contains: p.query } }, { sender: { _contains: p.query } } ] });
  if (p.subject) conds.push({ subject: { _contains: p.subject } });
  if (p.from) conds.push({ sender: { _contains: p.from } });
  if (p.since) conds.push({ dateReceived: { _greaterThan: new Date(p.since) } });
  if (p.until) conds.push({ dateReceived: { _lessThan: new Date(p.until) } });
  if (p.unreadOnly) conds.push({ readStatus: false });
  if (p.flaggedOnly) conds.push({ flaggedStatus: true });
  if (p.body) conds.push({ content: { _contains: p.body } });

  const hits = [];
  for (const b of boxes) {
    let spec = b.spec.messages;
    if (conds.length === 1) spec = spec.whose(conds[0]);
    else if (conds.length > 1) spec = spec.whose({ _and: conds });
    let ids;
    try { ids = spec.id(); } catch (e) { continue; }
    if (!ids.length) continue;
    const dates = spec.dateReceived();
    const subjects = spec.subject();
    const senders = spec.sender();
    const read = spec.readStatus();
    const flagged = spec.flaggedStatus();
    for (let i = 0; i < ids.length; i++) {
      hits.push({
        account: b.account, mailbox: b.mailbox, id: ids[i],
        date: dates[i], from: senders[i], subject: subjects[i],
        read: read[i], flagged: flagged[i],
      });
    }
  }
  hits.sort((a, b) => new Date(b.date) - new Date(a.date));
  return JSON.stringify({ total: hits.length, results: hits.slice(0, p.limit || 20) });
}`;

export const READ = `${JXA_HELPERS}
function run(argv) {
  const p = JSON.parse(argv[0]);
  const m = getMessage(p);
  let content = m.content() || '';
  const full = content.length;
  if (p.maxChars && content.length > p.maxChars) content = content.slice(0, p.maxChars) + '\\n\\n[… gekürzt, ' + full + ' Zeichen insgesamt]';
  const atts = m.mailAttachments();
  const result = {
    account: p.account, mailbox: p.mailbox, id: Number(p.id),
    messageId: m.messageId(),
    subject: m.subject(),
    from: m.sender(),
    replyTo: m.replyTo(),
    to: m.toRecipients.address(),
    cc: m.ccRecipients.address(),
    date: m.dateReceived(),
    read: m.readStatus(),
    flagged: m.flaggedStatus(),
    attachments: atts.map(a => {
      let size = null, downloaded = null;
      try { size = a.fileSize(); } catch (e) {}
      try { downloaded = a.downloaded(); } catch (e) {}
      return { name: a.name(), mimeType: a.mimeType(), size, downloaded };
    }),
    content,
  };
  if (p.markRead) m.readStatus = true;
  return JSON.stringify(result);
}`;

export const SAVE_ATTACHMENTS = `${JXA_HELPERS}
function run(argv) {
  const p = JSON.parse(argv[0]);
  const m = getMessage(p);
  const used = {};
  (p.existing || []).forEach(n => used[n.toLowerCase()] = true);
  const filter = p.nameContains ? p.nameContains.toLowerCase() : null;

  function unique(name) {
    let clean = String(name || 'anhang').replace(/[\\/:]/g, '-').replace(/^\\.+/, '') || 'anhang';
    const dot = clean.lastIndexOf('.');
    const base = dot > 0 ? clean.slice(0, dot) : clean;
    const ext = dot > 0 ? clean.slice(dot) : '';
    let n = 1, cand = clean;
    while (used[cand.toLowerCase()]) cand = base + ' (' + (++n) + ')' + ext;
    used[cand.toLowerCase()] = true;
    return cand;
  }

  const saved = [], failed = [];
  for (const a of m.mailAttachments()) {
    const name = a.name();
    if (filter && String(name).toLowerCase().indexOf(filter) === -1) continue;
    const file = unique(name);
    const path = p.dir + '/' + file;
    try {
      Mail.save(a, { in: Path(path) });
      saved.push({ name, path });
    } catch (e) {
      failed.push({ name, error: String(e.message || e) });
    }
  }
  return JSON.stringify({ saved, failed });
}`;

// Versand per AppleScript – das Hinzufügen von Anhängen ist hier stabiler als in JXA.
// argv: subject, body, sender, to, cc, bcc, attachments (je zeilengetrennt), mode
export const SEND = `
on splitLines(t)
  if t is "" then return {}
  set oldDelims to AppleScript's text item delimiters
  set AppleScript's text item delimiters to linefeed
  set r to text items of t
  set AppleScript's text item delimiters to oldDelims
  return r
end splitLines

on run argv
  set theSubject to item 1 of argv
  set theBody to item 2 of argv
  set theSender to item 3 of argv
  set toList to my splitLines(item 4 of argv)
  set ccList to my splitLines(item 5 of argv)
  set bccList to my splitLines(item 6 of argv)
  set attList to my splitLines(item 7 of argv)
  set theMode to item 8 of argv

  tell application "Mail"
    set isVisible to (theMode is not "send")
    set m to make new outgoing message with properties {subject:theSubject, content:theBody & linefeed & linefeed, visible:isVisible}
    if theSender is not "" then set sender of m to theSender
    tell m
      repeat with a in toList
        make new to recipient at end of to recipients with properties {address:(a as text)}
      end repeat
      repeat with a in ccList
        make new cc recipient at end of cc recipients with properties {address:(a as text)}
      end repeat
      repeat with a in bccList
        make new bcc recipient at end of bcc recipients with properties {address:(a as text)}
      end repeat
    end tell
    repeat with f in attList
      tell content of m
        make new attachment with properties {file name:(POSIX file (f as text))} at after the last paragraph
      end tell
    end repeat
    if (count of attList) > 0 then delay 2
    if theMode is "send" then
      send m
      return "sent"
    else
      activate
      return "opened"
    end if
  end tell
end run
`;
