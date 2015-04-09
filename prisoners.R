set.seed(1987)

library(party)
library(edarf) ## devel version
library(ggplot2)
library(gridExtra)
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

## fit classifiers
fit_cond_vote <- cforest(vote ~ ., df[df$registered == "registered", -skip[1]], controls = control)

## compute and plot feature importance
imp_cond_vote <- variable_importance(fit_cond_vote)
labels <- c("Ordinal Treatment", "Voted in 2008 Election", "Age on Election Day", 
            "Time Since Release (Years)", "Crime", "Days Served")
ylab <- "Permutation Importance"
plot_imp(imp_cond_vote, "descending", labels = labels, xlab = "", ylab = ylab, zero_line = TRUE)
ggsave("figures/imp_cond_vote.png", width = 10, height = 6)

## compute and plot bivariate partial dependence
vars <- colnames(df)[-c(skip, which(colnames(df) == "crime"))]
pd_cond_vote <- partial_dependence(fit_cond_vote, var = vars, type = "prob", ci = TRUE, parallel = TRUE)

## hacking edarf to fix this case
## we should handle this
pd_cond_vote$no.vote <- NULL
pd_cond_vote$vote <- as.numeric(as.character(pd_cond_vote$vote))
attr(pd_cond_vote, "prob") <- FALSE
pd_cond_vote$labels <- labels[match(pd_cond_vote$variable, imp_cond_vote$labels)]

plot_pd(pd_cond_vote, facet_var = "labels")
ggsave("figures/pd_cond_vote.png", width = 10, height = 8)

## compute interactions with treatment
pd_int_cond_vote <- partial_dependence(fit_cond_vote, var = c("treatment_ordered", "timesincerelease"),
                                       type = "prob", interaction = TRUE, parallel = TRUE)

## hacking edarf to fix this case
## we should handle this
pd_int_cond_vote$no.vote <- NULL
pd_int_cond_vote$vote <- as.numeric(as.character(pd_int_cond_vote$vote))
attr(pd_int_cond_vote, "prob") <- FALSE

## factor levels not being preserved this is a bug
pd_int_cond_vote$treatment_ordered <- factor(pd_int_cond_vote$treatment_ordered,
                                             labels = c("none", "assurance", "assurance expanded"))

xlab <- "Years Since Release"
plot_pd(pd_int_cond_vote, facet_var = "labels", xlab = xlab,
        ylab = "Predicted Probability of Voting Given Registration")
ggsave("figures/pd_int_cond_vote.png", width = 10, height = 5)

prox_cond_vote <- extract_proximity(fit_cond_vote)
pca_cond_vote <- prcomp(prox_cond_vote)

plot_prox(pca_cond_vote, alpha = .5,
          color = df$treatment_ordered[df$registered == "registered"],
          color_label = "Treatment",
          shape = df$v08[df$registered == "registered"],
          shape_label = "Voted in 2008",
          size = df$ageonelecday[df$registered == "registered"],
          size_label = "Age on Election Day") 
ggsave("figures/prox_cond_vote_top.png", width = 12, height = 7)
plot_prox(pca_cond_vote, alpha = .5,
          color = df$vote[df$registered == "registered"],
          olor_label = "Voted in 2012",
          shape = df$v08[df$registered == "registered"],
          shape_label = "Voted in 2008",
          size = df$ageonelecday[df$registered == "registered"],
          size_label = "Age on Election Day")
ggsave("figures/prox_cond_vote_bottom.png", width = 12, height = 7)

## compare pd to mg to glm fit
dfs <- df[df$registered == "registered", ]
pd <- partial_dependence(fit_cond_vote, var = "ageonelecday", cutoff = 20, type = "prob", empirical = FALSE)
pgrid <- data.frame("ageonelecday" = ivar_points(dfs, "ageonelecday", 20, FALSE),
                    "treatment_ordered" = names(which.max(table(dfs$treatment_ordered))),
                    "daysserved" = mean(dfs$daysserved),
                    "timesincerelease" = mean(dfs$timesincerelease),
                    "crime" = names(which.max(table(dfs$crime))), 
                    "v08" = names(which.max(table(dfs$v08))))
pgrid$treatment_ordered <- factor(pgrid$treatment_ordered, levels = levels(df$treatment_ordered))
pgrid$crime <- factor(pgrid$crime, levels = levels(df$crime))
pgrid$v08 <- factor(pgrid$v08, levels = levels(df$v08))

mg <- predict(fit_cond_vote, newdata = pgrid, type = "prob")
mg <- do.call("rbind", mg)[, 2]
plt <- data_frame("ageonelecday" = pd$ageonelecday,
                  "partial dependence" = pd$vote,
                  "marginal dependence" = as.numeric(mg))
plt <- gather(plt, method, value, -ageonelecday)
plt$value <- as.numeric(plt$value)
ggplot(plt, aes(ageonelecday, value, colour = method)) +
    geom_point() + geom_line() + theme_bw() +
        labs(x = "Age on Election Day", y = "Predicted Value")
ggsave("figures/pd_vesus_mg.png", width = 10, height = 5)
