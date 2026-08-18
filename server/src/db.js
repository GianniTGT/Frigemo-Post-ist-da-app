import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.DB_PATH
  ? path.resolve(process.env.DB_PATH)
  : path.join(__dirname, '..', 'data', 'deliveries.db');

fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS deliveries (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at     TEXT    NOT NULL,
    carrier_id     TEXT    NOT NULL,
    carrier_label  TEXT    NOT NULL,
    employee_id    TEXT    NOT NULL,
    employee_name  TEXT    NOT NULL,
    employee_email TEXT    NOT NULL,
    quantity       INTEGER NOT NULL,
    kind           TEXT    NOT NULL,
    location       TEXT    NOT NULL,
    note           TEXT,
    lang           TEXT    NOT NULL,
    terminal_id    TEXT    NOT NULL,
    mail_status    TEXT    NOT NULL DEFAULT 'pending',
    mail_detail    TEXT
  );
  CREATE INDEX IF NOT EXISTS idx_deliveries_created ON deliveries(created_at);
`);

const insertStmt = db.prepare(`
  INSERT INTO deliveries (
    created_at, carrier_id, carrier_label, employee_id, employee_name,
    employee_email, quantity, kind, location, note, lang, terminal_id
  ) VALUES (
    @created_at, @carrier_id, @carrier_label, @employee_id, @employee_name,
    @employee_email, @quantity, @kind, @location, @note, @lang, @terminal_id
  )
`);

const updateStmt = db.prepare(
  'UPDATE deliveries SET mail_status = ?, mail_detail = ? WHERE id = ?'
);

const recentStmt = db.prepare(
  'SELECT * FROM deliveries ORDER BY id DESC LIMIT ?'
);

export function insertDelivery(d) {
  const result = insertStmt.run({
    created_at: new Date().toISOString(),
    carrier_id: d.carrierId,
    carrier_label: d.carrierLabel,
    employee_id: d.employeeId,
    employee_name: d.employeeName,
    employee_email: d.employeeEmail,
    quantity: d.quantity,
    kind: d.kind,
    location: d.location,
    note: d.note,
    lang: d.lang,
    terminal_id: d.terminalId,
  });
  return Number(result.lastInsertRowid);
}

export function updateMailStatus(id, status, detail) {
  updateStmt.run(status, detail ? String(detail).slice(0, 500) : null, id);
}

export function recentDeliveries(limit = 50) {
  return recentStmt.all(limit);
}

export default db;
