source("devices.R")
source("goodput_model.R")

library(matlab)
library(dplyr)
library(tidyr)
library(broom)

tomW <- function(x) 10^(x/20)
todBm <- function(x) 20*log10(x)

devices <- rbind(soekris, linksys, HTC_Legend, samsung_note, raspberrypi) %>% arrange(device)
devices$device <- factor(devices$device)
devices$txp <- tomW(devices$TXP)

x <- linspace(tomW(6), tomW(15), 100)
data <- do.call(rbind, lapply(seq(1, 7, 2), function(m) {
  a <- data.frame(txp=x)
  a$MCS <- modes[m,]$data_rate
  a
}))

tx_formula <- formula(rho_tx ~ MCS + txp)
rx_formula <- formula(rho_rx ~ MCS)

devices_fit_tx <- devices %>% group_by(device) %>% do(model = lm(tx_formula, data=.)) %>% 
  do(cbind(data, data.frame(device=.$device, predict(.$model, newdata=data, interval="confidence"))))
devices_fit_rx <- devices %>% group_by(device) %>% do(model = lm(rx_formula, data=.)) %>% 
  do(cbind(data, data.frame(device=.$device, predict(.$model, newdata=data, interval="confidence"))))

fit_tx_glance <- devices %>% group_by(device) %>% do(glance(lm(tx_formula, data=.)))
fit_tx_tidy <- devices %>% group_by(device) %>% do(tidy(lm(tx_formula, data=.)))
fit_rx_glance <- devices %>% group_by(device) %>% do(glance(lm(rx_formula, data=.)))
fit_rx_tidy <- devices %>% group_by(device) %>% do(tidy(lm(rx_formula, data=.)))

######################################################################

set_device <- function(device, p) {
  device$txp <- tomW(device$TXP)
  fit_tx <- lm(tx_formula, device)
  fit_rx <- lm(rx_formula, device)
  
  # synthetic data
  data <- do.call(rbind, lapply(1:8, function(m) {
    a <- data.frame(TXP=p, txp=tomW(p))
    a$MCS <- modes[m,]$data_rate
    a
  }))
  data <- cbind(data, rho_tx = predict(fit_tx, newdata=data))
  data <- cbind(data, rho_rx = predict(fit_rx, newdata=data))
  data$device <- device$device[[1]]
  
  device <<- data
}
rho_tx <- function(m, p) subset(device, TXP==p & MCS==modes[m,]$data_rate)$rho_tx
rho_rx <- function(m, p) subset(device, TXP==p & MCS==modes[m,]$data_rate)$rho_rx
rho_id <- function() {
  dev <- device$device[[1]]
  subset(fixed_parms, device==dev)$rho_id
}
xfactor <- function() {
  dev <- device$device[[1]]
  subset(fixed_parms, device==dev)$xfactor
}

######################################################################

EDsucc <- function(l, s, m, p) {
  edwait <- Dwait(l, s, m) * rho_id()
  etdata <- Tdata(l, m) * rho_tx(m, p)
  aux <- Tbkoff(1) * rho_id() + etdata + tSIFSTime * rho_id() + Tack(m) * rho_rx(m, p) + tDIFSTime * rho_id()
  Pnsucc(1, l, s, m) * aux + colSums(t(sapply(2:n_max, function(n) 
    Pnsucc(n, l, s, m) * 
      (colSums(t(sapply(2:n, function(i) edwait + Tbkoff(i) * rho_id() + etdata))) + aux)
  )))
}
EDfail <- function(l, s, m, p) {
  edwait <- Dwait(l, s, m) * rho_id()
  etdata <- Tdata(l, m) * rho_tx(m, p)
  colSums(t(sapply(1:n_max, function(i) Tbkoff(i) * rho_id() + etdata + edwait)))
}
EG <- function(l, s, m, p, xfactor=0) Psucc(l, s, m) * l * 8 / (xfactor*1e3 + (1 - Psucc(l, s, m)) * EDfail(l, s, m, p) + Psucc(l, s, m) * EDsucc(l, s, m, p))
E <- function(l, s, m, p, xfactor=0) (xfactor*1e3 + (1 - Psucc(l, s, m)) * EDfail(l, s, m, p) + Psucc(l, s, m) * EDsucc(l, s, m, p))

