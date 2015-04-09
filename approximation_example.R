set.seed(1988)

library(party)
library(ggplot2)
library(reshape2)

n <- 200
x <- runif(n, -4, 4)
y <- sin(x) + rnorm(n, 0, 0.2)
df <- data.frame(x, y)
object <- party:::ctreedpp(y ~ x, df)

fit_tree <- ctree(y ~ x, df)
df$tree <- as.numeric(predict(fit_tree))

p <- ggplot(df, aes(x, y))
p <- p + geom_point(alpha = .5)
p <- p + geom_line(aes(x, tree), colour = "blue")
p <- p + theme_bw()
ggsave("figures/cart_approximation.png", p, width = 10, height = 8)

fit_forest <- cforest(y ~ x, df, control = cforest_unbiased(mtry = 1))
df <- sapply(fit_forest@ensemble, function(x)
    unlist(party:::R_getpredictions(x, party:::R_get_nodeID(x, object@inputs, 0))))
df <- as.data.frame(df[, sample(1:ncol(df), 25)])
df$obs <- 1:nrow(df)
df <- melt(df, id.vars = "obs")
df$x <- x
df$y <- y
df$forest <- as.numeric(predict(fit_forest))

p <- ggplot(df, aes(x, y, group = variable))
p <- p + geom_point()
p <- p + geom_line(aes(x, forest), colour = "red")
p <- p + geom_line(aes(x, value), alpha = .15, colour = "blue")
p <- p + theme_bw()
ggsave("figures/forest_approximation.png", p, width = 10, height = 8)
