set.seed(1987)
library(party)

df <- read.table("data/eeesr.csv", TRUE, ",")[, c(1:3,5:8,14,16:28,31,33:38,40:47)]
colnames(df)[26:27] <- c("mean", "sd")
df <- df[!is.na(df$mean) & !is.na(df$sd), ]
ivar <- colnames(df)[!colnames(df) %in% c("ccode", "country", "mean", "sd")]
form <- as.formula(paste0("mean ~", paste0(ivar, collapse = "+")))

invisible(lapply(1:2, function(x) {
    png(paste0("figures/rf_", x, ".png"), width = 12, height = 12, units = "in", res = 300)
    fit <- ctree(form, df, controls = ctree_control(mtry = 3, maxdepth = 2))
    plot(fit, inner_panel = node_inner(fit, id = FALSE))
    dev.off()
}))
