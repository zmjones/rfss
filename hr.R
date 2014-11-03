rm(list = ls())
set.seed(1987)

pkgs <- c("randomForest", "dplyr", "reshape2", "grid",
          "parallel", "ggplot2", "scales", "edarf", "polywog",
          "doParallel", "foreach", "iterators", "lars", "e1071")
invisible(lapply(pkgs, library, character.only = TRUE, quietly = TRUE))

## set global variables
CORES <- 8
TREES <- 1000 ## number of trees in forest
MTRY <- 5 ## number of predictors selected at each node
WINDOW <- 6 ## number of years in the test set
POINTS <- 24 ## number of points to sample for partial dependence
SAMP <- 500 ## number of draws to take from latent outcome variable
MI_ITER <- 10 ## number of forests to use for imputation
MI_TREES <- 1000 ## number of trees in each forest for imputation

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

## impute the data multiple times using randomForest and average over the imputations
## treated imputed data as completed, missingness as uninformative
## df_mi <- rfImpute(df[, ivar], df[, "mean"], MI_ITER, MI_TREES)
## df_mi$sd <- df$sd
## df_mi$ccode <- df$ccode
## colnames(df_mi)[1] <- "mean"
## write.csv(df_mi, "data/hr_rep_mi.csv", row.names = FALSE)
df_mi <- read.csv("data/hr_rep_mi.csv")

## function to get rmse by year
get_rmse <- function(df, label) {
    sapply(seq(min(df$year), max(df$year)),
           function(year) loss(df[df$year == year, label], df[df$year == year, "latent"]))
}

## function to calculate rmse
loss <- function(yhat, y) {
    sqrt(mean((y - yhat)^2))
}

## split data into train and test sets and create model formula
train <- df_mi[df_mi$year < max(df_mi$year) - WINDOW, ]
test <- df_mi[!(row.names(df_mi) %in% row.names(train)), ]
form <- as.formula(paste0("latent ~", paste0(ivar, collapse = "+")))

## sample from the latent outcome variable
samp <- foreach(icount(SAMP)) %do% rnorm(nrow(df_mi), df_mi$mean, df_mi$sd)

## register cluster object
cl <- makeCluster(CORES)
registerDoParallel(cl)

predict_lars <- function(X, y, newX) {
    cv_res <- cv.lars(X, y, type = "lasso", mode = "fraction", plot = FALSE)
    opt_frac <- min(cv_res$cv) + sd(cv_res$cv)
    opt_frac <- cv_res$index[which(cv_res$cv < opt_frac)][[1]]
    lasso_path <- lars(X, y, type = "lasso")
    lasso_fit <- predict.lars(lasso_path, type = "coefficients", mode = "fraction", s = opt_frac)
    rbind(X, newX) %*% coef(lasso_fit)
}

rmse <- foreach(x = samp, .inorder = FALSE, .packages = c("randomForest", "lars")) %dopar% {
    df_mi$latent <- x
    train$latent <- x[1:nrow(train)]
    test$latent <- x[(nrow(train)+1):nrow(df_mi)]
    ols <- lm(form, train)
    ## gam <- polywog(form, train, degree = 2, family = "gaussian", nlambda = 100)
    rf <- randomForest(train[, ivar], train[, "latent"], test[, ivar], test[, "latent"],
                      mtry = MTRY, ntree = TREES, importance = FALSE, proximity = TRUE)
    df_mi$ols <- c(fitted(ols), predict(ols, newdata = test))
    df_mi$rf <- c(rf$predicted, rf$test$predicted)
    ## df_mi$gam <- predict(gam, newdata = df_mi)
    df_mi$lars <- predict_lars(as.matrix(train[, ivar]), train[, "latent"], as.matrix(test[, ivar]))
    data.frame("ols" = get_rmse(df_mi, "ols"),
               "rf" = get_rmse(df_mi, "rf"),
               "lars" = get_rmse(df_mi, "lars"),
               ## "gam" = get_rmse(df_mi, "gam"),
               "year" = seq(min(train$year), max(test$year)))
}
save(rmse, file = "rep/hr_rmse.RData")

## summarize rmse by model and year
rmse <- do.call("rbind", rmse) %>%
        melt(id.vars = "year") %>%
        group_by(year, variable) %>%
        summarise("lower" = quantile(value, .025),
                  "mean" = mean(value),
                  "upper" = quantile(value, .975))

