set.seed(1987)

library(party)
library(ggplot2)
library(edarf)
library(xtable)
library(countrycode)
library(doParallel)
library(dplyr)

cl <- makeCluster(8, "FORK")
registerDoParallel(cl)

df <- read.csv("data/eeesr.csv")

## plt <- df %>% group_by(year) %>% summarise(mean = mean(latent))
## ggplot(plt, aes(year,  mean)) + geom_point() + geom_line()

df <- df %>% select(-one_of("latent_lag", "physint_lag", "amnesty_lag", "year",
                            "physint", "parcomp", "disap", "kill", "polpris", "tort", "amnesty",
                            "disap_lag", "kill_lag", "polpris_lag", "tort_lag", "latent_sd",
                            "hro_shaming_lag", "avmdia_lag", "ainr_lag", "aibr_lag", "polity2",
                            "cwar", "wbimfstruct", "lagus", "lagun", "iwar"))

df <- df %>% mutate(gdppc = log(gdppc), pop = log(pop)) %>%
    group_by(ccode) %>%
        summarise_each(funs(mean(., na.rm = TRUE))) %>%
            mutate_each(funs(ifelse(is.nan(.), NA, .)))
df <- as.data.frame(df)
ivar <- colnames(df)[!(colnames(df) %in% c("ccode", "latent"))]
form <- as.formula(paste0("latent ~ ", paste0(ivar, collapse = " + ")))
ntree <- 5000
mtry <- 5
fit <- cforest(form, df, controls = cforest_unbiased(mtry = mtry, ntree = ntree))

pred <- var_est(fit, df)
cl <- qnorm(.025, lower.tail = FALSE)
se <- sqrt(pred$variance)
pred$low <- pred$latent - cl * se
pred$high <- pred$latent + cl * se
pred$truth <- df$latent
pred$name <- countrycode(df$ccode, "cown", "country.name")
mse <- mean((pred$latent - pred$truth)^2)
mae <- mean(abs(pred$latent - pred$truth))
perf <- paste0("MSE = ", round(mse, 2), "\nMAE = ", round(mae, 2))
out <- pred[abs(pred$latent - pred$truth) > sd(pred$truth), c(1,3:6)]
row.names(out) <- out$name
out$name <- NULL
xtable(out, digits = 3)

plot_pred(pred$latent, pred$truth, pred$variance,
          outlier_idx = which(pred$name %in% row.names(out)), labs = pred$name,
          xlab = "Latent Mean by Country (over time)", ylab = "Predicted Country Mean",
          title = "Mean Country Levels versus Predicted Country Levels") +
    annotate("text", 3.5, -1, label = perf)
ggsave("figures/latent_pred.png", width = 10, height = 6)

imp <- variable_importance(fit)
labels <- c("INGOs", "Executive Compet.", "Executive Open.",
            "Executive Const.", "Judicial Indep.", "log Population", "log GDP per cap.",
            "Oil Rents", "Military Regime", "Left Executive", "Trade/GDP", "FDI",
            "Public Trial", "Fair Trial", "Court Decision Final", "Legislative Approval",
            "IMF Structural Adj.", "WB Structural Adj.",
            "British Colony", "Common Law", "PTA w/ HR Clause", "CAT Ratifier",
            "CCPR Ratifier", "Youth Bulge", "Ter. Revison.", "Rule of Law", "CIM", "CIE",
            "HR Sanctions", "Non-HR Sanctions")
plot_imp(imp, "descending", labels, ylab = "Permutation Importance", xlab = "")
ggsave("figures/latent_imp.png", width = 10, height = 6)

top <- ivar[ivar %in% imp$labels[order(imp$value, decreasing = TRUE)][1:12]]
pd <- partial_dependence(fit, var = top, interaction = FALSE, ci = TRUE, parallel = TRUE)
pd$labels <- labels[match(pd$variable, imp$labels)]
plot_pd(pd, facet_var = "labels", ylab = "Latent Respect for Physical Integrity Rights (Country Mean)",
        title = "Partial Dependence of Top Variables")
ggsave("figures/latent_pd.png", width = 10, height = 8)

prox <- extract_proximity(fit)
plot_prox(prox, scale = TRUE, size = 2.5, labels = countrycode(df$ccode, "cown", "country.name"),
          title = "Latent Country Similarity")
ggsave("figures/latent_prox.png", width = 8, height = 8)
