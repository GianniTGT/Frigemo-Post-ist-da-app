import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CSV_PATH = process.env.EMPLOYEES_CSV
  ? path.resolve(process.env.EMPLOYEES_CSV)
  : path.join(__dirname, '..', 'data', 'employees.csv');

let employees = [];
let byId = new Map();

/** Minimaler CSV-Parser mit Unterstützung für "quoted, fields". */
function parseCsv(text) {
  const rows = [];
  let field = '';
  let row = [];
  let quoted = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',' || ch === ';') { row.push(field); field = ''; }
    else if (ch === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (ch !== '\r') field += ch;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows.filter((r) => r.some((c) => c.trim() !== ''));
}

/** Diakritika entfernen, damit "muller" auch "Müller" findet. */
function normalize(value) {
  return (value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

export function loadEmployees() {
  if (!fs.existsSync(CSV_PATH)) {
    console.error(`Mitarbeiterdatei fehlt: ${CSV_PATH}`);
    employees = [];
    byId = new Map();
    return;
  }

  const rows = parseCsv(fs.readFileSync(CSV_PATH, 'utf8'));
  const header = rows.shift().map((h) => h.trim().toLowerCase());
  const col = (name) => header.indexOf(name);

  const parsed = [];
  for (const row of rows) {
    const get = (name) => (col(name) >= 0 ? (row[col(name)] || '').trim() : '');
    const active = get('active');
    if (active && !['1', 'true', 'ja', 'oui', 'yes'].includes(active.toLowerCase())) continue;

    const email = get('email');
    const name = get('name');
    if (!email || !name) continue;

    const lang = (get('lang') || 'fr').toLowerCase().startsWith('de') ? 'de' : 'fr';
    parsed.push({
      id: get('id') || email,
      name,
      email,
      department: get('department'),
      lang,
      search: `${normalize(name)} ${normalize(get('department'))} ${normalize(email)}`,
    });
  }

  employees = parsed;
  byId = new Map(parsed.map((e) => [e.id, e]));
  console.log(`Mitarbeiterliste geladen: ${employees.length} Einträge`);
}

/** Datei wird im Betrieb neu eingelesen – kein Neustart nötig. */
export function watchEmployees() {
  loadEmployees();
  try {
    let pending = null;
    fs.watch(path.dirname(CSV_PATH), (event, filename) => {
      if (filename && path.basename(CSV_PATH) !== filename) return;
      clearTimeout(pending);
      pending = setTimeout(loadEmployees, 500);
    });
  } catch (err) {
    console.warn('Datei-Überwachung nicht möglich:', err.message);
  }
}

export function searchEmployees(query, limit = 8) {
  const terms = normalize(query).split(/\s+/).filter(Boolean);
  if (!terms.length) return [];

  const scored = [];
  for (const emp of employees) {
    if (!terms.every((t) => emp.search.includes(t))) continue;
    // Treffer am Namensanfang zuerst.
    const score = normalize(emp.name).startsWith(terms[0]) ? 0 : 1;
    scored.push({ emp, score });
  }

  return scored
    .sort((a, b) => a.score - b.score || a.emp.name.localeCompare(b.emp.name))
    .slice(0, limit)
    .map((s) => s.emp);
}

export function getEmployee(id) {
  return byId.get(id) || null;
}

export function employeeCount() {
  return employees.length;
}