## create plots
p <- ggplot(rmse, aes(year, mean, colour = variable))
p <- p + geom_point()
p <- p + geom_errorbar(aes(ymin = lower, y = mean, ymax = upper), width = 0, size = .5)
p <- p + geom_vline(aes(xintercept = min(test$year)), linetype = "dotted")
p <- p + labs(x = "Year", y = "RMSE")
p <- p + scale_colour_brewer(name = "model", type = "qual", palette = 2)
p <- p + theme_bw()
ggsave("figures/hr_pred.png", p, width = 12, height = 6)

fit <- foreach(y = samp, .inorder = FALSE, .packages = "randomForest") %dopar% {
    randomForest(df_mi[, ivar], y, ntree = TREES, mtry = MTRY, importance = TRUE)
}

imp <- foreach(f = fit) %do% f$importance[, 1]
save(imp, file = "rep/hr_imp.RData")

## calculates partial dependence
## parallelizes inner or outer loop depending
## on whether the number of unique values of each predictor
pd <- foreach(f = fit) %do% {
    foreach(x = ivar, .inorder = FALSE,
            .packages = c("edarf", "randomForest")) %dopar% partial_dependence(f, df_mi, x, POINTS, TRUE)
}
save(pd, file = "rep/hr_pd.RData")

## summarise importance by predictor
imp <- do.call("rbind", imp)
imp <- apply(imp, 2, function(x) quantile(x, c(.025, .5, .975)))
imp <- as.data.frame(t(imp))
colnames(imp) <- c("lower", "median", "upper")
imp$variable <- ivar.labels
row.names(imp) <- NULL
imp$variable <- factor(imp$variable, levels = imp$variable[order(imp$median)])

## plot importance
p <- ggplot(imp, aes(variable, median))
p <- p + geom_point()
p <- p + scale_y_continuous(breaks = pretty_breaks())
p <- p + geom_errorbar(aes(y = median, ymax = upper, ymin = lower, width = .3))
p <- p + geom_hline(aes(yintercept = 0), linetype = "dashed")
p <- p + labs(y = "Mean Increase in MSE after Permutation")
p <- p + theme_bw()
p <- p + theme(plot.margin = unit(rep(.15, 4), "in"), axis.title.y = element_blank())
p <- p + coord_flip()
ggsave("figures/hr_imp.png", p, width = 6, height = 8)

## summarise partial dependence by predictor
pd <- lapply(pd, function(x) {
    x <- lapply(x, function(z) {
        z$x <- colnames(z)[1]
        colnames(z)[1] <- "rng"
        z
    })
    x <- as.data.frame(do.call(rbind, x))
    x$labels <- ivar.labels[match(x$x, ivar)]
    x$pred <- as.numeric(x$pred)
    x$rng <- as.numeric(x$rng)
    row.names(x) <- NULL
    x
})

pd <- do.call("rbind", pd)
log_vars <- c("pop", "gdppc", "rentspc")
fixes <- pd %>%
    filter(x %in% log_vars) %>%
    mutate(rng = log(rng), labels = paste("log", labels))
pd <- rbind(pd %>% filter(!(x %in% log_vars)), fixes)

## plot a subset of the two-way partial dependencies for the text
## top <- imp[order(imp$median, decreasing = TRUE), ] ## look at important predictors
vars <- c("ythblgap", "xrcomp", "parcomp", "pop", "ingo_uia", "CIE")
pd_main <- pd %>% filter(x %in% vars)
pd_appendix <- pd %>% filter(!(x %in% vars))
p <- ggplot(pd_main, aes(rng, pred))
p <- p + facet_wrap(~ labels, ncol = 3, scales = "free")
p <- p + geom_point(alpha = .05)
p <- p + scale_y_continuous(breaks = pretty_breaks(n = 7))
p <- p + labs(x = "Predictor Scale",
              y = "Latent Respect for Physical Integrity Rights")
p <- p + theme_bw()
ggsave("figures/hr_pd.png", p, width = 10, height = 6)

## plot all two-way partial dependencies for the appendix
p <- ggplot(pd_appendix, aes(rng, pred))
p <- p + facet_wrap(~ labels, ncol = 4, scales = "free")
p <- p + geom_point(alpha = .05)
p <- p + scale_x_continuous(breaks = pretty_breaks())
p <- p + labs(x = "Predictor Scale",
              y = "Latent Respect for Physical Integrity Rights")
p <- p + theme_bw()
ggsave("figures/hr_pd_all.png", p, width = 10, height = 12)