######################################################################

library(parallel)

x <- linspace(1, 30, 1000)
l <- 1500
dataG <- do.call(rbind, mclapply(1:8, function(i) {
  a <- data.frame(SNR=x, goodput=G(l, x, i))
  a$mode <- as.character(i)
  a
}))
dataG <- subset(dataG, goodput<100)
dataG_max <- dataG %>% group_by(SNR) %>% filter(goodput == max(goodput)) %>% ungroup()

xinterceptsG <- dataG_max%>%group_by(mode)%>%summarise(x=max(SNR))
xinterceptsG$textx <- xinterceptsG$x - c(xinterceptsG$x[[1]], diff(xinterceptsG$x))/2

######################################################################

# ITU model for indoor attenuation
L <- 31*log10(18)+20*log10(5.2*10^3) - 28
N <- -85
p <- x + L + N
devs <- list(soekris, linksys, HTC_Legend, samsung_note, raspberrypi)

all <- do.call(rbind, mclapply(1:5, function(dev) {
  set_device(devs[[dev]], p)
  
  dataEG <- do.call(rbind, mclapply(1:8, function(i) {
    a <- data.frame(
      SNR = x, 
      MbpJ = EG(l, x, i, p, xfactor()), 
      MbpJ_noxfactor = EG(l, x, i, p, 0), 
      mJpf=E(l, x, i, p, xfactor())/1e3,
      mJpf_noxfactor=E(l, x, i, p, 0)/1e3
    )
    a$mode <- as.character(i)
    a
  }))
  dataEG <- subset(dataEG, MbpJ<100) # ¯\_(ツ)_/¯
  data <- left_join(dataG, dataEG)
  data$device <- devs[[dev]]$device[[1]]
  data
}))

all_filtered <- all %>% group_by(SNR, device) %>% filter(goodput == max(goodput)) %>% ungroup()
  
xintercepts <- all_filtered %>% group_by(mode) %>% summarise(x=max(goodput))
xintercepts$textx <- xintercepts$x - c(xintercepts$x[[1]], diff(xintercepts$x))/2

#library(rgl)
#with(all_filtered, plot3d(SNR, goodput, MbpJ, type="l"))

######################################################################

library(ggplot2); theme_set(theme_bw()); library(dplyr)

ggplot(devices, aes(todBm(txp), rho_tx, shape=factor(MCS), color=factor(MCS))) + facet_wrap(~ device, nrow=1) + 
  #geom_ribbon(aes(ymin=lwr, ymax=upr, linetype=NA), alpha = 0.2) + 
  geom_point() + guides(shape=guide_legend(ncol=2), linetype=guide_legend(ncol=2)) +
  geom_errorbar(aes(ymin=rho_tx-rho_tx_e, ymax=rho_tx+rho_tx_e), width=0.7) +
  geom_line(aes(y=fit, linetype=factor(MCS)), data=devices_fit_tx) +
  scale_shape(name = "Data rate [Mbps]", solid=F) + scale_linetype(name = "Data rate [Mbps]") + scale_color_discrete(name = "Data rate [Mbps]") +
  xlab("Transmission Power [dBm]") + ylab(expression(paste(rho[tx], " [W]"))) +
  theme(legend.justification=c(0,1), legend.position=c(0,1), legend.box="horizontal", legend.background = element_rect(fill="transparent"))
#ggsave("../img/rho_tx.eps", device=cairo_ps, width=12, height=3)

ggplot(devices, aes(MCS, rho_rx)) + facet_wrap(~ device, nrow=1) + 
  #geom_ribbon(aes(ymin=lwr, ymax=upr, linetype=NA), alpha = 0.2) + 
  geom_point() + 
  geom_errorbar(aes(ymin=rho_rx-rho_rx_e, ymax=rho_rx+rho_rx_e), width=2.7) +
  xlab("MCS [Mbps]") + ylab(expression(paste(rho[rx], " [W]"))) +
  geom_line(aes(y=fit), data=devices_fit_rx)
