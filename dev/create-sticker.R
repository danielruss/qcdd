# Run from the package root: Rscript dev/create-sticker.R
# Optional hexSticker renderer: Rscript dev/create-sticker.R --hexsticker
# Artwork uses locally installed Helvetica Neue and Arial fonts.
library(ggplot2)

# Register the font for both raster output and portable SVG outlines.
font_file <- systemfonts::match_fonts("Helvetica Neue")$path
sysfonts::font_add("qcdd-label", regular = font_file)
url_font_file <- systemfonts::match_fonts("Arial", weight = "bold")$path
sysfonts::font_add("qcdd-url", regular = url_font_file)
showtext::showtext_opts(dpi = 400)
showtext::showtext_auto()

if (!file.exists("DESCRIPTION") ||
    read.dcf("DESCRIPTION")[1, "Package"] != "qcdd") {
  stop("Run this script from the qcdd package root.")
}
if (!requireNamespace("svglite", quietly = TRUE)) {
  stop("Install svglite to export the SVG logo.")
}

# NCI Red: NCI Branding and Logo Use Guidelines (February 2018), page 3.
# https://policyviz.com/wp-content/uploads/2019/11/NCI-Branding-and-Logo-Use-Guide_2.pdf
nci_red <- "#BB0E3D"
border <- "#780927"
# NCI Design System accent-cool-light (navy-30).
# https://designsystem.cancer.gov/foundations/color
hex_border <- "#92A9C8"
paper <- "#FFFFFF"

ink <- "#606060"
header <- "#14315C"
badge_green <- "#00B140"
check_colour <- "#14315C"

# A four-column concept table with alternating shading and a validation mark.
rows <- expand.grid(y = c(1.37, 1.18, .99), column = 0:3)
rows$x <- .47 + .30 * rows$column
rows$xend <- rows$x + rep(c(.14, .10, .12), 4)
badge <- data.frame(
  x = 1.48 + .22 * cos(seq(0, 2 * pi, length.out = 100)),
  y = .91 + .22 * sin(seq(0, 2 * pi, length.out = 100))
)
art_layers <- list(
  annotate("rect", xmin = .425, xmax = 1.625, ymin = .79, ymax = 1.52,
           fill = border, colour = NA),
  annotate("rect", xmin = .40, xmax = 1.60, ymin = .82, ymax = 1.55,
           fill = paper, colour = NA),
  annotate("rect", xmin = c(.40, 1.00), xmax = c(.70, 1.30),
           ymin = .82, ymax = 1.49,
           fill = "#F7E3E9", colour = NA),
  annotate("rect", xmin = .40, xmax = 1.60, ymin = 1.49, ymax = 1.55,
           fill = header, colour = NA),
  geom_segment(data = data.frame(y = c(1.275, 1.085)),
               aes(x = .40, xend = 1.60, y = y, yend = y),
               colour = ink, linewidth = .45, alpha = .18),
  geom_segment(data = rows, aes(x = x, xend = xend, y = y, yend = y),
               colour = ink, linewidth = 1.1, lineend = "round"),
  geom_polygon(data = badge, aes(x, y), fill = badge_green,
               colour = nci_red, linewidth = 1.5),
  geom_path(data = data.frame(x = c(1.37, 1.45, 1.60),
                             y = c(.91, .83, 1.00)),
            aes(x, y), colour = check_colour, linewidth = 1.7,
            lineend = "round", linejoin = "round")
)

hex <- data.frame(
  x = c(1, 1.866, 1.866, 1, .134, .134),
  y = c(2, 1.5, .5, 0, .5, 1.5)
)
sticker_theme <- theme_void() + theme(
  plot.background = element_rect(fill = "transparent", colour = NA),
  panel.background = element_rect(fill = "transparent", colour = NA),
  plot.margin = margin(3, 3, 3, 3)
)
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

if ("--hexsticker" %in% commandArgs(trailingOnly = TRUE)) {
  if (!requireNamespace("hexSticker", quietly = TRUE)) {
    stop("Install hexSticker to use --hexsticker.")
  }
  # hexSticker supplies its own hexagon and label. Place the same vector
  # artwork directly on its coordinate system to preserve fine detail.
  scratch <- tempfile(fileext = ".png")
  logo <- hexSticker::sticker(
    ggplot() + theme_void(), package = "qcdd",
    p_family = "qcdd-label", p_fontface = "plain", p_size = 10,
    p_x = .95, p_y = .61, p_color = paper,
    h_fill = nci_red, h_color = hex_border, h_size = 1.5,
    url = "github.com/danielruss/qcdd",
    u_x = 1.14, u_y = .17, u_angle = 30,
    u_family = "qcdd-url", u_size = 1.8, u_color = paper,
    filename = scratch
  ) + art_layers
  unlink(scratch)
} else {
  logo <- ggplot() +
    geom_polygon(data = hex, aes(x, y), fill = nci_red, colour = hex_border,
                 linewidth = 1.5, linejoin = "round") +
    art_layers +
    annotate("text", x = .95, y = .61, label = "qcdd",
             family = "qcdd-label", fontface = "plain", size = 10,
             colour = paper) +
    annotate("text", x = 1.14, y = .17,
             label = "github.com/danielruss/qcdd", hjust = 0,
             family = "qcdd-url", size = 1.8, angle = 30, colour = paper) +
    coord_fixed(xlim = c(.105, 1.895), ylim = c(-.03, 2.03), expand = FALSE) +
    sticker_theme
}

logo <- logo + annotate(
  "text", x = .95, y = .40, label = "QC - Data Dictionary",
  family = "qcdd-label", size = 2.1, colour = paper
)

ggsave("man/figures/logo.svg", logo, width = 2.6, height = 3,
       units = "in", bg = "transparent", device = svglite::svglite)
ggsave("man/figures/logo.png", logo, width = 2.6, height = 3,
       units = "in", dpi = 400, bg = "transparent")
message("Created man/figures/logo.png and man/figures/logo.svg")
