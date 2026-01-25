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

  interface Translations {
    compileTime: string;
    commit: string;
    noData: string;
    noDataHint: string;
  }

  let {
    history,
    t,
  }: {
    history: BenchmarkHistory;
    t: Translations;
  } = $props();

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  const colors = [
    "#3b82f6", // blue-500
    "#22c55e", // green-500
    "#ef4444", // red-500
    "#eab308", // yellow-500
    "#a855f7", // purple-500
    "#06b6d4", // cyan-500
    "#f97316", // orange-500
    "#6366f1", // indigo-500
    "#ec4899", // pink-500
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
              padding: 10,
              font: {
                size: 11,
              },
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
              text: t.compileTime,
            },
          },
          x: {
            title: {
              display: true,
              text: t.commit,
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
  <div class="overflow-x-auto -mx-2 px-2">
    <div
      class="min-w-[500px] h-[300px] sm:h-[350px] bg-card border border-border rounded-xl p-4"
    >
      <canvas bind:this={canvas}></canvas>
    </div>
  </div>
{:else}
  <div
    class="py-12 text-center text-muted-foreground bg-card border border-border rounded-xl"
  >
    <div class="text-4xl mb-2">📊</div>
    <div>{t.noData}</div>
    <div class="text-sm mt-1">{t.noDataHint}</div>
  </div>
{/if}
