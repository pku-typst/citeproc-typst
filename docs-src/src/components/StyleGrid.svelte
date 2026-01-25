<script lang="ts">
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

<input
  type="text"
  class="search-box"
  placeholder="🔍 搜索样式名称..."
  bind:value={query}
/>

<div class="styles-grid">
  {#each filteredStyles as style}
    <a href={style.url} class="style-link" target="_blank">
      {style.name}
    </a>
  {/each}
</div>

<style>
  .search-box {
    width: 100%;
    padding: 0.75rem 1rem;
    font-size: 1rem;
    border: 1px solid var(--border);
    border-radius: 8px;
    margin: 1rem 0;
  }

  .search-box:focus {
    outline: none;
    border-color: var(--primary);
    box-shadow: 0 0 0 2px rgba(26, 115, 232, 0.2);
  }

  .styles-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 0.75rem;
    margin-top: 1rem;
    max-height: 600px;
    overflow-y: auto;
    padding: 0.5rem;
  }

  .style-link {
    display: block;
    padding: 0.75rem 1rem;
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    text-decoration: none;
    font-size: 0.9rem;
    transition: all 0.15s;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .style-link:hover {
    border-color: var(--primary);
    background: #e8f0fe;
  }
</style>
