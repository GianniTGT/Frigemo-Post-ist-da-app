#!/usr/bin/env python3
"""Traegt die Internet-Berechtigung in das generierte Android-Manifest ein.

`flutter create` setzt <uses-permission android:name="android.permission.INTERNET"/>
nur in die Debug- und Profile-Manifeste. Ein Release-APK darf damit nicht ins
Netz: jede Verbindung scheitert schon bei der Namensaufloesung mit
"Failed host lookup ... errno = 7". Solange die App nur Intents weiterreichte,
fiel das nicht auf -- fuer den SMTP-Versand ist es toedlich.

Der Ordner android/ liegt nicht im Repository, sondern wird im Workflow bei
jedem Lauf neu erzeugt. Deshalb muss der Eintrag bei jedem Bau erneut hinein.
"""
import re
import sys
from pathlib import Path

PERMISSION = 'android.permission.INTERNET'
LINE = f'    <uses-permission android:name="{PERMISSION}"/>\n'


def main() -> None:
    android = Path(sys.argv[1] if len(sys.argv) > 1 else 'app/android')
    manifest = android / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
    if not manifest.exists():
        sys.exit(f'FEHLER: {manifest} fehlt')

    text = manifest.read_text(encoding='utf-8')
    if PERMISSION in text:
        print('Internet-Berechtigung bereits vorhanden - nichts zu tun.')
        return

    # Direkt nach dem oeffnenden <manifest ...> einfuegen.
    opening = re.search(r'<manifest\b[^>]*>\s*\n', text)
    if not opening:
        sys.exit('FEHLER: <manifest> nicht gefunden - Vorlage hat sich geaendert.')

    patched = text[:opening.end()] + LINE + text[opening.end():]
    manifest.write_text(patched, encoding='utf-8')
    print(f'Internet-Berechtigung in {manifest} eingetragen.')


if __name__ == '__main__':
    main()