#ggsave("../img/rho_rx.eps", device=cairo_ps, width=12, height=3)

write.table(fit_tx_glance, "fit_tx_glance.dat")
write.table(fit_tx_tidy, "fit_tx_tidy.dat")
write.table(fit_rx_glance, "fit_rx_glance.dat")
write.table(fit_rx_tidy, "fit_rx_tidy.dat")

ggplot() + geom_line(data=dataG_max, aes(SNR, goodput, group=mode), size=1.5) + 
  geom_line(data=dataG, aes(SNR, goodput, group=mode), alpha=.6) + 
  geom_linerange(aes(x=xinterceptsG$x[1:7], ymax=Inf, ymin=(dataG_max%>%group_by(mode)%>%summarise(x=max(goodput)))$x[-8]), alpha=.4, linetype=2) +
  geom_text(data=xinterceptsG, aes(x=textx, y=32, label=mode), size=4) + 
  xlab("SNR [dB]") + ylab("Goodput [Mbps]") +
  annotate("text", x=28, y=32, label="= mode", size=4)
#ggsave("../img/goodput.eps", device=cairo_ps, width=6, height=5)

ggplot(all) + geom_line(aes(SNR, mJpf, linetype=mode, color=mode)) + facet_wrap(~device, nrow=1) +
  scale_y_log10() + annotation_logticks(sides="l") + guides(linetype=guide_legend(ncol=4)) +
  xlab("Transmission Power [dBm]") + ylab("Energy consumption [mJpf]") +
  theme(legend.justification=c(0,1), legend.position=c(0.04,1.07), legend.box="horizontal", legend.background = element_rect(fill="transparent"))
#ggsave("../img/consumption.eps", device=cairo_ps, width=12, height=3)

ggplot(all_filtered) + geom_line(aes(goodput, MbpJ, linetype=device, color=device, group=interaction(mode, device))) + 
  geom_vline(xintercept=xintercepts$x, alpha=.4, linetype=2) + 
  geom_text(data=xintercepts, aes(x=textx, y=34, label=mode), size=4) + 
  xlab("Optimal Goodput [Mbps]") + ylab("Energy Efficiency [MbpJ]") +
  annotate("text", x=1, y=34, label="mode = ", size=4) +
  theme(legend.justification=c(0,1), legend.position=c(0,0.95), legend.box="horizontal", legend.background = element_rect(fill="transparent"))
#ggsave("../img/efficiency-goodput.eps", device=cairo_ps, width=6, height=5)

ggplot(all_filtered %>% filter(device=="Raspberry Pi")) + 
  geom_line(aes(SNR, MbpJ, linetype=mode, color=mode)) + 
  xlab("Transmission Power [dBm]") + ylab("Energy Efficiency [MbpJ]") +
  theme(legend.justification=c(1,0), legend.position=c(1,0), legend.box="horizontal", legend.background = element_rect(fill="transparent"))
#ggsave("../img/efficiency-txp.eps", device=cairo_ps, width=6, height=4.7)

######################################################################

get_EG <- function(param, op) {
  dataEG <- do.call(rbind, mclapply(1:8, function(i) {
    a <- data.frame(
      SNR = x, 
      MbpJ = EG(l, x, i, p, xfactor())
    )
    a$mode <- as.character(i)
    a
  }))
  dataEG <- subset(dataEG, MbpJ<100) # ¯\_(ツ)_/¯
  dataEG$param <- param
  dataEG$op <- op
  left_join(dataG, dataEG)
}
fixed_parms_bkp = fixed_parms
data <- NULL

# xfactor
set_device(raspberrypi, p)
fixed_parms$xfactor <- fixed_parms$xfactor * 3
data <- rbind(data, get_EG("xfactor", "x3"))
fixed_parms = fixed_parms_bkp
fixed_parms$xfactor <- fixed_parms$xfactor / 3
data <- rbind(data, get_EG("xfactor", "/3"))

