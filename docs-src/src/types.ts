export interface Style {
  name: string;
  url: string;
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

export interface TestSuiteSummary {
  total: number;
  pass: number;
  mismatch: number;
  excluded: number;
  error: number;
}

export interface TestSuiteCategory {
  category: string;
  total: number;
  pass: number;
  mismatch: number;
  excluded: number;
  error: number;
}

export interface TestSuiteMismatch {
  name: string;
  mode?: string;
  expected?: string;
  actual?: string;
}

export interface TestSuiteExcluded {
  name: string;
  reason: string;
}

export interface TestSuiteError {
  name: string;
  error: string;
}

export interface TestSuiteReport {
  compare?: boolean;
  summary: TestSuiteSummary;
  byCategory: TestSuiteCategory[];
  mismatches: TestSuiteMismatch[];
  excluded: TestSuiteExcluded[];
  errors: TestSuiteError[];
}

export interface PageData {
  // CSL compatibility
  csl: {
    total: number;
    passed: number;
    failed: number;
    styles: Style[];
  };
  // CSL test-suite results
  testSuite: TestSuiteReport;
  // Benchmark
  benchmark: BenchmarkHistory;
  // Build info
  buildTime: string;
}
