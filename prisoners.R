set.seed(1987)

library(party)
library(edarf) ## devel version
library(ggplot2)
library(gridExtra)
## library(plotROC)
library(dplyr)
library(tidyr)
library(doParallel)

registerDoParallel(makeCluster(8))

## load and clean data
df <- read.csv("data/prisoner.csv")
drop <- c("treat1", "treat2_felon", "treat_combined", "f_contype",
          "f_daysserved", "v_pres_general_12", "returntoprison", "returned")
df <- df %>% mutate(treatment_ordered = factor(treatment_ordered,
                        labels = c("none", "assurance", "assurance expanded")),
                    registered = factor(registered, labels = c("not registered", "registered")),
                    vote = factor(v_pres_general_12, labels = c("no vote", "vote")),
                    v08 = factor(v08, labels = c("no", "yes")),
                    returned = factor(returned, labels = c("no", "yes")),
                    returntoprison = as.integer(returntoprison),
                    ageonelecday = as.numeric(ageonelecday),
                    crime = as.factor(tolower(f_contype)),
                    daysserved = as.numeric(f_daysserved),
                    timesincerelease = as.numeric(timesincerelease))
## drop observations where mailer was returned or where individual returned to prison
## before the election
df <- df %>% filter(returntoprison == 0, returned == "no") %>% select(-one_of(drop))

## fit random forests to each outcome
skip <- which(colnames(df) %in% c("vote", "registered"))
control <- cforest_unbiased(mtry = 2, ntree = 1000)

## skip observation weights for now
## weight_registered <- ifelse(df$registered == "registered", 2, 1)
## weight_vote <- ifelse(df$vote == "registered", 2, 1)

## fit classifiers
## fit_registered <- cforest(registered ~ ., df[, -skip[2]], controls = control)
## fit_vote <- cforest(vote ~ ., df[, -skip[1]], controls = control)
## fit_cond_vote <- cforest(vote ~ ., df[df$registered == "registered", -skip[1]], controls = control)

## force regression to get CI
df$registered <- ifelse(as.numeric(df$registered) == 1, 0, 1)
df$vote <- ifelse(as.numeric(df$vote) == 1, 0, 1)
fit_registered <- cforest(registered ~ ., df[, -skip[2]], controls = control)
fit_vote <- cforest(vote ~ ., df[, -skip[1]], controls = control)
fit_cond_vote <- cforest(vote ~ ., df[df$registered == 1, -skip[1]], controls = control)

## get oob class probabilities
## pred_registered <- predict(fit_registered, type = "prob", OOB = TRUE)
## pred_vote <- predict(fit_vote, type = "prob")
## pred_cond_vote <- predict(fit_vote, type = "prob", OOB = TRUE)
## pred_registered <- do.call("rbind", pred_registered)[, 1]
## pred_vote <- do.call("rbind", pred_vote)[, 1]
## pred_cond_vote <- do.call("rbind", pred_cond_vote)[, 1]

## calculate roc curves
## roc_registered <- calculate_roc(pred_registered, df$registered)
## roc_vote <- calculate_roc(pred_vote, df$vote)
## roc_cond_vote <- calculate_roc(pred_cond_vote, df$vote[df$registered == "registered"])

## plot_journal_roc(ggroc(roc_registered))
## ggsave("figures/roc_registered.png", width = 6, height = 6)
## plot_journal_roc(ggroc(roc_vote))
## ggsave("figures/roc_vote.png", width = 6, height = 6)
## plot_journal_roc(ggroc(roc_cond_vote))
## ggsave("figures/roc_cond_vote.png", width = 6, height = 6)

## compute and plot feature importance
imp_registered <- variable_importance(fit_registered)
imp_vote <- variable_importance(fit_vote)
imp_cond_vote <- variable_importance(fit_cond_vote)
labels <- c("Ordinal Treatment", "Voted in 2008 Election", "Age on Election Day", 
            "Time Since Release (Years)", "Crime", "Days Served")
ylab <- "Permutation Importance"
plot_imp(imp_registered, "descending", labels = labels, xlab = "", ylab = ylab,
         title = "Permutation Importance of Predictors for Ex-Felon Voter Registration")
ggsave("figures/imp_registration.png", width = 10, height = 6)
plot_imp(imp_vote, "descending", labels = labels, xlab = "", ylab = ylab,
         title = "Permutation Importance of Predictors for Ex-Felon Voting")
ggsave("figures/imp_vote.png", width = 10, height = 6)
plot_imp(imp_cond_vote, "descending", labels = labels, xlab = "", ylab = ylab,
         title = "Permutation Importance of Predictors for Ex-Felon Voting Given Registration")
ggsave("figures/imp_cond_vote.png", width = 10, height = 6)

## compute and plot bivariate partial dependence
vars <- colnames(df)[-c(skip, which(colnames(df) == "crime"))]
pd_registered <- partial_dependence(fit_registered, var = vars, ci = TRUE, parallel = TRUE)
pd_vote <- partial_dependence(fit_vote, var = vars, ci = TRUE, parallel = TRUE)
pd_cond_vote <- partial_dependence(fit_cond_vote, var = vars, ci = TRUE, parallel = TRUE)

