#!/usr/bin/env python3
"""Generate Typst locale files from official CSL locale XML files."""

import xml.etree.ElementTree as ET
import os
import re
from pathlib import Path

# Map our locale names to official CSL locale files
# All locales from https://github.com/citation-style-language/locales
LOCALE_MAP = {
    "af-ZA": "af-ZA",
    "ar": "ar",
    "bal-PK": "bal-PK",
    "bg-BG": "bg-BG",
    "brh-PK": "brh-PK",
    "ca-AD": "ca-AD",
    "cs-CZ": "cs-CZ",
    "cy-GB": "cy-GB",
    "da-DK": "da-DK",
    "de-AT": "de-AT",
    "de-CH": "de-CH",
    "de-DE": "de-DE",
    "el-GR": "el-GR",
    "en-GB": "en-GB",
    "en-US": "en-US",
    "es-CL": "es-CL",
    "es-ES": "es-ES",
    "es-MX": "es-MX",
    "et-EE": "et-EE",
    "eu": "eu",
    "fa-IR": "fa-IR",
    "fi-FI": "fi-FI",
    "fr-CA": "fr-CA",
    "fr-FR": "fr-FR",
    "gl-ES": "gl-ES",
    "he-IL": "he-IL",
    "hi-IN": "hi-IN",
    "hr-HR": "hr-HR",
    "hu-HU": "hu-HU",
    "id-ID": "id-ID",
    "is-IS": "is-IS",
    "it-IT": "it-IT",
    "ja-JP": "ja-JP",
    "km-KH": "km-KH",
    "ko-KR": "ko-KR",
    "la": "la",
    "lij-IT": "lij-IT",
    "lt-LT": "lt-LT",
    "lv-LV": "lv-LV",
    "mn-MN": "mn-MN",
    "ms-MY": "ms-MY",
    "nb-NO": "nb-NO",
    "nl-NL": "nl-NL",
    "nn-NO": "nn-NO",
    "pa-PK": "pa-PK",
    "pl-PL": "pl-PL",
    "pt-BR": "pt-BR",
    "pt-PT": "pt-PT",
    "ro-RO": "ro-RO",
    "ru-RU": "ru-RU",
    "sk-SK": "sk-SK",
    "sl-SI": "sl-SI",
    "sr-Cyrl-RS": "sr-Cyrl-RS",
    "sr-Latn-RS": "sr-Latn-RS",
    "sv-SE": "sv-SE",
    "th-TH": "th-TH",
    "tr-TR": "tr-TR",
    "uk-UA": "uk-UA",
    "vi-VN": "vi-VN",
    "zh-CN": "zh-CN",
    "zh-TW": "zh-TW",
}

