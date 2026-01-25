import { translations, type Translations } from "./translations";

export type Locale = "zh" | "en";
export const defaultLocale: Locale = "zh";
export const locales: Locale[] = ["zh", "en"];

export function useTranslation(locale: Locale): Translations {
  return translations[locale];
}

export function getLocalePath(locale: Locale, path: string = ""): string {
  const base = "/citeproc-typst";
  if (locale === "zh") {
    return `${base}/${path}`;
  }
  return `${base}/en/${path}`;
}

export function getAlternateLocale(locale: Locale): Locale {
  return locale === "zh" ? "en" : "zh";
}

export { translations };
