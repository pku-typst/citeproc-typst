// CSL Compatibility Test Script
//
// Tests citeproc-typst with a given CSL style using comprehensive test cases.
//
// Usage: typst compile test-csl-compatibility.typ --root . --input csl=path/to/style.csl

#import "/lib.typ": csl-bibliography, init-csl, multicite

#let csl-path = sys.inputs.at("csl", default: none)

#if csl-path == none {
  text(
    fill: red,
    "ERROR: No CSL file specified. Use --input csl=path/to/file.csl",
  )
} else {
  let bib-content = read("/tests/test-gb7714.bib") // Absolute path from project root
  // CSL path is relative to project root, so use "/" prefix for absolute path from root
  let csl-content = read("/" + csl-path)

  show: init-csl.with(bib-content, csl-content)

  set page(margin: 2cm)
  set text(size: 10pt)
  set par(justify: true)

  align(center)[
    #text(size: 14pt, weight: "bold")[CSL 兼容性测试]
    #v(0.3em)
    #text(size: 9pt, fill: gray)[#csl-path]
  ]

  v(0.5em)

  [= 期刊文章]

  [中文期刊：王晓华@wang2010guide 发表了科技论文摘要写作方法。]

  [英文期刊：Smith 等@smith2020climate 研究了气候变化。Smith 还发表了政策研究@smith2020policy。]

  [= 专著]

  [中文专著：刘明和李华@liu2015method 系统论述了科研方法。]

  [英文专著：Kopka 和 Daly@kopka2004guide 撰写了 LaTeX 指南。]

  [带前缀姓名：de Gaulle@gaulle1970memoirs 回忆二战历史。]

  [带后缀姓名：Gates III@gates2021life 讨论气候议题。]

  [= 学位论文]

  [博士论文：张伟@zhang2018thesis 研究深度学习与 NLP。]

  [= 会议论文]

  [Jones@jones2019conference 在 ACL 2019 发表论文。]

  [= 技术报告]

  [中科院@report2022 发布 AI 发展报告。]

  [= 标准与专利]

  [国家标准@gb7714 规定了参考文献著录规则。]

  [李四等@patent2020 申请图像识别专利。]

  [= 在线资源]

  [网页：Typst 文档@webpage2024。带日期网页@webpage_with_date。]

  [预印本：Brown 和 Smith@online_article2023 发表 LLM 综述。]

  [= 报纸与期刊]

  [报纸文章@newspaper2024 报道科研进展。]

  [连续出版物《计算机学报》@periodical2023。]

  [= 汇编与析出文献]

  [汇编@collection2020 收录多篇论文。]

  [中文书章节：张华@chapter2019 讨论深度学习。]

  [英文书章节：Vaswani 等@chapter_en2020 介绍 Transformer。]

  [= 姓名格式测试]

  [连字符名：Sartre@sartre1946existentialism 讨论存在主义。]

  [van 前缀：van Beethoven 和 Mozart@beethoven2020music 探讨音乐。]

  [Jr. 后缀：King Jr.@king1963dream 发表演讲。]

  [= 多文献引用]

  [合并引用：#multicite("wang2010guide", "smith2020climate", "kopka2004guide")]

  [带页码：#multicite((key: "wang2010guide", supplement: [53]), "smith2020climate")]

  [= 引用形式]

  [上标形式（默认）：研究表明@smith2020climate]

  [非上标形式：详见#cite(<smith2020climate>, form: "prose")]

  [仅作者：#cite(<smith2020climate>, form: "author")]

  [仅年份：#cite(<smith2020climate>, form: "year")]

  [= 参考文献]
}

// Bibliography outside if-else to avoid layout convergence issues
#csl-bibliography(title: none)