# rho_id
fixed_parms = fixed_parms_bkp
fixed_parms$rho_id <- fixed_parms$rho_id * 3
data <- rbind(data, get_EG("rho_id", "x3"))
fixed_parms = fixed_parms_bkp
fixed_parms$rho_id <- fixed_parms$rho_id / 3
data <- rbind(data, get_EG("rho_id", "/3"))

# rho_tx
fixed_parms = fixed_parms_bkp
device$rho_tx <- device$rho_tx * 3
data <- rbind(data, get_EG("rho_tx", "x3"))
set_device(raspberrypi, p)
device$rho_tx <- device$rho_tx / 3
data <- rbind(data, get_EG("rho_tx", "/3"))

data_filtered <- data %>% group_by(SNR, param, op) %>% filter(goodput == max(goodput)) %>% ungroup
device <- subset(all_filtered, device=="Raspberry Pi")[,1:4]
device$op <- "no scaling"
device$param <- "rho_id"
data_filtered <- rbind(data_filtered, device)
device$param <- "rho_tx"
data_filtered <- rbind(data_filtered, device)
device$param <- "xfactor"
data_filtered <- rbind(data_filtered, device)

ggplot(data_filtered) + geom_line(aes(goodput, MbpJ, linetype=op, color=op, group=interaction(mode, op))) +
  facet_wrap(~factor(param, labels=c("rho[id]", "rho[tx]", "gamma[xg]")), nrow=1, labeller=label_parsed) + 
  scale_linetype_manual(name = "param scaling", values = c("dotted", "solid", "dashed")) +
  scale_color_discrete(name = "param scaling") + 
  #geom_line(data=subset(all_filtered, device=="Raspberry Pi"), aes(goodput, MbpJ, group=mode)) +
  xlab("Optimal Goodput [Mbps]") + ylab("Energy Efficiency [MbpJ]") +
  theme(legend.justification=c(0,1), legend.position=c(0.67,1), legend.box="horizontal", legend.background = element_rect(fill="transparent"))
#ggsave("../img/param-scaling1.eps", device=cairo_ps, width=6, height=3)

diffs_orig <- left_join(device %>% group_by(mode) %>% filter(MbpJ == max(MbpJ)) %>% summarise(max=MbpJ),
                   device %>% group_by(mode) %>% filter(goodput == min(goodput)) %>% summarise(min=MbpJ)) %>%
              mutate(lag = max - lead(min))
diffs_orig$op <- "no scaling"

diffs <- left_join(data_filtered %>% group_by(param, op, mode) %>% filter(MbpJ == max(MbpJ)) %>% summarise(max=MbpJ),
                   data_filtered %>% group_by(param, op, mode) %>% filter(goodput == min(goodput)) %>% summarise(min=MbpJ)) %>%
         mutate(lag = max - lead(min))
diffs_orig$param <- "rho_id"
diffs <- rbind(diffs, diffs_orig)
diffs_orig$param <- "rho_tx"
diffs <- rbind(diffs, diffs_orig)
diffs_orig$param <- "xfactor"
diffs <- rbind(diffs, diffs_orig)

diffs_final <- diffs %>% na.omit %>% group_by(param, op) %>% mutate(mode = c("1to2", "2to3", "3to4", "4to5", "5to6", "6to7", "7to8")) %>% ungroup

ggplot(diffs_final, aes(op, lag, group=mode, color=mode, linetype=mode)) + geom_line() + geom_point() +
  facet_wrap(~factor(param, labels=c("rho[id]", "rho[tx]", "gamma[xg]")), nrow=1, labeller=label_parsed) + 
  ylab("Energy Efficiency Drop [MbpJ]") + guides(colour = guide_legend(override.aes = list(shape = NA))) +
  scale_color_discrete(name = "mode transition") + scale_linetype(name = "mode transition") +
  theme(legend.position="top", axis.title.x = element_blank(), panel.border=element_blank(), panel.grid.major.x=element_line(color="black"))
#ggsave("../img/param-scaling2.eps", device=cairo_ps, width=6, height=3)