pd_registered$low <- ifelse(pd_registered$low < 0, 0, pd_registered$low)
pd_registered$high <- ifelse(pd_registered$high > 1, 1, pd_registered$high)
pd_vote$low <- ifelse(pd_vote$low < 0, 0, pd_vote$low)
pd_vote$high <- ifelse(pd_vote$high > 1, 1, pd_vote$high)
pd_cond_vote$low <- ifelse(pd_cond_vote$low < 0, 0, pd_cond_vote$low)
pd_cond_vote$high <- ifelse(pd_cond_vote$high > 1, 1, pd_cond_vote$high)

## hacking edarf to fix this case
## we should handle this
## pd_registered$not.registered <- NULL
## pd_vote$no.vote <- NULL
## pd_cond_vote$no.vote <- NULL

## pd_registered$registered <- as.numeric(as.character(pd_registered$registered))
## pd_vote$vote <- as.numeric(as.character(pd_vote$vote))
## pd_cond_vote$vote <- as.numeric(as.character(pd_cond_vote$vote))

## attr(pd_registered, "prob") <- FALSE
## attr(pd_vote, "prob") <- FALSE
## attr(pd_cond_vote, "prob") <- FALSE

pd_registered$labels <- labels[match(pd_registered$variable, imp_registered$labels)]
pd_vote$labels <- labels[match(pd_vote$variable, imp_vote$labels)]
pd_cond_vote$labels <- labels[match(pd_cond_vote$variable, imp_cond_vote$labels)]

plot_pd(pd_registered, facet_var = "labels",
        title = "Partial Dependence of Predictors on the Probability of Registration")
ggsave("figures/pd_registered.png", width = 10, height = 8)
plot_pd(pd_vote, facet_var = "labels",
        title = "Partial Dependence of Predictors on the Probability of Voting")
ggsave("figures/pd_vote.png", width = 10, height = 8)
plot_pd(pd_cond_vote, facet_var = "labels",
        title = "Partial Dependence of Predictors on the Probability of Voting Given Registration")
ggsave("figures/pd_cond_vote.png", width = 10, height = 8)

## compute interactions with treatment
pd_int_registered <- partial_dependence(fit_registered, var = c("treatment_ordered", "timesincerelease"),
                                        interaction = TRUE, parallel = TRUE, ci = TRUE)
pd_int_vote <- partial_dependence(fit_vote, var = c("treatment_ordered", "timesincerelease"),
                                  interaction = TRUE, parallel = TRUE, ci = TRUE)
pd_int_cond_vote <- partial_dependence(fit_cond_vote, var = c("treatment_ordered", "timesincerelease"),
                                       interaction = TRUE, parallel = TRUE, ci = TRUE)

pd_int_registered$low <- ifelse(pd_int_registered$low < 0, 0, pd_int_registered$low)
pd_int_registered$high <- ifelse(pd_int_registered$high > 1, 1, pd_int_registered$high)
pd_int_vote$low <- ifelse(pd_int_vote$low < 0, 0, pd_int_vote$low)
pd_int_vote$high <- ifelse(pd_int_vote$high > 1, 1, pd_int_vote$high)
pd_int_cond_vote$low <- ifelse(pd_int_cond_vote$low < 0, 0, pd_int_cond_vote$low)
pd_int_cond_vote$high <- ifelse(pd_int_cond_vote$high > 1, 1, pd_int_cond_vote$high)

## hacking edarf to fix this case
## we should handle this
## pd_int_registered$not.registered <- NULL
## pd_int_vote$no.vote <- NULL
## pd_int_cond_vote$no.vote <- NULL

## pd_int_registered$registered <- as.numeric(as.character(pd_int_registered$registered))
## pd_int_vote$vote <- as.numeric(as.character(pd_int_vote$vote))
## pd_int_cond_vote$vote <- as.numeric(as.character(pd_int_cond_vote$vote))

## attr(pd_int_registered, "prob") <- FALSE
## attr(pd_int_vote, "prob") <- FALSE
## attr(pd_int_cond_vote, "prob") <- FALSE

## factor levels not being preserved this is a bug
pd_int_registered$treatment_ordered <- factor(pd_int_registered$treatment_ordered,
                                              labels = c("none", "assurance", "assurance expanded"))
pd_int_vote$treatment_ordered <- factor(pd_int_vote$treatment_ordered,
                                        labels = c("none", "assurance", "assurance expanded"))
pd_int_cond_vote$treatment_ordered <- factor(pd_int_cond_vote$treatment_ordered,
                                             labels = c("none", "assurance", "assurance expanded"))

xlab <- "Years Since Release"
plot_pd(pd_int_registered, facet_var = "labels", xlab = xlab, ylab = "Predicted Probability of Registration")
ggsave("figures/pd_int_registered.png", width = 10, height = 5)
plot_pd(pd_int_vote, facet_var = "labels", xlab = xlab, ylab = "Predicted Probability of Voting")
ggsave("figures/pd_int_vote.png", width = 10, height = 5)
plot_pd(pd_int_cond_vote, facet_var = "labels", xlab = xlab,
        ylab = "Predicted Probability of Voting Given Registration")
