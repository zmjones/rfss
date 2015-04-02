set.seed(1987)

library(party)
library(edarf) ## devel version
library(ggplot2)
library(gridExtra)
library(dplyr)
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
df <- df %>% filter(returntoprison == 0, returned == "no") %>% select(-one_of(drop))

## fit random forests to each outcome
skip <- which(colnames(df) %in% c("vote", "registered"))
control <- cforest_unbiased(mtry = 2, ntree = 500)
fit_registered <- cforest(registered ~ ., df[, -skip[2]], controls = control)
fit_vote <- cforest(vote ~ ., df[, -skip[1]], controls = control)
fit_cond_vote <- cforest(vote ~ ., df[df$registered == "registered", -skip[1]], controls = control)

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
pd_registered <- partial_dependence(fit_registered, var = vars, parallel = TRUE, type = "prob")
pd_vote <- partial_dependence(fit_vote, var = vars, parallel = TRUE, type = "prob")
pd_cond_vote <- partial_dependence(fit_cond_vote, var = vars, parallel = TRUE, type = "prob")

## hacking edarf to fix this case
## we should handle this
pd_registered$not.registered <- NULL
pd_vote$no.vote <- NULL
pd_cond_vote$no.vote <- NULL

pd_registered$registered <- as.numeric(as.character(pd_registered$registered))
pd_vote$vote <- as.numeric(as.character(pd_vote$vote))
pd_cond_vote$vote <- as.numeric(as.character(pd_cond_vote$vote))

attr(pd_registered, "prob") <- FALSE
attr(pd_vote, "prob") <- FALSE
attr(pd_cond_vote, "prob") <- FALSE

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
                                        interaction = TRUE, parallel = TRUE, type = "prob")
pd_int_vote <- partial_dependence(fit_vote, var = c("treatment_ordered", "timesincerelease"),
                                  interaction = TRUE, parallel = TRUE, type = "prob")
pd_int_cond_vote <- partial_dependence(fit_cond_vote, var = c("treatment_ordered", "timesincerelease"),
                                       interaction = TRUE, parallel = TRUE, type = "prob")

## hacking edarf to fix this case
## we should handle this
pd_int_registered$not.registered <- NULL
pd_int_vote$no.vote <- NULL
pd_int_cond_vote$no.vote <- NULL

pd_int_registered$registered <- as.numeric(as.character(pd_int_registered$registered))
pd_int_vote$vote <- as.numeric(as.character(pd_int_vote$vote))
pd_int_cond_vote$vote <- as.numeric(as.character(pd_int_cond_vote$vote))

attr(pd_int_registered, "prob") <- FALSE
attr(pd_int_vote, "prob") <- FALSE
attr(pd_int_cond_vote, "prob") <- FALSE

## factor levels not being preserved
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

pca_registered <- prcomp(prox_registered)
pca_vote <- prcomp(prox_vote)
pca_cond_vote <- prcomp(prox_cond_vote)

p1 <- plot_prox(pca_registered, alpha = .95,
                color = df$treatment_ordered, color_label = "Treatment",
                shape = df$v08, shape_label = "Voted in 2008",
                size = df$ageonelecday, size_label = "Age on Election Day",
                title = "Latent Similarity of Individuals on Predictors of Registration")
p2 <- plot_prox(pca_registered, alpha = .95,
                color = df$vote, color_label = "Vote",
                shape = df$v08, shape_label = "Voted in 2008",
                size = df$ageonelecday, size_label = "Age on Election Day")
png("figures/prox_registered.png", width = 10, height = 15, units = "in", res = 300)
grid.arrange(p1, p2, ncol = 1)
dev.off()

p1 <- plot_prox(pca_vote, alpha = .95,
                color = df$treatment_ordered, color_label = "Treatment",
                shape = df$v08, shape_label = "Voted in 2008",
                size = df$ageonelecday, size_label = "Age on Election Day",
                title = "Latent Similarity of Individuals on Predictors of Voting")
p2 <- plot_prox(pca_vote, alpha = .95,
                color = df$vote, color_label = "Vote",
                shape = df$v08, shape_label = "Voted in 2008",
                size = df$ageonelecday, size_label = "Age on Election Day")
png("figures/prox_vote.png", width = 10, height = 15, units = "in", res = 300)
grid.arrange(p1, p2, ncol = 1)
dev.off()

p1 <- plot_prox(pca_cond_vote, alpha = .5,
                color = df$treatment_ordered[df$registered == "registered"], color_label = "Treatment",
                shape = df$v08[df$registered == "registered"], shape_label = "Voted in 2008",
                size = df$ageonelecday[df$registered == "registered"], size_label = "Age on Election Day",
                title = "Latent Similarity of Individuals on Predictors of Voting Given Registration")
p2 <- plot_prox(pca_cond_vote, alpha = .5,
                color = df$vote[df$registered == "registered"], color_label = "Voted in 2012",
                shape = df$v08[df$registered == "registered"], shape_label = "Voted in 2008",
                size = df$ageonelecday[df$registered == "registered"], size_label = "Age on Election Day")
png("figures/prox_cond_vote.png", width = 10, height = 15, units = "in", res = 300)
grid.arrange(p1, p2, ncol = 1)
dev.off()
