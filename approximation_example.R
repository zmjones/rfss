set.seed(1988)

library(party)
library(ggplot2)
library(reshape2)

n <- 200
x <- runif(n, -4, 4)
y <- sin(x)
df <- data.frame(x, y)
object <- party:::ctreedpp(y ~ x, df)

fit_tree <- ctree(y ~ x, df)
df$tree <- as.numeric(predict(fit_tree))

fit_forest <- cforest(y ~ x, df, control = cforest_unbiased(mtry = 1))
df$forest <- as.numeric(predict(fit_forest))

df <- melt(df, id.vars = c("x", "y"))

p <- ggplot(df, aes(x, y))
p <- p + facet_wrap( ~ variable)
p <- p + geom_point(alpha = .5)
p <- p + geom_line(aes(x, value), colour = "blue")
p <- p + theme_bw()
ggsave("figures/approximation_example.png", p, width = 8, height = 4)

forest_pred <- sapply(fit_forest@ensemble, function(x)
    unlist(party:::R_getpredictions(x, party:::R_get_nodeID(x, object@inputs, 0))))
forest_pred <- as.data.frame(forest_pred[, sample(1:ncol(forest_pred), 25)])
colnames(forest_pred) <- paste0("p", 1:ncol(forest_pred))
forest_pred$obs <- 1:nrow(forest_pred)
forest_pred <- melt(forest_pred, id.vars = "obs")
forest_pred$x <- x
forest_pred$y <- y

p <- ggplot(forest_pred, aes(x, y, group = variable))
p <- p + geom_point()
p <- p + geom_line(aes(x, value), alpha = .25, colour = "blue")
p <- p + theme_bw()
ggsave("figures/forest_approximation.png", p, width = 8, height = 4)


