// citeproc-typst: 中文文档与示例
//
// 本文档展示 citeproc-typst 的功能特性
// 使用 GB/T 7714—2025（顺序编码制）格式

#import "../lib.typ": csl-bibliography, init-csl, multicite

#set page(margin: 2.5cm)
#set text(font: ("Times New Roman", "SimSun"), size: 12pt)
#set par(justify: true, leading: 1em, first-line-indent: (
  amount: 2em,
  all: true,
))
#set heading(numbering: "1")

#show heading.where(level: 1): set text(size: 15pt, weight: "bold")
#show heading.where(level: 2): set text(size: 13pt, weight: "bold")

#show: init-csl.with(
  read("refs-zh.bib"),
  read("gb7714-2025-numeric.csl"),
)

#align(center)[
  #text(size: 18pt, weight: "bold")[citeproc-typst 使用指南]
  #v(0.3em)
  #text(size: 12pt)[面向 Typst 的 CSL 引用处理器]
  #v(1em)
]

= 简介

*citeproc-typst* 是一个用于 Typst 的 CSL（Citation Style Language，引文样式语言）处理器。它允许你使用标准的 CSL 样式文件——与 Zotero、Mendeley 等引文管理软件相同的格式——在 Typst 文档中格式化引文和参考文献。

本文档既是使用说明，也是一个完整的工作示例。文档采用 GB/T 7714—2025（顺序编码制）格式。

= 基本引用

使用 Typst 标准的 `@key` 语法进行引用。例如，Kopka 等@kopka2004latex 提供了 LaTeX 的详细指南，而王晓华等@wang2010abstract 分析了科技论文摘要的写作要点。

引文可以出现在不同的语境中：
- 行文中引用：刘明等@liu2015method 系统论述了科学研究方法论。
- 括注式引用：这一问题已被广泛研究@li2018deep。
- 带页码引用：如张伟@zhang2018thesis[第 3 章]所述，深度学习有广泛应用。

= 多文献引用

引用多篇文献时，使用 `multicite` 函数：

#multicite("wang2010abstract", "li2018deep", "liu2015method")

也可以为单独的引用添加页码：

#multicite(
  (key: "wang2010abstract", supplement: [53]),
  "li2018deep",
  (key: "liu2015method", supplement: [第 5 章]),
)

= 引用折叠

对于顺序编码制，citeproc-typst 支持自动折叠连续编号的引用。

连续三篇文献（自动折叠为 `[2–4]`）：#multicite("wang2010abstract", "liu2015method", "li2018deep")

不连续的文献（显示为 `[2,4,6]`）：#multicite("wang2010abstract", "li2018deep", "smith2020climate")

混合情况（显示为 `[2–4,6]`）：#multicite("wang2010abstract", "liu2015method", "li2018deep", "smith2020climate")

= 引用形式

本库支持不同的引用形式：

- *默认形式*（顺序编码制为上标）：@zhang2018thesis
- *正文形式*（非上标）：#cite(<vaswani2017attention>, form: "prose")
- *仅作者*：#cite(<smith2020climate>, form: "author")
- *仅年份*：#cite(<kopka2004latex>, form: "year")

= 年份消歧

当同一作者在同一年份有多篇发表时，citeproc-typst 自动添加字母后缀进行区分：

- Smith 2020 年第一篇论文：@smith2020climate
- Smith 2020 年第二篇论文：@smith2020policy

参考文献列表中将分别显示为"2020a"和"2020b"。

= 中英文混排

本库自动识别文献语言，正确处理中英文混排的参考文献：

- 中文期刊文章：@wang2010abstract
- 英文期刊文章：@smith2020climate
- 中文专著：@liu2015method
- 英文专著：@kopka2004latex
- 中文学位论文：@zhang2018thesis
- 英文会议论文：@vaswani2017attention

= 支持的文献类型

本库支持多种文献类型：

- *期刊文章*：@wang2010abstract、@li2018deep、@smith2020climate
- *专著*：@liu2015method、@kopka2004latex
- *学位论文*：@zhang2018thesis
- *会议论文*：@vaswani2017attention
- *标准*：@gb7714
- *网络资源*：@typst2024docs

= 自定义渲染

`csl-bibliography` 支持 `full-control` 参数，允许完全自定义参考文献列表的渲染方式：

#csl-bibliography(
  title: heading(numbering: none)[参考文献（自定义渲染）],
  full-control: entries => {
    set par(hanging-indent: 2em, first-line-indent: 0em)
    for e in entries [
      // 使用 order 显示编号，rendered-body 显示不含编号的内容，ref-label 添加链接锚点
      [#e.order] #h(0.5em) #e.rendered-body #e.ref-label
      #parbreak()
    ]
  },
)
