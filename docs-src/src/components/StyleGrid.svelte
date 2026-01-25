<script lang="ts">
  import { Input } from "$lib/components/ui/input/index.js";

  interface Style {
    name: string;
    url: string;
  }

  let { styles }: { styles: Style[] } = $props();
  let query = $state("");

  let filteredStyles = $derived(
    styles.filter((s) => s.name.toLowerCase().includes(query.toLowerCase()))
  );
</script>

<Input
  type="text"
  class="my-4"
  placeholder="🔍 搜索样式名称..."
  bind:value={query}
/>

<div
  class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 max-h-[600px] overflow-y-auto p-2"
>
  {#each filteredStyles as style}
    <a
      href={style.url}
      class="block px-4 py-3 bg-card border border-border rounded-md text-foreground text-sm no-underline truncate transition-colors hover:border-primary hover:bg-accent"
      target="_blank"
    >
      {style.name}
    </a>
  {/each}
</div>
