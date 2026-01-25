export const translations = {
  zh: {
    meta: {
      title: "citeproc-typst 兼容性测试",
      lang: "zh-CN",
    },
    hero: {
      title: "citeproc-typst",
      description:
        "CSL (Citation Style Language) 处理器的 Typst 原生实现。支持学术文献引用格式化，兼容 Zotero 等工具的 CSL 样式。",
    },
    stats: {
      cslStyles: "CSL 样式",
      testCases: "测试用例",
      benchmarkStyles: "Benchmark 样式",
      total: "总测试数",
      totalStyles: "总样式数",
      compiled: "编译通过",
      errors: "编译错误",
      failed: "编译失败",
      passRate: "通过率",
    },
    sections: {
      citeproc: {
        title: "citeproc-js 测试套件",
        description:
          "使用 citeproc-js 测试套件中的 CSL 样式和数据进行编译测试。",
        note: "编译通过仅表示 citeproc-typst 能够处理该测试用例，不保证输出结果与 citeproc-js 完全一致。",
      },
      csl: {
        title: "CSL 样式兼容性",
        description:
          "测试 zotero-chinese/styles 中的所有 CSL 样式是否可以正常编译。",
        note: "编译通过仅表示 citeproc-typst 能够解析并处理该样式，不保证输出格式完全符合预期。",
      },
      benchmark: {
        title: "性能趋势",
        description: "追踪代表性 CSL 样式的编译时间变化，用于检测性能回归。",
      },
    },
    category: {
      viewByCategory: "按类别查看详情",
      categories: "个类别",
    },
    styleGrid: {
      searchPlaceholder: "搜索样式名称...",
      found: "找到",
      styles: "个样式",
      total: "共",
      noResults: "未找到匹配的样式",
      clearSearch: "清除搜索",
    },
    chart: {
      compileTime: "编译时间 (ms)",
      commit: "Commit",
      noData: "暂无性能数据",
      noDataHint: "首次 CI 运行后将显示趋势图",
    },
    footer: {
      buildTime: "构建时间",
    },
    langSwitch: {
      current: "中文",
      switchTo: "English",
    },
    theme: {
      system: "跟随系统",
      light: "浅色",
      dark: "深色",
    },
  },
  en: {
    meta: {
      title: "citeproc-typst Compatibility Tests",
      lang: "en",
    },
    hero: {
      title: "citeproc-typst",
      description:
        "Native Typst implementation of CSL (Citation Style Language) processor. Supports academic citation formatting, compatible with Zotero CSL styles.",
    },
    stats: {
      cslStyles: "CSL Styles",
      testCases: "Test Cases",
      benchmarkStyles: "Benchmark Styles",
      total: "Total Tests",
      totalStyles: "Total Styles",
      compiled: "Compiled",
      errors: "Errors",
      failed: "Failed",
      passRate: "Pass Rate",
    },
    sections: {
      citeproc: {
        title: "citeproc-js Test Suite",
        description:
          "Compile tests using CSL styles and data from the citeproc-js test suite.",
        note: "Compilation success only indicates citeproc-typst can process the test case, not that output matches citeproc-js exactly.",
      },
      csl: {
        title: "CSL Style Compatibility",
        description:
          "Test all CSL styles from zotero-chinese/styles for successful compilation.",
        note: "Compilation success only indicates citeproc-typst can parse and process the style, not that output format is fully compliant.",
      },
      benchmark: {
        title: "Performance Trends",
        description:
          "Track compilation time changes for representative CSL styles to detect regressions.",
      },
    },
    category: {
      viewByCategory: "View by category",
      categories: "categories",
    },
    styleGrid: {
      searchPlaceholder: "Search style name...",
      found: "Found",
      styles: "styles",
      total: "Total",
      noResults: "No matching styles found",
      clearSearch: "Clear search",
    },
    chart: {
      compileTime: "Compile Time (ms)",
      commit: "Commit",
      noData: "No performance data",
      noDataHint: "Trend chart will appear after first CI run",
    },
    footer: {
      buildTime: "Build time",
    },
    langSwitch: {
      current: "English",
      switchTo: "中文",
    },
    theme: {
      system: "System",
      light: "Light",
      dark: "Dark",
    },
  },
} as const;

export type Translations = typeof translations.zh;
