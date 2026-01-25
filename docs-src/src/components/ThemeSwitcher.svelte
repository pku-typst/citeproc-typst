<script lang="ts">
  import { onMount } from "svelte";

  type Theme = "system" | "light" | "dark";

  interface Translations {
    system: string;
    light: string;
    dark: string;
  }

  let { t }: { t: Translations } = $props();

  let theme = $state<Theme>("system");
  let isOpen = $state(false);

  const themes: { value: Theme; icon: string }[] = [
    { value: "system", icon: "💻" },
    { value: "light", icon: "☀️" },
    { value: "dark", icon: "🌙" },
  ];

  function getLabel(value: Theme): string {
    return t[value];
  }

  function getCurrentIcon(): string {
    return themes.find((t) => t.value === theme)?.icon ?? "💻";
  }

  function setTheme(newTheme: Theme) {
    theme = newTheme;
    isOpen = false;

    if (newTheme === "system") {
      document.documentElement.removeAttribute("data-theme");
      localStorage.removeItem("theme");
    } else {
      document.documentElement.setAttribute("data-theme", newTheme);
      localStorage.setItem("theme", newTheme);
    }
  }

  function handleClickOutside(event: MouseEvent) {
    const target = event.target as HTMLElement;
    if (!target.closest(".theme-switcher")) {
      isOpen = false;
    }
  }

  onMount(() => {
    // Load saved theme
    const saved = localStorage.getItem("theme") as Theme | null;
    if (saved && ["light", "dark"].includes(saved)) {
      theme = saved;
      document.documentElement.setAttribute("data-theme", saved);
    }

    document.addEventListener("click", handleClickOutside);
    return () => document.removeEventListener("click", handleClickOutside);
  });
</script>

<div class="theme-switcher relative">
  <button
    onclick={() => (isOpen = !isOpen)}
    class="inline-flex items-center justify-center w-9 h-9 rounded-full border border-border bg-card hover:bg-accent transition-colors"
    title={getLabel(theme)}
    aria-label={getLabel(theme)}
  >
    <span class="text-base">{getCurrentIcon()}</span>
  </button>

  {#if isOpen}
    <div
      class="absolute right-0 top-full mt-2 py-1 bg-card border border-border rounded-lg shadow-lg z-50 min-w-[120px]"
    >
      {#each themes as { value, icon }}
        <button
          onclick={() => setTheme(value)}
          class="w-full px-3 py-2 text-sm text-left flex items-center gap-2 hover:bg-accent transition-colors {theme ===
          value
            ? 'text-primary font-medium'
            : 'text-foreground'}"
        >
          <span>{icon}</span>
          <span>{getLabel(value)}</span>
          {#if theme === value}
            <span class="ml-auto text-primary">✓</span>
          {/if}
        </button>
      {/each}
    </div>
  {/if}
</div>
