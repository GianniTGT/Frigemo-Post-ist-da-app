#!/usr/bin/env python3
"""Traegt die Release-Signatur in das von `flutter create` erzeugte
Android-Projekt ein.

Der Ordner app/android/ liegt nicht im Repository, sondern wird im Workflow
bei jedem Lauf neu generiert. Das generierte Gradle-Skript signiert Release-
Builds mit dem Debug-Schluessel; dieses Skript ersetzt das durch eine
Release-Konfiguration, die Keystore und Passwoerter aus Umgebungsvariablen
liest (FRIGEMO_KEYSTORE, FRIGEMO_STORE_PASSWORD, FRIGEMO_KEY_ALIAS,
FRIGEMO_KEY_PASSWORD) -- so landet kein Passwort in einer Datei.

Bricht mit Exit-Code 1 ab, wenn das Gradle-Skript nicht wie erwartet aussieht.
Das ist Absicht: ein stillschweigend debug-signiertes Release-APK waere der
schlimmere Ausgang.
"""
import re
import sys
from pathlib import Path

KTS_BLOCK = '''    signingConfigs {
        create("release") {
            storeFile = System.getenv("FRIGEMO_KEYSTORE")?.let { file(it) }
            storePassword = System.getenv("FRIGEMO_STORE_PASSWORD")
            keyAlias = System.getenv("FRIGEMO_KEY_ALIAS")
            keyPassword = System.getenv("FRIGEMO_KEY_PASSWORD")
        }
    }

'''

GROOVY_BLOCK = '''    signingConfigs {
        release {
            storeFile System.getenv("FRIGEMO_KEYSTORE") ? file(System.getenv("FRIGEMO_KEYSTORE")) : null
            storePassword System.getenv("FRIGEMO_STORE_PASSWORD")
            keyAlias System.getenv("FRIGEMO_KEY_ALIAS")
            keyPassword System.getenv("FRIGEMO_KEY_PASSWORD")
        }
    }

'''

# (Muster fuer den Debug-Verweis, Ersatz) je Gradle-Dialekt.
DEBUG_REF = {
    True: (
        re.compile(r'signingConfig\s*=\s*signingConfigs\.getByName\(\s*"debug"\s*\)'),
        'signingConfig = signingConfigs.getByName("release")',
    ),
    False: (
        re.compile(r'signingConfig\s+signingConfigs\.debug\b'),
        'signingConfig signingConfigs.release',
    ),
}


def find_gradle(android_dir: Path) -> Path:
    for name in ('build.gradle.kts', 'build.gradle'):
        candidate = android_dir / 'app' / name
        if candidate.exists():
            return candidate
    sys.exit(f'FEHLER: weder app/build.gradle.kts noch app/build.gradle in {android_dir}')


def patch(text: str, is_kts: bool) -> str:
    if 'FRIGEMO_KEYSTORE' in text:
        print('Signaturkonfiguration bereits vorhanden - nichts zu tun.')
        return text

    build_types = re.search(r'^([ \t]*)buildTypes\s*\{', text, re.MULTILINE)
    if not build_types:
        sys.exit('FEHLER: Block "buildTypes {" nicht gefunden - Gradle-Vorlage hat sich geaendert.')

    block = KTS_BLOCK if is_kts else GROOVY_BLOCK
    text = text[:build_types.start()] + block + text[build_types.start():]

    pattern, replacement = DEBUG_REF[is_kts]
    text, count = pattern.subn(replacement, text)
    if count != 1:
        sys.exit(
            f'FEHLER: Debug-Signaturverweis {count}x gefunden (erwartet: 1) - '
            'Gradle-Vorlage hat sich geaendert.'
        )
    return text


def main() -> None:
    android_dir = Path(sys.argv[1] if len(sys.argv) > 1 else 'app/android')
    gradle = find_gradle(android_dir)
    original = gradle.read_text(encoding='utf-8')
    patched = patch(original, gradle.suffix == '.kts')
    if patched != original:
        gradle.write_text(patched, encoding='utf-8')
        print(f'Release-Signatur in {gradle} eingetragen.')


if __name__ == '__main__':
    main()
