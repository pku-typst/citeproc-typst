<script lang="ts">
  import { onMount } from "svelte";
  import Chart from "chart.js/auto";

  interface BenchmarkRun {
    date: string;
    commit: string;
    results: Record<string, number>;
  }

  interface BenchmarkHistory {
    runs: BenchmarkRun[];
    styles: string[];
  }

  let { history }: { history: BenchmarkHistory } = $props();
  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  const colors = [
    "#1a73e8",
    "#34a853",
    "#ea4335",
    "#fbbc04",
    "#9334e6",
    "#00acc1",
    "#ff7043",
    "#5c6bc0",
  ];

  onMount(() => {
    if (history.runs.length === 0) return;

    const labels = history.runs.map((r) => r.commit);
    const datasets = history.styles.map((style, i) => ({
      label: style,
      data: history.runs.map((r) => r.results[style] ?? null),
      borderColor: colors[i % colors.length],
      backgroundColor: colors[i % colors.length] + "20",
      tension: 0.1,
      fill: false,
    }));

    chart = new Chart(canvas, {
      type: "line",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              boxWidth: 12,
              padding: 15,
            },
          },
          tooltip: {
            callbacks: {
              label: (ctx) => `${ctx.dataset.label}: ${ctx.parsed.y}ms`,
            },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: "编译时间 (ms)",
            },
          },
          x: {
            title: {
              display: true,
              text: "Commit",
            },
          },
        },
      },
    });

    return () => {
      chart?.destroy();
    };
  });
</script>

{#if history.runs.length > 0}
  <div class="chart-container">
    <canvas bind:this={canvas}></canvas>
  </div>
{:else}
  <div class="no-data">暂无性能数据</div>
{/if}

<style>
  .chart-container {
    height: 350px;
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1rem;
  }

  .no-data {
    padding: 2rem;
    text-align: center;
    color: var(--text-secondary);
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 8px;
  }
</style>
