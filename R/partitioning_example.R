set.seed(3434349) ## Works only with this seed

library(ggplot2)
library(party)
library(stringr)

path <- unlist(str_split(getwd(), "/"))
dir_prefix <- ifelse(path[length(path)] == "R", "../", "./")

vote <- c(0, 0, rep(1, 18), rep(0, 20))
ideology <- c(rnorm(20, 3, .7), rnorm(15, 5, .7), rnorm(5, 3, .6))
age <- c(runif(35, 0, 70), runif(5, 70, 90))
dme <- data.frame(ideology, age, vote = as.factor(vote))
levels(dme$vote) <- c("Democrat", "Republican")

fit_cart <- ctree(vote ~ ideology + age, data = dme)
sp1 <- fit_cart@tree$psplit$splitpoint
sp2 <- fit_cart@tree$left$psplit$splitpoint

## Original Data
p <- ggplot(dme, aes(ideology, age, shape = vote))
p <- p + theme_bw() + xlim(min(ideology), max(ideology)) + ggtitle("Original Data")
p <- p + geom_point(size = 5) + scale_shape_manual(values=c("D", "R"))
ggsave(paste0(dir_prefix, "figures/o.png"), p, width = 20, height = 12, units = "cm")

## First Partition
dme2 <- dme
corr <- ifelse(((dme$ideology <= sp1 & dme$vote == "Republican") |
                    (dme$ideology >= sp1 & dme$vote == "Democrat")), 1, 0)
dme2$corr <- factor(corr)
levels(dme2$corr) <- c("Incorrect", "Correct")

p <- ggplot(dme2, aes(ideology, age, shape = vote, color = corr))
p <- p + scale_colour_manual(values = c("red", "darkgreen"))
p <- p + theme_bw() + xlim(min(ideology), max(ideology))
p <- p + ggtitle("First Partition")
p <- p + geom_vline(aes(xintercept = sp1))
p <- p + geom_point(size = 5) + scale_shape_manual(values=c("D", "R"))
ggsave(paste0(dir_prefix, "figures/p1.png"), p, width = 20, height = 12, units = "cm")

## Second Partition
dme3 <- dme
corr <- ifelse(((dme$ideology <= sp1 & dme$vote == "Republican" & dme$age <= sp2) |
                    (dme$ideology <= sp1 & dme$vote == "Democrat" & dme$age > sp2) |
                        (dme$ideology >= sp1 & dme$vote == "Democrat")),
               1, 0)
dme3$corr <- factor(corr)
levels(dme3$corr) <- c("Incorrect", "Correct")

p <- ggplot(dme3, aes(ideology, age, shape = vote, color = corr))
p <- p + scale_colour_manual(values = c("red", "darkgreen"))
p <- p + theme_bw() + xlim(min(ideology), max(ideology))
p <- p + ggtitle("Second Partition")
p <- p + geom_vline(aes(xintercept = sp1))
p <- p + geom_point(size = 5) + scale_shape_manual(values = c("D", "R"))
ggsave(paste0(dir_prefix, "figures/p2.png"), p, width = 20, height = 12, units = "cm")

png(paste0(dir_prefix, "figures/cart.png"), width = 20, height = 12, units = "cm", res = 300)
plot(fit_cart, inner_panel = node_inner(fit_cart, pval = FALSE),
     terminal_panel = node_barplot(fit_cart, beside = FALSE, id = FALSE))
dev.off()
