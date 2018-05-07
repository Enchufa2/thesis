library(dplyr); library(ggplot2); theme_set(theme_bw()); library(plotly)

data <- rbind(
  read.csv("../data/processed_data_test_18.csv", header=T, sep=" ") %>% mutate(AP="AP: 10 dBm"),
  read.csv("../data/processed_data_test_29.csv", header=T, sep=" ") %>% mutate(AP="AP: 17 dBm"))
data$mode <- factor(data$rate, labels=seq(1, 8))

data_plot <- data %>% arrange(AP, mode) %>%
  mutate(Mbps = acc_bytes*8*1e-6/duration, MbpJ = acc_bytes*8*1e-6/acc_ener) %>%
  group_by(dbm) %>% mutate(goodput = max(Mbps)) %>% ungroup %>%
  group_by(goodput) %>% mutate(ymax = max(MbpJ)) %>% ungroup

data_plot$mode <- factor(data_plot$mode)

filt_18 <- c(rep(T, 4), rep(F, 17),
             rep(F, 21),
             rep(F, 21),
             F, rep(T, 4), rep(F, 16),
             F, F, rep(T, 4), rep(F, 15),
             rep(F, 4), rep(T, 7), F, T, rep(F, 8),
             rep(F, 11), rep(T, 7), rep(F, 3),
             rep(F, 13), T, F, rep(T, 5))

filt_29 <- c(rep(F, 21),
             rep(F, 21),
             T, T, T, rep(F, 18),
             rep(F, 21),
             T, T, F, rep(T, 4), rep(F, 14),
             rep(F, 5), rep(T, 4), rep(F, 12),
             rep(F, 7), rep(T, 5), rep(F, 8),
             rep(F, 10), rep(T, 8), rep(F, 3))

ggplot(subset(data_plot, c(filt_18, filt_29)), aes(dbm, MbpJ)) + facet_grid(AP~.)+
  geom_line(mapping=aes(linetype=mode, color=mode)) + geom_point() +
  labs(x="Transmission Power [dBm]", y="Energy efficiency [MbpJ]") +
  scale_linetype(drop=FALSE) + scale_color_discrete(drop=FALSE) +
  theme(legend.justification=c(1,0), legend.position=c(1,0), legend.box="horizontal", legend.background = element_rect(fill="transparent"))
#ggsave("../img/efficiency-txp-exp.eps", device=cairo_ps, width=6, height=9)