# Language names for comments
LANG_NAMES = {
    "af-ZA": "Afrikaans (South Africa)",
    "ar": "Arabic",
    "bal-PK": "Balochi (Pakistan)",
    "bg-BG": "Bulgarian",
    "brh-PK": "Brahui (Pakistan)",
    "ca-AD": "Catalan",
    "cs-CZ": "Czech",
    "cy-GB": "Welsh",
    "da-DK": "Danish",
    "de-AT": "German (Austria)",
    "de-CH": "German (Switzerland)",
    "de-DE": "German (Germany)",
    "el-GR": "Greek",
    "en-GB": "English (UK)",
    "en-US": "English (US)",
    "es-CL": "Spanish (Chile)",
    "es-ES": "Spanish (Spain)",
    "es-MX": "Spanish (Mexico)",
    "et-EE": "Estonian",
    "eu": "Basque",
    "fa-IR": "Persian",
    "fi-FI": "Finnish",
    "fr-CA": "French (Canada)",
    "fr-FR": "French (France)",
    "gl-ES": "Galician",
    "he-IL": "Hebrew",
    "hi-IN": "Hindi",
    "hr-HR": "Croatian",
    "hu-HU": "Hungarian",
    "id-ID": "Indonesian",
    "is-IS": "Icelandic",
    "it-IT": "Italian",
    "ja-JP": "Japanese",
    "km-KH": "Khmer",
    "ko-KR": "Korean",
    "la": "Latin",
    "lij-IT": "Ligurian",
    "lt-LT": "Lithuanian",
    "lv-LV": "Latvian",
    "mn-MN": "Mongolian",
    "ms-MY": "Malay",
    "nb-NO": "Norwegian Bokmål",
    "nl-NL": "Dutch",
    "nn-NO": "Norwegian Nynorsk",
    "pa-PK": "Punjabi (Pakistan)",
    "pl-PL": "Polish",
    "pt-BR": "Portuguese (Brazil)",
    "pt-PT": "Portuguese (Portugal)",
    "ro-RO": "Romanian",
    "ru-RU": "Russian",
    "sk-SK": "Slovak",
    "sl-SI": "Slovenian",
    "sr-Cyrl-RS": "Serbian (Cyrillic)",
    "sr-Latn-RS": "Serbian (Latin)",
    "sv-SE": "Swedish",
    "th-TH": "Thai",
    "tr-TR": "Turkish",
    "uk-UA": "Ukrainian",
    "vi-VN": "Vietnamese",
    "zh-CN": "Chinese (Simplified)",
    "zh-TW": "Chinese (Traditional)",
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

    # Parse date formats
    for date_node in root.findall('csl:date', ns) or root.findall('date'):
        form = date_node.get('form', 'numeric')
        parts = []
        for part_node in date_node.findall('csl:date-part', ns) or date_node.findall('date-part'):
            part = {
                'name': part_node.get('name', ''),
                'form': part_node.get('form', ''),
                'prefix': part_node.get('prefix', ''),
                'suffix': part_node.get('suffix', ''),
                'range-delimiter': part_node.get('range-delimiter', '–'),
            }
            parts.append(part)
        if parts:
            dates[form] = {'parts': parts}

    # Parse style-options
    for options_node in root.findall('csl:style-options', ns) or root.findall('style-options'):
        if options_node.get('punctuation-in-quote'):
            options['punctuation-in-quote'] = options_node.get('punctuation-in-quote') == 'true'
        if options_node.get('limit-day-ordinals-to-day-1'):
            options['limit-day-ordinals-to-day-1'] = options_node.get('limit-day-ordinals-to-day-1') == 'true'

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

    # Add date formats
    if data.get('dates'):
        lines.append("  // Date formats")
        lines.append("  dates: (")
        for form, date_data in sorted(data['dates'].items()):
            lines.append(f'    "{form}": (')
            lines.append("      parts: (")
            for part in date_data.get('parts', []):
                lines.append("        (")
                lines.append(f'          name: "{part["name"]}",')
                lines.append(f'          form: "{part["form"]}",')
                # Escape prefix/suffix for Typst strings
                prefix = part["prefix"].replace("\\", "\\\\").replace('"', '\\"')
                suffix = part["suffix"].replace("\\", "\\\\").replace('"', '\\"')
                range_delim = part["range-delimiter"].replace("\\", "\\\\").replace('"', '\\"')
                lines.append(f'          prefix: "{prefix}",')
                lines.append(f'          suffix: "{suffix}",')
                lines.append(f'          range-delimiter: "{range_delim}",')
                lines.append("        ),")
            lines.append("      ),")
            lines.append("    ),")
        lines.append("  ),")
    else:
        lines.append("  dates: (:),")

    # Add options
    if data.get('options'):
        lines.append("  // Locale options")
        lines.append("  options: (")
        for key, value in sorted(data['options'].items()):
            if isinstance(value, bool):
                lines.append(f'    "{key}": {str(value).lower()},')
            else:
                lines.append(f'    "{key}": "{value}",')
        lines.append("  ),")
    else:
        lines.append("  options: (:),")

    lines.extend([
        ")",
        "",
    ])

    return "\n".join(lines)


def generate_data_typ(locale_codes: list[str]) -> str:
    """Generate the data.typ file with imports, registry, and mappings."""
    lines = [
        "// citrus - Locale Data",
        "//",
        "// Auto-generated by scripts/generate-locales.py",
        "// DO NOT EDIT MANUALLY - edit the generator script instead.",
        "",
        "// =============================================================================",
        "// Import All Locales",
        "// =============================================================================",
        "",
    ]

    # Generate imports
    for code in sorted(locale_codes):
        lines.append(f'#import "{code}.typ": locale as _{code}')

    lines.extend([
        "",
        "// =============================================================================",
        "// Built-in Locale Registry",
        "// =============================================================================",
        "",
        "#let _builtin-locales = (",
    ])

    # Generate registry
    for code in sorted(locale_codes):
        lines.append(f'  "{code}": _{code},')

    # Add locale aliases (non-standard codes that map to standard locales)
    # kh-KH is a common typo/variant for km-KH (Khmer)
    locale_aliases = {
        "kh-KH": "km-KH",
    }
    for alias, target in sorted(locale_aliases.items()):
        if target in locale_codes:
            safe_target = target.replace("-", "-")
            lines.append(f'  "{alias}": _{safe_target},')

    lines.extend([
        ")",
        "",
        "// =============================================================================",
        "// Language Detection Data",
        "// =============================================================================",
        "",
        "// Language name to code mappings",
        "#let _language-name-map = (",
    ])

    # Generate language name map from LANG_NAMES
    name_to_code = {}
    for code, name in LANG_NAMES.items():
        # Extract the base language name (before parentheses)
        base_name = name.split("(")[0].strip().lower()
        # Get the language prefix (first part of locale code)
        lang_prefix = code.split("-")[0].lower()
        if base_name not in name_to_code:
            name_to_code[base_name] = lang_prefix

    for name in sorted(name_to_code.keys()):
        lines.append(f'  "{name}": "{name_to_code[name]}",')

    lines.extend([
        ")",
        "",
        "// Language code prefixes for detection",
        "#let _language-code-prefixes = (",
    ])

    # Generate unique language prefixes
    prefixes = set()
    for code in locale_codes:
        prefix = code.split("-")[0].lower()
        prefixes.add(prefix)

    for prefix in sorted(prefixes):
        lines.append(f'  "{prefix}",')

    lines.extend([
        ")",
        "",
        "// =============================================================================",
        "// Language Family Mappings",
        "// =============================================================================",
        "",
        "/// Language family mappings for fallback (prefix -> default locale)",
        "#let _language-family-map = (",
    ])

    # Generate family map - pick first locale for each prefix (or specific defaults)
    prefix_to_locale = {}
    # Define preferred defaults for common languages
    preferred_defaults = {
        "en": "en-US",
        "zh": "zh-CN",
        "de": "de-DE",
        "fr": "fr-FR",
        "es": "es-ES",
        "pt": "pt-BR",
        "sr": "sr-Latn-RS",
        "kh": "km-KH",  # kh is often used as an alias for km (Khmer)
    }

    for code in sorted(locale_codes):
        prefix = code.split("-")[0].lower()
        if prefix not in prefix_to_locale:
            prefix_to_locale[prefix] = preferred_defaults.get(prefix, code)

    for prefix in sorted(prefix_to_locale.keys()):
        lines.append(f'  "{prefix}": "{prefix_to_locale[prefix]}",')

    # Add language prefix aliases that aren't derived from locale codes
    # These are manually added for common alternative codes
    if "kh" not in prefix_to_locale and "km-KH" in locale_codes:
        lines.append('  "kh": "km-KH",')

    lines.extend([
        ")",
        "",
    ])

    return "\n".join(lines)


def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent

    # Use official CSL locales from https://github.com/citation-style-language/locales
    xml_base = project_dir / "references" / "csl-locales"
    output_dir = project_dir / "src" / "parsing" / "locales"

    successful_locales = []

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
            successful_locales.append(our_name)

        except Exception as e:
            print(f"ERROR {our_name}: {e}")

    # Generate data.typ
    if successful_locales:
        data_content = generate_data_typ(successful_locales)
        data_path = output_dir / "data.typ"
        data_path.write_text(data_content, encoding='utf-8')
        print(f"\nGenerated data.typ with {len(successful_locales)} locales")


if __name__ == "__main__":
    main()
