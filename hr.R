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

plt <- df %>% group_by(year) %>% summarise(mean = mean(latent))
ggplot(plt, aes(year,  mean)) + geom_point() + geom_line()

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
ntree <- 1000
mtry <- 3
fit <- cforest(form, df, controls = cforest_unbiased(mtry = mtry, ntree = ntree))

pred <- var_est(fit, df)
cl <- qnorm(.025, lower.tail = FALSE)
se <- sqrt(pred$variance)
pred$low <- pred$latent - cl * se
pred$high <- pred$latent + cl * se
pred$truth <- df$latent
pred$name <- countrycode(df$ccode, "cown", "country.name")
pred$error <- factor(ifelse(pred$latent - pred$truth > 0,
                            "less respect than expected", "more respect than expected"))
mse <- mean((pred$latent - pred$truth)^2)
mae <- mean(abs(pred$latent - pred$truth))
perf <- paste0("MSE = ", round(mse, 2), "\nMAE = ", round(mae, 2))
out <- pred[abs(pred$latent - pred$truth) > sd(pred$truth), c(1,3:6)]
row.names(out) <- out$name
out$name <- NULL
xtable(out, digits = 3)

ggplot(pred, aes(truth, latent, ymax = Inf, ymin = -Inf)) + geom_point(position = "dodge") +
    geom_text(data = pred[abs(pred$latent - pred$truth) > sd(pred$truth), ],
              aes(truth, latent, label = name, colour = error),
              size = 3, hjust = 0, vjust = 0, position = "dodge") +
                  geom_errorbar(aes(ymin = low, y = latent, ymax = high), alpha = .25) +
                      geom_abline(aes(intercept = 0, slope = 1), colour = "blue") +
                          labs(x = "Latent Mean by Country (over time)", y = "Predicted Country Mean",
                               title = "Mean Country Levels versus Predicted Country Levels") +
                                   annotate("text", 3.5, -1, label = perf) +
                                       theme_bw() + theme(legend.position = "bottom")
ggsave("figures/latent_pred.png", width = 10, height = 6)

imp <- varimp(fit)
imp <- data.frame(imp, features = names(imp),
                  labels = c("INGOs", "Executive Compet.", "Executive Open.",
                 "Executive Const.", "Judicial Indep.", "log Population", "log GDP per cap.",
                 "Oil Rents", "Military Regime", "Left Executive", "Trade/GDP", "FDI",
                 "Public Trial", "Fair Trial", "Court Decision Final", "Legislative Approval",
                 "IMF Structural Adj.", "WB Structural Adj.",
                 "British Colony", "Common Law", "PTA w/ HR Clause", "CAT Ratifier",
                 "CCPR Ratifier", "Youth Bulge", "Ter. Revison.", "Rule of Law", "CIM", "CIE",
                 "HR Sanctions", "Non-HR Sanctions"))
imp$labels <- factor(imp$labels, levels = imp$labels[order(imp$imp)])

ggplot(imp, aes(labels, imp)) +
    geom_point() + theme_bw() +
        theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5)) +
            labs(y = "Permutation Importance", x = "Variables")
ggsave("figures/latent_imp.png", width = 10, height = 6)

top <- ivar[ivar %in% imp$features[order(imp$imp, decreasing = TRUE)][1:12]]
pd <- partial_dependence(fit, top, interaction = FALSE, ci = TRUE, parallel = TRUE)
attributes(pd)$interaction <- FALSE ## bug
pd$labels <- imp$labels[match(pd$variable, imp$features)]

ggplot(pd, aes(value, latent)) + geom_point() + geom_line() +
    geom_errorbar(aes(ymin = low, y = latent, ymax = high), alpha = .25) +
        facet_wrap(~ labels, scales = "free") +
            labs(x = "value", y = "country mean latent respect",
                 title = "Partial Dependence of Top Variables") + theme_bw()
ggsave("figures/latent_pd.png", width = 10, height = 8)

pca <- prcomp(proximity(fit), scale. = TRUE)
ggbiplot::ggbiplot(pca, obs.scale = 1, var.scale = 1, var.axes = FALSE,
                   labels = countrycode(df$ccode, "cown", "country.name"), varname.size = 2) +
    labs(title = "latent country similarity") + theme_bw()
ggsave("figures/latent_prox.png", width = 8, height = 8)
