import nodemailer from 'nodemailer';

const DRY_RUN = process.env.MAIL_DRY_RUN === 'true';

const transporter = DRY_RUN
  ? null
  : nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 25),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
        : undefined,
      tls: { rejectUnauthorized: process.env.SMTP_TLS_STRICT !== 'false' },
    });

const T = {
  fr: {
    subject: (d) => `${d.urgent ? '[URGENT] ' : ''}Livraison pour vous – ${d.carrierLabel}`,
    heading: 'Une livraison vous attend',
    intro: (d) =>
      `Bonjour ${d.employeeName.split(' ')[0]}, une livraison est arrivée à votre nom à la réception de Cressier.`,
    carrier: 'Transporteur',
    quantity: 'Nombre',
    kind: 'Type',
    location: 'À retirer à',
    note: 'Remarque',
    time: 'Annoncé le',
    urgentNote:
      'Marchandise réfrigérée : merci de venir la chercher immédiatement, la chaîne du froid ne peut pas être garantie à la réception.',
    footer: 'Message automatique du terminal de réception. Merci de ne pas répondre.',
    kinds: {
      parcel: 'Colis',
      pallet: 'Palette',
      letter: 'Courrier recommandé',
      chilled: 'Marchandise réfrigérée',
    },
    locations: {
      reception: 'Réception',
      dock: 'Quai de chargement',
      coldroom: 'Chambre froide',
    },
    locale: 'fr-CH',
  },
  de: {
    subject: (d) => `${d.urgent ? '[DRINGEND] ' : ''}Lieferung für Sie – ${d.carrierLabel}`,
    heading: 'Eine Lieferung wartet auf Sie',
    intro: (d) =>
      `Guten Tag ${d.employeeName.split(' ')[0]}, am Empfang Cressier ist eine Lieferung auf Ihren Namen eingetroffen.`,
    carrier: 'Transporteur',
    quantity: 'Anzahl',
    kind: 'Art',
    location: 'Abholort',
    note: 'Bemerkung',
    time: 'Gemeldet am',
    urgentNote:
      'Kühlware: Bitte sofort abholen – am Empfang kann die Kühlkette nicht eingehalten werden.',
    footer: 'Automatische Meldung des Empfangsterminals. Bitte nicht antworten.',
    kinds: {
      parcel: 'Paket',
      pallet: 'Palette',
      letter: 'Eingeschriebener Brief',
      chilled: 'Kühlware',
    },
    locations: {
      reception: 'Empfang',
      dock: 'Laderampe',
      coldroom: 'Kühlraum',
    },
    locale: 'de-CH',
  },
};

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );
}

function render(delivery) {
  const t = T[delivery.lang] || T.fr;
  const urgent = delivery.kind === 'chilled';
  const stamp = new Date().toLocaleString(t.locale, {
    dateStyle: 'short',
    timeStyle: 'short',
  });

  const rows = [
    [t.carrier, delivery.carrierLabel],
    [t.quantity, String(delivery.quantity)],
    [t.kind, t.kinds[delivery.kind]],
    [t.location, t.locations[delivery.location]],
    [t.time, stamp],
  ];
  if (delivery.note) rows.push([t.note, delivery.note]);

  const text = [
    t.heading,
    '',
    t.intro({ ...delivery, urgent }),
    '',
    ...rows.map(([k, v]) => `${k}: ${v}`),
    ...(urgent ? ['', t.urgentNote] : []),
    '',
    t.footer,
  ].join('\n');

  const html = `<!doctype html>
<html lang="${delivery.lang}"><body style="margin:0;padding:24px;background:#f2f5f6;font-family:Arial,Helvetica,sans-serif;color:#16222e;">
  <table role="presentation" width="100%" style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #d6dee3;border-radius:12px;">
    <tr><td style="background:#16222e;color:#ffffff;padding:20px 24px;border-radius:12px 12px 0 0;">
      <div style="font-size:12px;letter-spacing:2px;color:#9fb3c1;">FRIGEMO CRESSIER</div>
      <div style="font-size:20px;font-weight:700;margin-top:4px;">${escapeHtml(t.heading)}</div>
    </td></tr>
    ${urgent ? `<tr><td style="background:#c25e00;color:#ffffff;padding:14px 24px;font-weight:600;">${escapeHtml(t.urgentNote)}</td></tr>` : ''}
    <tr><td style="padding:24px;font-size:15px;line-height:1.5;">
      <p style="margin:0 0 18px;">${escapeHtml(t.intro({ ...delivery, urgent }))}</p>
      <table role="presentation" width="100%" style="border-collapse:collapse;font-size:15px;">
        ${rows
          .map(
            ([k, v]) =>
              `<tr><td style="padding:8px 0;color:#4a5a69;width:40%;">${escapeHtml(k)}</td><td style="padding:8px 0;font-weight:600;">${escapeHtml(v)}</td></tr>`
          )
          .join('')}
      </table>
    </td></tr>
    <tr><td style="padding:16px 24px;border-top:1px solid #d6dee3;color:#4a5a69;font-size:12px;">${escapeHtml(t.footer)}</td></tr>
  </table>
</body></html>`;

  return { subject: t.subject({ ...delivery, urgent }), text, html };
}

export async function sendDeliveryMail(delivery) {
  const { subject, text, html } = render(delivery);

  const message = {
    from: process.env.MAIL_FROM || 'reception@frigemo.ch',
    to: delivery.employeeEmail,
    subject,
    text,
    html,
    replyTo: process.env.MAIL_REPLY_TO || undefined,
    priority: delivery.kind === 'chilled' ? 'high' : 'normal',
  };

  if (delivery.kind === 'chilled' && process.env.MAIL_URGENT_CC) {
    message.cc = process.env.MAIL_URGENT_CC;
  }

  if (DRY_RUN) {
    console.log('--- MAIL_DRY_RUN ---');
    console.log(`An: ${message.to}\nBetreff: ${subject}\n\n${text}\n`);
    return { messageId: 'dry-run' };
  }

  return transporter.sendMail(message);
}
