#!/usr/bin/env python3
"""Schaltet die Code-Schrumpfung (R8) fuer Release-Builds ab.

Der Barcode-Scanner scheiterte auf dem Geraet beim Start mit

  Attempt to invoke virtual method 'java.lang.Class
  java.lang.Object.getClass()' on a null object reference

Das ist die Handschrift von R8: Die Barcode-Erkennung (Google MLKit) laedt
ihre Bausteine ueber Namens-Nachschlag zur Laufzeit, R8 sieht keine direkte
Verwendung und entfernt oder verkuerzt sie -- beim Start ist dann intern
etwas null. Fuer ein Kiosk-Terminal ist die eingesparte APK-Groesse ohne
Wert; Verlaesslichkeit schlaegt Schrumpfung.

Der Ordner app/android/ wird im Workflow bei jedem Lauf neu erzeugt,
deshalb muss der Eintrag bei jedem Bau erneut hinein.

Bricht ab, wenn das Gradle-Skript nicht wie erwartet aussieht -- ein
stillschweigend geschrumpftes Release waere der schlimmere Ausgang.
"""
import re
import sys
from pathlib import Path

KTS_LINES = '''            isMinifyEnabled = false
            isShrinkResources = false
'''

GROOVY_LINES = '''            minifyEnabled false
            shrinkResources false
'''


def find_gradle(android_dir: Path) -> Path:
    for name in ('build.gradle.kts', 'build.gradle'):
        candidate = android_dir / 'app' / name
        if candidate.exists():
            return candidate
    sys.exit(f'FEHLER: weder app/build.gradle.kts noch app/build.gradle in {android_dir}')


def patch(text: str, is_kts: bool) -> str:
    if 'MinifyEnabled' in text or 'minifyEnabled' in text:
        print('Schrumpfung bereits abgeschaltet - nichts zu tun.')
        return text

    build_types = re.search(r'^[ \t]*buildTypes\s*\{', text, re.MULTILINE)
    if not build_types:
        sys.exit('FEHLER: Block "buildTypes {" nicht gefunden - Gradle-Vorlage hat sich geaendert.')

    release = re.compile(r'^[ \t]*release\s*\{[ \t]*\n', re.MULTILINE).search(
        text, build_types.end()
    )
    if not release:
        sys.exit('FEHLER: Block "release {" nicht gefunden - Gradle-Vorlage hat sich geaendert.')

    lines = KTS_LINES if is_kts else GROOVY_LINES
    return text[:release.end()] + lines + text[release.end():]


def main() -> None:
    android_dir = Path(sys.argv[1] if len(sys.argv) > 1 else 'app/android')
    gradle = find_gradle(android_dir)
    original = gradle.read_text(encoding='utf-8')
    patched = patch(original, gradle.suffix == '.kts')
    if patched != original:
        gradle.write_text(patched, encoding='utf-8')
        print(f'Code-Schrumpfung in {gradle} abgeschaltet.')


if __name__ == '__main__':
    main()
