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

<div class="space-y-3">
  <div class="relative">
    <Input
      type="text"
      placeholder="🔍 搜索样式名称..."
      bind:value={query}
    />
    {#if query}
      <button
        class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
        onclick={() => (query = "")}
        aria-label="清除搜索"
      >
        ✕
      </button>
    {/if}
  </div>

  <!-- Search results count -->
  <div class="flex items-center justify-between text-sm text-muted-foreground">
    <span>
      {#if query}
        找到 <span class="font-medium text-foreground">{filteredStyles.length}</span> 个样式
        {#if filteredStyles.length !== styles.length}
          （共 {styles.length} 个）
        {/if}
      {:else}
        共 <span class="font-medium text-foreground">{styles.length}</span> 个样式
      {/if}
    </span>
  </div>

  {#if filteredStyles.length > 0}
    <div
      class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-3 max-h-[400px] sm:max-h-[500px] overflow-y-auto p-1 -m-1"
    >
      {#each filteredStyles as style}
        <a
          href={style.url}
          class="block px-3 py-2.5 bg-card border border-border rounded-lg text-foreground text-sm no-underline truncate transition-all duration-200 hover:border-primary hover:bg-accent hover:shadow-sm"
          target="_blank"
          rel="noopener noreferrer"
          title={style.name}
        >
          {style.name}
        </a>
      {/each}
    </div>
  {:else}
    <div class="py-8 text-center text-muted-foreground bg-muted/50 rounded-lg">
      <div class="text-3xl mb-2">🔍</div>
      <div>未找到匹配的样式</div>
      <button
        class="mt-2 text-sm text-primary hover:underline"
        onclick={() => (query = "")}
      >
        清除搜索
      </button>
    </div>
  {/if}
</div>
