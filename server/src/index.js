import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import { searchEmployees, getEmployee, employeeCount, watchEmployees } from './employees.js';
import { insertDelivery, updateMailStatus, recentDeliveries } from './db.js';
import { sendDeliveryMail } from './mailer.js';

const app = express();
const PORT = Number(process.env.PORT || 3000);
const TERMINAL_KEY = process.env.TERMINAL_API_KEY || '';
const ADMIN_KEY = process.env.ADMIN_API_KEY || '';

app.use(cors());
app.use(express.json({ limit: '32kb' }));

// --- Auth ------------------------------------------------------------------

function requireTerminal(req, res, next) {
  if (!TERMINAL_KEY) return next(); // Entwicklungsmodus
  if (req.get('x-api-key') === TERMINAL_KEY) return next();
  return res.status(401).json({ error: 'unauthorized' });
}

function requireAdmin(req, res, next) {
  if (ADMIN_KEY && req.get('x-api-key') === ADMIN_KEY) return next();
  return res.status(401).json({ error: 'unauthorized' });
}

// --- Einfaches Rate-Limit pro Terminal -------------------------------------

const hits = new Map();
function rateLimit(max, windowMs) {
  return (req, res, next) => {
    const key = req.get('x-terminal-id') || req.ip;
    const now = Date.now();
    const entry = hits.get(key) || { count: 0, reset: now + windowMs };
    if (now > entry.reset) {
      entry.count = 0;
      entry.reset = now + windowMs;
    }
    entry.count += 1;
    hits.set(key, entry);
    if (entry.count > max) return res.status(429).json({ error: 'too_many_requests' });
    next();
  };
}

// --- Routen ----------------------------------------------------------------

app.get('/api/health', (req, res) => {
  res.json({ ok: true, employees: employeeCount(), time: new Date().toISOString() });
});

/**
 * Serverseitige Suche: das Terminal bekommt nie die ganze Personalliste,
 * und E-Mail-Adressen verlassen den Server gar nicht.
 */
app.get('/api/employees', requireTerminal, (req, res) => {
  const q = String(req.query.q || '').trim();
  const limit = Math.min(Number(req.query.limit) || 8, 25);
  if (q.length < 2) return res.json({ data: [] });

  const data = searchEmployees(q, limit).map((e) => ({
    id: e.id,
    name: e.name,
    department: e.department,
  }));
  res.json({ data });
});

const KINDS = new Set(['parcel', 'pallet', 'letter', 'chilled']);
const LOCATIONS = new Set(['reception', 'dock', 'coldroom']);

app.post('/api/deliveries', requireTerminal, rateLimit(60, 60_000), async (req, res) => {
  const body = req.body || {};
  const employee = getEmployee(String(body.employeeId || ''));

  if (!employee) return res.status(400).json({ error: 'unknown_employee' });
  if (!body.carrierLabel) return res.status(400).json({ error: 'missing_carrier' });

  const delivery = {
    carrierId: String(body.carrierId || 'other').slice(0, 32),
    carrierLabel: String(body.carrierLabel).slice(0, 64),
    employeeId: employee.id,
    employeeName: employee.name,
    employeeEmail: employee.email,
    quantity: Math.min(Math.max(Number(body.quantity) || 1, 1), 99),
    kind: KINDS.has(body.kind) ? body.kind : 'parcel',
    location: LOCATIONS.has(body.location) ? body.location : 'reception',
    note: String(body.note || '').slice(0, 200),
    lang: employee.lang || 'fr',
    terminalId: String(body.terminalId || req.get('x-terminal-id') || 'unknown').slice(0, 64),
  };

  // Erst protokollieren, dann versenden: eine erfasste Sendung geht auch
  // dann nicht verloren, wenn der Mailserver klemmt.
  const id = insertDelivery(delivery);

  try {
    const info = await sendDeliveryMail(delivery);
    updateMailStatus(id, 'sent', info.messageId || null);
    res.status(201).json({ id, mailStatus: 'sent' });
  } catch (err) {
    console.error(`[delivery ${id}] Mailversand fehlgeschlagen:`, err.message);
    updateMailStatus(id, 'failed', err.message);
    res.status(201).json({ id, mailStatus: 'failed' });
  }
});

/** Auditliste für Empfang/IT. */
app.get('/api/deliveries', requireAdmin, (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 500);
  res.json({ data: recentDeliveries(limit) });
});

app.use((req, res) => res.status(404).json({ error: 'not_found' }));

// --- Start -----------------------------------------------------------------

watchEmployees();

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Frigemo Post API läuft auf Port ${PORT}`);
  console.log(`Mitarbeitende geladen: ${employeeCount()}`);
  if (!TERMINAL_KEY) console.warn('WARNUNG: TERMINAL_API_KEY nicht gesetzt – API ist offen.');
  if (process.env.MAIL_DRY_RUN === 'true') console.warn('MAIL_DRY_RUN aktiv – es werden keine E-Mails versendet.');
});
