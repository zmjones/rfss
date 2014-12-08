rm(list = ls())
set.seed(1987)

pkgs <- c("dplyr", "reshape2", "grid", "parallel", "ggplot2",
         "scales", "edarf", "Amelia", "doParallel",
         "foreach", "iterators", "lars", "party", "e1071")
invisible(lapply(pkgs, library, character.only = TRUE, quietly = TRUE))

## set global variables
CORES <- 8
TREES <- 1000 ## number of trees in forest
MTRY <- 5 ## number of predictors selected at each node
WINDOW <- 6 ## number of years in the test set
POINTS <- 24 ## number of points to sample for partial dependence
SAMP <- 500 ## number of draws to take from latent outcome variable
MI_ITER <- 10 ## number of imputations

cl <- makeCluster(CORES)
registerDoParallel(cl)

## load data
## hro_shaming_lag, avmdia_lag, ainr_lag, aibr_lag
df <- read.table("data/eeesr.csv", TRUE, ",")[, c(1:3,5:8,14,16:28,31,33:38,40:47)]
colnames(df)[26:27] <- c("mean", "sd")
df <- df[!is.na(df$mean) & !is.na(df$sd), ]

ivar <- colnames(df)[!colnames(df) %in% c("ccode", "country", "mean", "sd")]
ivar.labels <- c("Year", "INGOs", "Executive Compet.", "Executive Open.",
                 "Executive Const.", "Participation Compet.", "Judicial Indep.",
                 "Population", "GDP per capita", "Oil Rents", "Military Regime",
                 "Left Executive", "log Trade/GDP", "FDI",
                 "Public Trial", "Fair Trial", "Court Decision Final", "Legislative Approval",
                 "IMF Structural Adj.", "WB Structural Adj.",
                 "Common Law", "CAT Ratifier",
                 "CCPR Ratifier", "Youth Bulge", "Ter. Revison.", "CIM", "CIE",
                 "US Sanction (lag)", "UN Sanction (lag)", "HR Sanctions",
                 "Non-HR Sanctions", "Civil War", "International War")
form <- as.formula(paste0("mean ~", paste0(ivar, collapse = "+")))

unbounded_ints <- which(colnames(df) %in% c("ccode", "year", "ingo_uia"))
bounds <- foreach(i = 1:ncol(df), .combine = "cbind") %do% {
    if (is.integer(df[, i]) & !(i %in% unbounded_ints))
        c("column" = i, "lower" = min(df[, i], na.rm = TRUE), "upper" = max(df[, i], na.rm = TRUE))
}
bounds <- t(bounds)

df_mi <- amelia(df, 5, p2s = 0, ts = "year", cs = "ccode", splinetime = 4,
               logs = c("gdppc", "pop", "rentspc"),
               noms = c("terrrev", "imfstruct", "structad"),
               ords = c("nonhrordinal", "hrordinal", "lagun", "lagus",
                   "legislative_ck", "final_decision", "fair_trial", "public_trial",
                   "injud", "parcomp", "xconst", "xropen", "xrcomp"),
               bounds = bounds)

split_data <- function(df) {
    train <- df[df$year < max(df$year) - WINDOW, ]
    test <- df[!(row.names(df) %in% row.names(train)), ]
    list("train" = train, "test" = test)
}

## split data into train and test sets and create model formula
df_split <- split_data(df)
df_mi_split <- lapply(df_mi$imputations, split_data)

predict_lars <- function(X, y, newX) {
    cv_res <- cv.lars(X, y, type = "lasso", mode = "fraction", plot = FALSE)
    opt_frac <- min(cv_res$cv) + sd(cv_res$cv)
    opt_frac <- cv_res$index[which(cv_res$cv < opt_frac)][[1]]
    lasso_path <- lars(X, y, type = "lasso")
    lasso_fit <- predict.lars(lasso_path, type = "coefficients", mode = "fraction", s = opt_frac)
    rbind(X, newX) %*% coef(lasso_fit)
}

get_rmse <- function(df, label) {
    sapply(seq(min(df$year), max(df$year)),
           function(year) loss(df[df$year == year, label], df[df$year == year, "mean"]))
}

## function to calculate rmse
loss <- function(yhat, y) {
    sqrt(mean((y - yhat)^2))
}

pred_combine <- function(...) {
    out <- do.call("cbind", list(...))
    apply(out, 1, mean)
}

df$ols <- foreach(d = df_mi_split, .combine = "pred_combine") %do% {
    train <- d[[1]]
    test <- d[[2]]
    fit <- lm(form, train)
    c(fitted(fit), predict(fit, newdata = test))
}

