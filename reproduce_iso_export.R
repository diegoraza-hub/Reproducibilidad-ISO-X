#!/usr/bin/env Rscript

# Reproducibilidad-ISO-X
# Pipeline en R para reproducir:
# - PSM (NN caliper 0.05, exact matching dentro de país-año)
# - Logit principal (OR y efectos marginales)
# - Robustez kernel (bw 0.06)
# - Tobit en cuota exportadora (entre exportadores)
#
# Requiere: los .dta de WBES ubicados en data/raw/
# Archivos esperados (nombres por defecto):
#   Colombia-2017-full-data.dta
#   Colombia-2023-full-data.dta
#   Ecuador-2017-full-data.dta
#   Ecuador-2024-full-data.dta
#   Peru-2017-full-data.dta
#   Peru-2023-full-data.dta

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(stringr)
  library(MatchIt)
  library(margins)
  library(AER)
  library(jsonlite)
  library(readr)
})

set.seed(42)

# -------------------------
# 0) CONFIG
# -------------------------

RAW_DIR <- "data/raw"
OUT_DIR <- "outputs"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(OUT_DIR, "tables"), showWarnings = FALSE, recursive = TRUE)

files <- tibble::tribble(
  ~file,                           ~country, ~year,
  "Colombia-2017-full-data.dta",   "COL",    "2017",
  "Colombia-2023-full-data.dta",   "COL",    "2023",
  "Ecuador-2017-full-data.dta",    "ECU",    "2017",
  "Ecuador-2024-full-data.dta",    "ECU",    "2024",
  "Peru-2017-full-data.dta",       "PER",    "2017",
  "Peru-2023-full-data.dta",       "PER",    "2023"
)

# Variables WBES (según el manuscrito)
VAR_ISO   <- "b8"
VAR_SALES <- "d2"
VAR_EMP   <- "l1"
# Export share: en WBES suele estar separada en exportación directa e indirecta (d3c y d3b).
# Este pipeline usa exp_share_any = d3b + d3c.
VAR_EXP_IND <- "d3b"
VAR_EXP_DIR <- "d3c"

# Sector ISIC (heurístico): intentar encontrar una columna que contenga "isic"
detect_isic <- function(df) {
  cand <- names(df)[str_detect(tolower(names(df)), "isic")]
  if (length(cand) == 0) stop("No se encontró variable ISIC en el .dta. Ajusta detect_isic().")
  # preferir la primera
  cand[[1]]
}

winsorize <- function(x, p = 0.01) {
  q <- quantile(x, probs = c(p, 1 - p), na.rm = TRUE)
  x[x < q[[1]]] <- q[[1]]
  x[x > q[[2]]] <- q[[2]]
  x
}

recode_iso <- function(x) {
  # WBES: 1 = Sí, 2 = No (frecuente). Mapear 2 a 0.
  x <- as.numeric(x)
  x <- dplyr::recode(x, `2` = 0)
  x
}

# -------------------------
# 1) LOAD + CLEAN
# -------------------------

dfs <- lapply(seq_len(nrow(files)), function(i) {
  f <- files$file[[i]]
  p <- file.path(RAW_DIR, f)
  if (!file.exists(p)) stop(paste("Falta archivo:", p))
  df <- read_dta(p)
  df$country <- files$country[[i]]
  df$year <- files$year[[i]]
  df
})

raw <- bind_rows(dfs)

# detectar ISIC y construir ISIC2
isic_var <- detect_isic(raw)

core <- raw %>%
  transmute(
    country = as.character(country),
    year = as.character(year),
    iso = recode_iso(.data[[VAR_ISO]]),
    sales = as.numeric(.data[[VAR_SALES]]),
    emp = as.numeric(.data[[VAR_EMP]]),
    exp_ind = as.numeric(.data[[VAR_EXP_IND]]),
    exp_dir = as.numeric(.data[[VAR_EXP_DIR]]),
    isic_raw = .data[[isic_var]]
  ) %>%
  mutate(
    exp_ind = ifelse(is.na(exp_ind), 0, exp_ind),
    exp_dir = ifelse(is.na(exp_dir), 0, exp_dir),
    exp_share = exp_ind + exp_dir,
    exporter = as.integer(exp_share > 0),
    # ISIC2: tomar dos primeros dígitos numéricos
    isic2 = suppressWarnings(as.integer(str_sub(as.character(as.integer(isic_raw)), 1, 2))),
    ctry_year = paste0(country, "_", year)
  ) %>%
  filter(!is.na(iso), !is.na(sales), !is.na(emp), !is.na(isic2))

# winsorizar y logs
core <- core %>%
  mutate(
    sales_w = winsorize(sales, 0.01),
    emp_w   = winsorize(emp, 0.01),
    ln_sales = log(pmax(sales_w, 1e-6)),
    ln_emp   = log(pmax(emp_w, 1e-6))
  )