ggsave("figures/pd_int_cond_vote.png", width = 10, height = 5)

prox_registered <- extract_proximity(fit_registered)
prox_vote <- extract_proximity(fit_vote)
prox_cond_vote <- extract_proximity(fit_cond_vote)

## subsample larger matrices to visual clarity
## class asymmetric subsampling
## idx <- which(df$registered == "registered" | df$vote == "vote")
## idx <- as.integer(c(idx, sample(row.names(df[-idx, ]), 500 - length(idx))))
## class symetric subsampling
idx <- sample(1:nrow(df), 500)
prox_registered <- prox_registered[idx, idx]
prox_vote <- prox_vote[idx, idx]

pca_registered <- prcomp(prox_registered)
pca_vote <- prcomp(prox_vote)
pca_cond_vote <- prcomp(prox_cond_vote)

df$vote <- factor(df$vote, labels = c("no vote", "vote"))
df$registered <- factor(df$registered, labels = c("not registered", "registered"))

p1 <- plot_prox(pca_registered, alpha = .95,
                color = df$treatment_ordered[idx],
                color_label = "Treatment",
                shape = df$v08[idx],
                shape_label = "Voted in 2008",
                size = df$ageonelecday[idx],
                size_label = "Age on Election Day",
                title = "Latent Similarity of Individuals on Predictors of Registration")
p2 <- plot_prox(pca_registered, alpha = .95,
                color = df$vote[idx],
                color_label = "Vote",
                shape = df$v08[idx],
                shape_label = "Voted in 2008",
                size = df$ageonelecday[idx],
                size_label = "Age on Election Day")
png("figures/prox_registered.png", width = 10, height = 15, units = "in", res = 300)
grid.arrange(p1, p2, ncol = 1)
dev.off()

p1 <- plot_prox(pca_vote, alpha = .95,
                color = df$treatment_ordered[idx],
                color_label = "Treatment",
                shape = df$v08[idx],
                shape_label = "Voted in 2008",
                size = df$ageonelecday[idx],
                size_label = "Age on Election Day",
                title = "Latent Similarity of Individuals on Predictors of Voting")
p2 <- plot_prox(pca_vote, alpha = .95,
                color = df$vote[idx],
                color_label = "Vote",
                shape = df$v08[idx],
                shape_label = "Voted in 2008",
                size = df$ageonelecday[idx],
                size_label = "Age on Election Day")
png("figures/prox_vote.png", width = 10, height = 15, units = "in", res = 300)
grid.arrange(p1, p2, ncol = 1)
dev.off()

p1 <- plot_prox(pca_cond_vote, alpha = .5,
                color = df$treatment_ordered[df$registered == 1],
                color_label = "Treatment",
                shape = df$v08[df$registered == 1],
                shape_label = "Voted in 2008",
                size = df$ageonelecday[df$registered == 1],
                size_label = "Age on Election Day",
                title = "Latent Similarity of Individuals on Predictors of Voting Given Registration")
p2 <- plot_prox(pca_cond_vote, alpha = .5,
                color = df$vote[df$registered == 1], c
                olor_label = "Voted in 2012",
                shape = df$v08[df$registered == 1],
                shape_label = "Voted in 2008",
                size = df$ageonelecday[df$registered == 1],
                size_label = "Age on Election Day")
png("figures/prox_cond_vote.png", width = 10, height = 15, units = "in", res = 300)
grid.arrange(p1, p2, ncol = 1)
dev.off()

## compare pd to mg to glm fit
dfs <- df[df$registered == "registered", ]
pd <- partial_dependence(fit_cond_vote, var = "ageonelecday", cutoff = 20, ci = FALSE, empirical = FALSE)
pgrid <- data.frame("ageonelecday" = ivar_points(dfs, "ageonelecday", 20, FALSE),
                    "treatment_ordered" = names(which.max(table(dfs$treatment_ordered))),
                    "daysserved" = mean(dfs$daysserved),
                    "timesincerelease" = mean(dfs$timesincerelease),
                    "crime" = names(which.max(table(dfs$crime))), 
                    "v08" = names(which.max(table(dfs$v08))))
pgrid$treatment_ordered <- factor(pgrid$treatment_ordered, levels = levels(df$treatment_ordered))
pgrid$crime <- factor(pgrid$crime, levels = levels(df$crime))
pgrid$v08 <- factor(pgrid$v08, levels = levels(df$v08))

mg <- predict(fit_cond_vote, newdata = pgrid)
plt <- data_frame("ageonelecday" = pd$ageonelecday,
                  "partial dependence" = pd$vote,
                  "marginal dependence" = as.numeric(mg))
plt <- gather(plt, method, value, -ageonelecday)
ggplot(plt, aes(ageonelecday, value, colour = method)) +
    geom_point() + geom_line() + theme_bw() +
        labs(x = "Age on Election Day", y = "Predicted Value")
ggsave("figures/pd_vesus_mg.png", width = 10, height = 5)