df$lar <- foreach(d = df_mi_split, .combine = "pred_combine") %do% {
    train <- d[[1]]
    test <- d[[2]]
    predict_lars(as.matrix(train[, ivar]), train$mean, as.matrix(test[, ivar]))
}

df$svm <- foreach(d = df_mi_split, .combine = "pred_combine") %do% {
    train <- d[[1]]
    test <- d[[2]]
    fit <- svm(train[, ivar], train$mean)
    c(fitted(fit), predict(fit, newdata = test[, ivar]))
}

rf <- cforest(form, df_split$train, controls = cforest_unbiased(mtry = MTRY, ntree = TREES))
df$rf <- as.numeric(predict(rf, newdata = df))

out <- data.frame("OLS (imputed)" = get_rmse(df, "ols"),
                  "LARS (imputed)" = get_rmse(df, "lar"),
                  "SVM (imputed)" = get_rmse(df, "svm"),
                  "Random Forest" = get_rmse(df, "rf"),
                  "year" = seq(min(df$year), max(test$year)), check.names = FALSE)
out <- melt(out, id.vars = "year")

p <- ggplot(out, aes(year, value, colour = variable))
p <- p + geom_point()
p <- p + geom_line()
p <- p + geom_vline(aes(xintercept = min(df_split$test$year)), linetype = "dotted")
p <- p + labs(x = "Year", y = "RMSE")
p <- p + scale_colour_brewer(name = "", type = "qual", palette = 2)
p <- p + theme_bw()
ggsave("figures/hr_pred.png", p, width = 12, height = 6)

fit <- cforest(form, df, controls = cforest_unbiased(mtry = MTRY, ntree = TREES))

imp <- varimp(fit)
imp <- data.frame("point" = imp)
imp$variable <- ivar.labels
imp$variable <- factor(imp$variable, levels = imp$variable[order(imp$point)])
p <- ggplot(imp, aes(variable, point))
p <- p + geom_bar(stat = "identity")
p <- p + scale_y_continuous(breaks = pretty_breaks())
p <- p + geom_hline(aes(yintercept = 0), linetype = "dashed")
p <- p + labs(y = "Mean Increase in MSE after Permutation")
p <- p + theme_bw()
p <- p + theme(plot.margin = unit(rep(.15, 4), "in"), axis.title.y = element_blank())
p <- p + coord_flip()
ggsave("figures/hr_imp.png", p, width = 6, height = 8)

pd <- foreach(x = ivar, .inorder = FALSE, .packages = c("party", "edarf"), .combine = "rbind") %dopar% {
    out <- partial_dependence(fit, df, x, POINTS, TRUE, FALSE)
    colnames(out)[1] <- "rng"
    out$x <- x
    out$labels <- ivar.labels[match(x, ivar)]
    out$pred <- as.numeric(out$pred)
    out$rng <- as.numeric(out$rng)
    row.names(out) <- NULL
    out
}
save(pd, file = "rep/hr_pd.RData")

log_vars <- c("pop", "gdppc", "rentspc")
fixes <- pd %>%
    filter(x %in% log_vars) %>%
    mutate(rng = log(rng), labels = paste("log", labels))
pd <- rbind(pd %>% filter(!(x %in% log_vars)), fixes)

vars <- c("ythblgap", "xrcomp", "parcomp", "pop", "ingo_uia", "CIE")
pd_main <- pd %>% filter(x %in% vars)
pd_appendix <- pd %>% filter(!(x %in% vars))
p <- ggplot(pd_main, aes(rng, pred))
p <- p + facet_wrap(~ labels, ncol = 3, scales = "free")
p <- p + geom_point()
p <- p + geom_line()
p <- p + scale_y_continuous(breaks = pretty_breaks(n = 7))
p <- p + labs(x = "Predictor Scale",
              y = "Latent Respect for Physical Integrity Rights")
p <- p + theme_bw()
ggsave("figures/hr_pd.png", p, width = 10, height = 6)

## plot all two-way partial dependencies for the appendix
p <- ggplot(pd_appendix, aes(rng, pred))
p <- p + facet_wrap(~ labels, ncol = 4, scales = "free")
p <- p + geom_point()
p <- p + geom_line()
p <- p + scale_x_continuous(breaks = pretty_breaks())
p <- p + labs(x = "Predictor Scale",
              y = "Latent Respect for Physical Integrity Rights")
p <- p + theme_bw()
ggsave("figures/hr_pd_all.png", p, width = 10, height = 12)
