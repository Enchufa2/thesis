options(bookdown.post.latex = function(x) {
  if (file.exists("pdfa")) {
    x[2] <- "\\usepackage[a-1b]{pdfx}"
    x[grep("definecolor", x)] <- "\\definecolor{uc3m}{RGB}{46, 44, 109}"
    x <- sub(",hyperxmp", "", x)
    x <- x[-grep("pdfcopyright", x)]
    x <- x[-grep("pdflicenseurl", x)]
  }
  
  if (file.exists("showframe"))
    x <- c(x[1], "\\geometry{showframe}", x[2:length(x)])
  
  ## save & restore caption
  x[2] <- paste0("\\makeatletter\\let\\tufte@caption\\@caption\\makeatother", x[2])
  hyperref <- grep("\\\\usepackage\\{hyperref\\}", x)
  x[hyperref] <- paste0(x[hyperref], "\\makeatletter\\let\\@caption\\tufte@caption\\makeatother")
  
  ## remove unnumbered sections (e.g., acks) from toc
  x <- x[-grep("\\\\addcontentsline\\{toc\\}\\{section\\}", x)]
  
  ## hack to remove noindent from abstract
  x <- sub("\\\\noindent \\\\colchunk", "\\\\colchunk", x)
  
  ## hack to avoid extra space before and after equation environments
  begin <- grep("\\\\begin\\{(align|equation)\\*?\\}", x) - 1
  end <- grep("\\\\end\\{(align|equation)\\*?\\}", x) + 1
  x[c(begin, end)] <- ifelse(x[c(begin, end)] == "", "%", x[c(begin, end)])
  gsub("\\\\SPACE", "", x)
})

options(
  knitr.graphics.auto_pdf = TRUE,
  knitr.kable.NA = "-"
)

invisible(Sys.setlocale("LC_ALL", "en_GB.UTF-8"))

margincite <- function(entry, pos="0pt") {
  if (knitr::is_html_output())
    paste0(" [", paste0("@", entry, collapse=";"), "]")
  else {
    entry <- paste0(entry, collapse=",")
    paste0("\\cite[", pos, "]{", entry, "}",
           "\\marginnote{\\hypersetup{hidelinks}\\color{white}",
           "\\citet{", entry, "}}")
  }
}

## use center environment and put caption at the end
.tune.table <- function(ktable) {
  if (attr(ktable, "format") != "latex")
    return(ktable)
  
  lines <- strsplit(ktable, "\n")[[1]]
  caption <- lines[grep("\\\\caption", lines)]
  if (grepl("table\\*", lines[1]))
    caption <- paste("\\vspace*{2mm}", caption, sep="\n")
  lines <- lines[-grep("\\\\caption|centering", lines)]
  tabular <- grep("\\\\(begin|end)\\{tabular", lines) + c(0, 1)
  center <- c("\\begin{center}", paste("\\end{center}", caption, sep="\n"))
  lines <- R.utils::insert(lines, tabular, center)
  out <- paste(lines, collapse = "\n")
  class(out) <- class(ktable)
  attributes(out) <- attributes(ktable)
  out
}

`%.%` <- function(x, y) paste0(x, y)
web.tex <- function(web, tex) ifelse(knitr::is_html_output(), web, tex)
textwidth <- 5
marginwidth <- 3
height <- 3
fullwidth <- 8.2

setHook(packageEvent("knitr", "onLoad"), function(...) {
  .kable <- getFromNamespace("kable", "knitr")
  .knit <- getFromNamespace("knit", "knitr")
  assignInNamespace("kable", function(...) .tune.table(.kable(...)), "knitr")
  assignInNamespace("knit", function(...) {
    knitr::opts_chunk$set(
      tidy = FALSE,
      echo = FALSE,
      fig.align = 'center',
      fig.width = textwidth,
      fig.height = height
    )
    .knit(...)
  }, "knitr")
})

library(magrittr)
library(ggplot2)
theme_set(
  ggthemes::theme_tufte(base_family="Palatino") + theme(
    plot.margin = margin(t=11/2, r=13),
    axis.title.y = element_blank()
  )
)
update_geom_defaults("text", list(family="Palatino"))
update_geom_defaults("label", list(family="Palatino"))

ggplot.default <- function(data=NULL, mapping=aes(), ...) {
  p <- ggplot2:::ggplot.default(data, mapping, ...) + ggthemes::geom_rangeframe(color = "black")
  if (file.exists("showframe"))
    p <- p + theme(panel.border = element_rect(fill = NA, colour = "black", size = rel(1)))
  p
}

ylab <- function(text) labs(subtitle=text)

facetlab <- function(text, hs, vs) annotation_custom(grid::textGrob(
  label = text,
  x = .5 + if(!missing(hs)) hs else 0,
  y = .99 - if(!missing(vs)) vs else 0,
  just = c("center", "top"),
  gp = grid::gpar(fontfamily = "Palatino", fontsize=8.8)
))

theme_adj_r_margin <- function(p, r) {
  g <- egg::set_panel_size(p, width=unit(textwidth, "in"))
  w <- grid::convertWidth(sum(g$widths), "in", TRUE)
  p + theme(
    plot.margin = margin(t=11/2, r=(fullwidth-w+r-0.08)*72.27),
    legend.box.margin = margin(l=26)
  )
}
