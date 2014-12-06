set.seed(1988)

library(party)
library(ggplot2)
library(reshape2)

n <- 200
x <- runif(n, -4, 4)
y <- sin(x)
df <- data.frame(x, y)

fit_tree <- ctree(y ~ x, df)
df$tree <- as.numeric(predict(fit_tree))

fit_forest <- cforest(y ~ x, df, control = cforest_unbiased(mtry = 1, ntree = 1000))
df$forest <- as.numeric(predict(fit_forest))
df <- melt(df, id.vars = c("x", "y"))

p <- ggplot(df, aes(x, y))
p <- p + facet_wrap( ~ variable)
p <- p + geom_point(alpha = .5)
p <- p + geom_line(aes(x, value), colour = "blue")
p <- p + theme_bw()
ggsave("figures/approximation_example.png", p, width = 8, height = 4)
