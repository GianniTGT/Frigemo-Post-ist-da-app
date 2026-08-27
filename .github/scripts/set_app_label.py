#!/usr/bin/env python3
"""Setzt den Anzeigenamen der App im generierten Android-Manifest.

`flutter create` traegt als android:label den technischen Projektnamen ein
(frigemo_post_terminal) -- der stand dann unter dem Icon und in den
Android-Einstellungen. Der Anzeigename soll aber der Produktname sein.

Nur der Anzeigename wird geaendert, nicht die App-ID: eine andere ID saehe
Android als fremde App und verweigerte das Update ueber die installierte
Fassung.

Der Ordner android/ liegt nicht im Repository, sondern wird im Workflow bei
jedem Lauf neu erzeugt. Deshalb muss der Name bei jedem Bau erneut hinein.
"""
import re
import sys
from pathlib import Path

LABEL = 'Tiff – Post ist da'


def main() -> None:
    android = Path(sys.argv[1] if len(sys.argv) > 1 else 'app/android')
    label = sys.argv[2] if len(sys.argv) > 2 else LABEL
    manifest = android / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
    if not manifest.exists():
        sys.exit(f'FEHLER: {manifest} fehlt')

    text = manifest.read_text(encoding='utf-8')
    if f'android:label="{label}"' in text:
        print('App-Name bereits gesetzt - nichts zu tun.')
        return

    pattern = re.compile(r'android:label="[^"]*"')
    if not pattern.search(text):
        sys.exit('FEHLER: android:label nicht gefunden - Vorlage hat sich geaendert.')

    patched = pattern.sub(f'android:label="{label}"', text, count=1)
    manifest.write_text(patched, encoding='utf-8')
    print(f'App-Name "{label}" in {manifest} eingetragen.')


if __name__ == '__main__':
    main()
