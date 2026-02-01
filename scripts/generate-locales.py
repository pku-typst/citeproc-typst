#!/usr/bin/env python3
"""Generate Typst locale files from official CSL locale XML files."""

import xml.etree.ElementTree as ET
import os
import re
from pathlib import Path

# Map our locale names to official CSL locale files
LOCALE_MAP = {
    "en-US": "en-US",
    "zh-CN": "zh-CN",
    "zh-TW": "zh-TW",
    "de-DE": "de-DE",
    "fr-FR": "fr-FR",
    "es-ES": "es-ES",
    "ja-JP": "ja-JP",
    "ko-KR": "ko-KR",
    "pt-BR": "pt-BR",
    "ru-RU": "ru-RU",
    "ar": "ar",
    "tr-TR": "tr-TR",
    "it-IT": "it-IT",
    "nl-NL": "nl-NL",
    "pl-PL": "pl-PL",
    "cs-CZ": "cs-CZ",
}

# Language names for comments
LANG_NAMES = {
    "en-US": "English (US)",
    "zh-CN": "Chinese (Simplified)",
    "zh-TW": "Chinese (Traditional)",
    "de-DE": "German",
    "fr-FR": "French",
    "es-ES": "Spanish",
    "ja-JP": "Japanese",
    "ko-KR": "Korean",
    "pt-BR": "Portuguese (Brazil)",
    "ru-RU": "Russian",
    "ar": "Arabic",
    "tr-TR": "Turkish",
    "it-IT": "Italian",
    "nl-NL": "Dutch",
    "pl-PL": "Polish",
    "cs-CZ": "Czech",
}


def escape_typst_string(s: str) -> str:
    """Escape a string for Typst."""
    if s is None:
        return ""
    # Use Unicode escapes for special characters
    result = []
    for c in s:
        code = ord(c)
        if code < 32 or code == 34 or code == 92:  # control chars, quote, backslash
            result.append(f"\\u{{{code:04X}}}")
        elif code > 127:
            result.append(f"\\u{{{code:04X}}}")
        else:
            result.append(c)
    return "".join(result)


