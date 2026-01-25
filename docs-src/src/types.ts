export interface Style {
  name: string;
  url: string;
}

export interface Category {
  name: string;
  total: number;
  compiled: number;
}

export interface BenchmarkRun {
  date: string;
  commit: string;
  results: Record<string, number>;
}

export interface BenchmarkHistory {
  runs: BenchmarkRun[];
  styles: string[];
}

export interface PageData {
  // CSL compatibility
  csl: {
    total: number;
    passed: number;
    failed: number;
    styles: Style[];
  };
  // citeproc-js tests
  citeproc: {
    total: number;
    compiled: number;
    errors: number;
    categories: Category[];
  };
  // Benchmark
  benchmark: BenchmarkHistory;
  // Build info
  buildTime: string;
}
