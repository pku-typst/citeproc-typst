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
  <div
    class="h-[350px] bg-card border border-border rounded-lg p-4"
  >
    <canvas bind:this={canvas}></canvas>
  </div>
{:else}
  <div
    class="py-8 text-center text-muted-foreground bg-card border border-border rounded-lg"
  >
    暂无性能数据
  </div>
{/if}
