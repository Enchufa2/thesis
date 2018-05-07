modes <- read.table(header=T, text="
  mode modulation code_rate data_rate BpS M
                    1 BPSK 1/2 6 3 2
                    2 BPSK 3/4 9 4.5 2
                    3 QPSK 1/2 12 6 4
                    4 QPSK 3/4 18 9 4
                    5 16-QAM 1/2 24 12 16 
                    6 16-QAM 3/4 36 18 16
                    7 64-QAM 2/3 48 24 64
                    8 64-QAM 3/4 54 27 64
                    ")

conv <- data.frame(
  code_rate = as.factor(c("1/2", "2/3", "3/4")),
  d_free = c(10, 6, 5),
  a_d = I(list(c(36, 0, 211, 0, 1404, 0, 11633, 0, 77433, 0),
               c(1, 16, 48, 158, 642, 2435, 9174, 34701, 131533, 499312),
               c(8, 31, 160, 892, 4512, 23297, 120976, 624304, 3229885, 16721329)
  ))
)

tSlotTime <- 9
tSIFSTime <- 16
tDIFSTime <- 34
aCWmin <- 15
aCWmax <- 1023
tPLCPPreamble <- 16
tPLCP_SIG <- 4
tSymbol <- 4
n_max <- 7

# l = octets to be transmitted
# s = SNR
# m = transmission mode
# m' = mack = ack mode

mack <- function(m) {
  if (m >= 5) mack <- 5
  else if (m >= 3) mack <- 3
  else mack <- 1
  mack
}
BpS <- function(m) modes[m,]$BpS
Tdata <- function(l, m) tPLCPPreamble + tPLCP_SIG + ceiling((30.75 + l) / BpS(m)) * tSymbol
Tack <- function(m) tPLCPPreamble + tPLCP_SIG + ceiling(16.75 / BpS(mack(m))) * tSymbol
Tbkoff <- function(i) tSlotTime * min(2^(i-1) * (aCWmin + 1) - 1, aCWmax) / 2

# section 5.1 AWGN channel
Q <- function(x) pnorm(x, lower = FALSE)
PsqrtM <- function(M, S) 2 * (1 - 1/sqrt(M)) * Q(sqrt(3*S/(M-1)))
PM <- function(M, S) 1 - (1 - PsqrtM(M, S))^2
Pb <- function(m, s) {
  if (m > 2) PM(modes[m,]$M, 10^((s)/10)) / log(modes[m,]$M, 2)
  else Q(sqrt(2*10^((s)/10)))
}
Pd <- function(d, m, s) {
  if (d%%2)
    colSums(t(sapply(((d+1)/2):d, function(k) choose(d, k) * (Pb(m, s))^k * (1 - Pb(m, s))^(d-k))))
  else
    colSums(t(sapply((d/2+1):d, function(k) choose(d, k) * (Pb(m, s))^k * (1 - Pb(m, s))^(d-k)))) +
    choose(d, d/2) * (Pb(m, s))^(d/2) * (1 - Pb(m, s))^(d/2) / 2
}
ad <- function(m, i) subset(conv, code_rate==modes[m,]$code_rate)$a_d[[1]][i]
dfree <- function(m) subset(conv, code_rate==modes[m,]$code_rate)$d_free
Pu <- function(m, s) colSums(t(sapply(0:9, function(i) ad(m, i+1) * Pd(dfree(m)+i, m, s))))
Pe <- function(m, h, s) 1 - (1 - Pu(m, s))^(8*h)
Pedata <- function(l, s, m) 1 - (1 - Pe(1, 3, s)) * (1 - Pe(m, 30.75 + l, s))
Peack <- function(s, m) 1 - (1 - Pe(1, 3, s)) * (1 - Pe(mack(m), 16.75, s))

# section 4
library(matrixStats)
Psxmit <- function(l, s, m) (1 - Pedata(l, s, m)) * (1 - Peack(s, m))
Psucc <- function(l, s, m) 1 - (1 - Psxmit(l, s, m))^n_max
Pnsucc <- function(n, l, s, m) {
  Psxmit(l, s, m) * (1 - Psxmit(l, s, m))^(n-1) / Psucc(l, s, m)
}
Dwait <- function(l, s, m) {
  ret <- Pedata(l, s, m) / (1 - Psxmit(l, s, m)) * (tSIFSTime + Tack(m) + tSlotTime) +
    (1 - Pedata(l, s, m)) * Peack(s, m) / (1 - Psxmit(l, s, m)) *
    (tSIFSTime + Tack(m) + tSIFSTime + Tack(1) + tDIFSTime)
  ret[is.nan(ret)] <- 0
  ret
}
Dsucc <- function(l, s, m) {
  dwait <- Dwait(l, s, m)
  tdata <- Tdata(l, m)
  aux <- Tbkoff(1) + tdata + tSIFSTime + Tack(m) + tDIFSTime
  Pnsucc(1, l, s, m) * aux + colSums(t(sapply(2:n_max, function(n) Pnsucc(n, l, s, m) * 
                                                (colSums(t(sapply(2:n, function(i) dwait + Tbkoff(i) + tdata))) + aux)
  )))
}
Dfail <- function(l, s, m) {
  dwait <- Dwait(l, s, m)
  tdata <- Tdata(l, m)
  colSums(t(sapply(1:n_max, function(i) Tbkoff(i) + tdata + dwait)))
}
G <- function(l, s, m) Psucc(l, s, m) * l * 8 / ((1 - Psucc(l, s, m)) * Dfail(l, s, m) + Psucc(l, s, m) * Dsucc(l, s, m))