# descriptivos
desc <- core %>%
  group_by(iso) %>%
  summarise(
    n = n(),
    mean_sales = mean(sales_w, na.rm = TRUE),
    median_sales = median(sales_w, na.rm = TRUE),
    mean_emp = mean(emp_w, na.rm = TRUE),
    median_emp = median(emp_w, na.rm = TRUE),
    exporter_rate = mean(exporter, na.rm = TRUE),
    exp_share_mean = mean(exp_share, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(desc, file.path(OUT_DIR, "tables", "descriptives_by_iso.csv"))

# -------------------------
# 2) PSM: NN caliper 0.05 (exact dentro de país-año)
# -------------------------

# Propensity score: iso ~ ln_sales + ln_emp + FE sector + FE país-año
# MatchIt calcula distancia logit internamente con method = "nearest".
m_nn <- matchit(
  iso ~ ln_sales + ln_emp + factor(isic2) + factor(ctry_year),
  data = core,
  method = "nearest",
  distance = "logit",
  caliper = 0.05,
  replace = FALSE,
  exact = ~ ctry_year
)

matched_nn <- match.data(m_nn)

# balance SMD (MatchIt summary ya lo calcula, guardamos tabla)
bal_nn <- summary(m_nn, standardize = TRUE)$sum.matched
write.csv(bal_nn, file.path(OUT_DIR, "tables", "balance_nn.csv"), row.names = TRUE)

# -------------------------
# 3) MODELO PRINCIPAL: logit con FE + controles (sobre matched sample)
# -------------------------

fit_logit <- glm(
  exporter ~ iso + ln_sales + ln_emp + factor(isic2) + factor(ctry_year),
  data = matched_nn,
  family = binomial(),
  weights = matched_nn$weights
)

coef_iso <- coef(fit_logit)[["iso"]]
or_iso <- unname(exp(coef_iso))

# Efecto marginal promedio (AME) con margins (sobre matched sample)
ame <- suppressWarnings(margins(fit_logit, variables = "iso", data = matched_nn, weights = matched_nn$weights))
ame_iso <- as.numeric(summary(ame)$AME[1])

# -------------------------
# 4) ROBUSTEZ: kernel bw 0.06
# -------------------------
m_kernel <- matchit(
  iso ~ ln_sales + ln_emp + factor(isic2) + factor(ctry_year),
  data = core,
  method = "kernel",
  distance = "logit",
  bw = 0.06,
  exact = ~ ctry_year
)
matched_k <- match.data(m_kernel)

fit_logit_k <- glm(
  exporter ~ iso + ln_sales + ln_emp + factor(isic2) + factor(ctry_year),
  data = matched_k,
  family = binomial(),
  weights = matched_k$weights
)
or_iso_k <- unname(exp(coef(fit_logit_k)[["iso"]]))

# -------------------------
# 5) TOBIT en cuota exportadora (entre exportadores)
# -------------------------
sub_exp <- matched_nn %>% filter(exporter == 1)

tobit_coef <- NA_real_
tobit_p <- NA_real_

if (nrow(sub_exp) > 0) {
  fit_tobit <- AER::tobit(
    exp_share ~ iso + ln_sales + ln_emp + factor(isic2) + factor(ctry_year),
    left = 0, right = 100,
    data = sub_exp,
    weights = sub_exp$weights
  )
  sm <- summary(fit_tobit)
  if ("iso" %in% rownames(sm$coefficients)) {
    tobit_coef <- sm$coefficients["iso", "Estimate"]
    tobit_p <- sm$coefficients["iso", "Pr(>|z|)"]
  }
}

# -------------------------
# 6) PLACEBO: solo 2017
# -------------------------
core_2017 <- core %>% filter(year == "2017")
placebo_or <- NA_real_
placebo_p <- NA_real_
if (length(unique(core_2017$iso)) == 2) {
  fit_placebo <- glm(
    exporter ~ iso + ln_sales + ln_emp + factor(isic2) + factor(ctry_year),
    data = core_2017,
    family = binomial()
  )
  placebo_or <- unname(exp(coef(fit_placebo)[["iso"]]))
  placebo_p <- summary(fit_placebo)$coefficients["iso", "Pr(>|z|)"]
}

# -------------------------
# 7) RESUMEN JSON
# -------------------------
summary_out <- list(
  n_total = nrow(core),
  n_matched_nn = nrow(matched_nn),
  main_logit_or_iso = or_iso,
  main_logit_ame_iso = ame_iso,
  kernel_logit_or_iso = or_iso_k,
  tobit_coef_iso = tobit_coef,
  tobit_p_iso = tobit_p,
  placebo_2017_or_iso = placebo_or,
  placebo_2017_p_iso = placebo_p
)

write_json(summary_out, file.path(OUT_DIR, "repro_summary_R.json"), auto_unbox = TRUE, pretty = TRUE)

message("Listo. Ver outputs/repro_summary_R.json y outputs/tables/")