def parse_locale_xml(xml_path: str) -> dict:
    """Parse a CSL locale XML file and extract terms."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Handle namespace
    ns = {'csl': 'http://purl.org/net/xbiblio/csl'}

    terms = {}
    term_genders = {}  # Track gender of terms (e.g., edition -> feminine)
    ordinal_gender_forms = {}  # Track gender-form variants of ordinals
    dates = {}
    options = {}

    # Find terms
    terms_node = root.find('.//csl:terms', ns)
    if terms_node is None:
        terms_node = root.find('.//terms')

    if terms_node is not None:
        for term in terms_node.findall('csl:term', ns) or terms_node.findall('term'):
            name = term.get('name')
            form = term.get('form')
            gender = term.get('gender')
            gender_form = term.get('gender-form')
            match = term.get('match')

            if name is None:
                continue

            # Build key
            key = name
            if form and form != 'long':
                key = f"{name}-{form}"

            # Check for single/multiple
            single = term.find('csl:single', ns)
            if single is None:
                single = term.find('single')
            multiple = term.find('csl:multiple', ns)
            if multiple is None:
                multiple = term.find('multiple')

            # Handle gender-form variants (for ordinals)
            if gender_form:
                gf_key = f"{key}:{gender_form}"
                if single is not None and multiple is not None:
                    ordinal_gender_forms[gf_key] = {
                        'single': single.text or '',
                        'multiple': multiple.text or ''
                    }
                else:
                    ordinal_gender_forms[gf_key] = term.text or ''
                continue  # Don't add to main terms

            # Track gender of terms
            if gender:
                term_genders[key] = gender

            if single is not None and multiple is not None:
                terms[key] = {
                    'single': single.text or '',
                    'multiple': multiple.text or ''
                }
            else:
                terms[key] = term.text or ''

    # Add missing terms that CSL requires but aren't in all locale files
    # CSL spec requires "and" to have both long and symbol forms
    if 'and' in terms and 'and-symbol' not in terms:
        terms['and-symbol'] = '&'  # Universal ampersand symbol

    return {
        'terms': terms,
        'term_genders': term_genders,
        'ordinal_gender_forms': ordinal_gender_forms,
        'dates': dates,
        'options': options,
    }


def format_term_value(value) -> str:
    """Format a term value for Typst."""
    if isinstance(value, dict):
        single = escape_typst_string(value.get('single', ''))
        multiple = escape_typst_string(value.get('multiple', ''))
        return f'(single: "{single}", multiple: "{multiple}")'
    else:
        return f'"{escape_typst_string(value)}"'


def generate_typst_locale(locale_name: str, data: dict, lang_name: str) -> str:
    """Generate Typst locale file content."""
    lines = [
        f"// citrus - {lang_name} Locale",
        f"// Auto-generated from official CSL locale",
        "",
        "#let locale = (",
        "  terms: (",
    ]

    # Group terms by category
    categories = {
        'basic': [],
        'roles': [],
        'locators': [],
        'quotes': [],
        'ordinals': [],
        'months': [],
        'seasons': [],
        'misc': [],
    }

    for key, value in sorted(data['terms'].items()):
        if key in ('and', 'et-al', 'and-symbol', 'in', 'from', 'accessed',
                   'retrieved', 'references', 'no date', 'anonymous', 'circa'):
            categories['basic'].append((key, value))
        elif key.startswith(('editor', 'translator', 'author', 'interviewer',
                            'recipient', 'director', 'composer')):
            categories['roles'].append((key, value))
        elif key.startswith(('page', 'volume', 'chapter', 'issue', 'part',
                            'section', 'column', 'line', 'verse', 'figure',
                            'folio', 'opus', 'note', 'number', 'paragraph',
                            'sub verbo', 'locator', 'book', 'article', 'rule')):
            categories['locators'].append((key, value))
        elif 'quote' in key:
            categories['quotes'].append((key, value))
        elif 'ordinal' in key:
            categories['ordinals'].append((key, value))
        elif key.startswith('month-'):
            categories['months'].append((key, value))
        elif key.startswith('season-'):
            categories['seasons'].append((key, value))
        elif 'range-delimiter' in key:
            categories['misc'].append((key, value))
        else:
            categories['misc'].append((key, value))

    def add_category(name: str, items: list):
        if items:
            lines.append(f"    // {name}")
            for key, value in items:
                lines.append(f'    "{key}": {format_term_value(value)},')

    add_category("Basic terms", categories['basic'])
    add_category("Roles", categories['roles'])
    add_category("Locator terms", categories['locators'])
    add_category("Range delimiters", categories['misc'])
    add_category("Quote marks", categories['quotes'])
    add_category("Ordinals", categories['ordinals'])
    add_category("Months", categories['months'])
    add_category("Seasons", categories['seasons'])

    lines.append("  ),")

    # Add term genders (for ordinal gender matching)
    if data.get('term_genders'):
        lines.append("  // Gender of terms (for ordinal agreement)")
        lines.append("  term-genders: (")
        for key, gender in sorted(data['term_genders'].items()):
            lines.append(f'    "{key}": "{gender}",')
        lines.append("  ),")
    else:
        lines.append("  term-genders: (:),")

    # Add ordinal gender forms
    if data.get('ordinal_gender_forms'):
        lines.append("  // Ordinal gender-form variants (key format: ordinal-NN:masculine or ordinal-NN:feminine)")
        lines.append("  ordinal-gender-forms: (")
        for key, value in sorted(data['ordinal_gender_forms'].items()):
            lines.append(f'    "{key}": {format_term_value(value)},')
        lines.append("  ),")
    else:
        lines.append("  ordinal-gender-forms: (:),")

    lines.extend([
        "  dates: (:),",
        "  options: (:),",
        ")",
        "",
    ])

    return "\n".join(lines)


def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent

    xml_base = project_dir / "references" / "citeproc-js-docs" / "_static" / "data" / "locales"
    output_dir = project_dir / "src" / "parsing" / "locales"

    for our_name, csl_name in LOCALE_MAP.items():
        xml_path = xml_base / f"locales-{csl_name}.xml"

        if not xml_path.exists():
            print(f"SKIP {our_name}: XML file not found")
            continue

        try:
            data = parse_locale_xml(str(xml_path))
            lang_name = LANG_NAMES.get(our_name, our_name)
            content = generate_typst_locale(our_name, data, lang_name)

            output_path = output_dir / f"{our_name}.typ"
            output_path.write_text(content, encoding='utf-8')

            term_count = len(data['terms'])
            print(f"OK {our_name}: {term_count} terms")

        except Exception as e:
            print(f"ERROR {our_name}: {e}")


if __name__ == "__main__":
    main()
