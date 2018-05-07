fixed_parms <- data.frame(device=character(),
                          xfactor=numeric(), xfactor_e=numeric(),
                          rho_id=numeric(), rho_id_e=numeric())

soekris <- read.table(header=T, text="
  MCS TXP rho_tx rho_tx_e rho_rx rho_rx_e
  6 6 0.52 3.1 0.16 8
  6 9 0.57 2.1 0.16 8
  6 12 0.70 1.7 0.16 8
  6 15 0.86 2.2 0.16 8
  12 6 0.55 4.6 0.27 5.6
  12 9 0.59 1.8 0.27 5.6
  12 12 0.73 2.2 0.27 5.6
  12 15 0.89 2.3 0.27 5.6
  24 6 0.81 5.3 0.6 11
  24 9 0.88 2.3 0.6 11
  24 12 1.02 2.8 0.6 11
  24 15 1.17 2.5 0.6 11
  48 6 1.2 1.6 1.14 3.5
  48 9 1.24 2.7 1.14 3.5
  48 12 1.37 3.1 1.14 3.5
  48 15 1.58 3.3 1.14 3.5
")
soekris$device <- "Soekris"
new <- as.data.frame(list("Soekris", 0.93, 1.2, 3.56, 0.6))
names(new) <- names(fixed_parms)
fixed_parms <- rbind(fixed_parms, new)

# errores en porcentajes, hay que convertir
soekris$rho_tx_e <- soekris$rho_tx * soekris$rho_tx_e/100
soekris$rho_rx_e <- soekris$rho_rx * soekris$rho_rx_e/100

linksys <- read.table(header=T, text="
  MCS TXP rho_tx rho_tx_e rho_rx rho_rx_e
  6 6 0.70 1.1 0.19 5.3
  6 9 0.77 1.4 0.19 5.3
  6 12 0.84 1.2 0.19 5.3
  6 15 0.97 0.9 0.19 5.3
  12 6 0.72 2.2 0.29 3.4
  12 9 0.81 2.6 0.29 3.4
  12 12 0.85 1.5 0.29 3.4
  12 15 1.0 1.5 0.29 3.4
  24 6 0.75 2.0 0.53 2.3
  24 9 0.84 2.3 0.53 2.3
  24 12 0.92 2.4 0.53 2.3
  24 15 1.04 2.1 0.53 2.3
  48 6 0.81 3.7 0.74 4.4
  48 9 0.88 3.4 0.74 4.4
  48 12 0.99 4.0 0.74 4.4
  48 15 1.08 3.7 0.74 4.4
")
linksys$device <- "Linksys"
new <- as.data.frame(list("Linksys", 0.46, 3.3, 2.73, 0.4))
names(new) <- names(fixed_parms)
fixed_parms <- rbind(fixed_parms, new)

linksys$rho_tx_e <- linksys$rho_tx * linksys$rho_tx_e/100
linksys$rho_rx_e <- linksys$rho_rx * linksys$rho_rx_e/100

HTC_Legend <- read.table(header=T, text="
  MCS TXP rho_tx rho_tx_e rho_rx rho_rx_e
  6 6 412.65 3.6 52.02 19.6
  6 9 422.26 2.8 52.02 19.6
  6 12 468.26 2.1 52.02 19.6
  6 15 500.98 2.2 52.02 19.6
  12 6 456.60 4.2 96.54 10.8
  12 9 471.50 5.9 96.54 10.8
  12 12 519.60 6.0 96.54 10.8
  12 15 570.78 2.1 96.54 10.8
  24 6 534.40 2.4 155.97 13.4
  24 9 541.62 3.0 155.97 13.4
  24 12 559.96 2.2 155.97 13.4
  24 15 603.03 2.1 155.97 13.4
  48 6 665.35 4.0 325.08 11.3
  48 9 673.64 4.2 325.08 11.3
  48 12 682.50 4.4 325.08 11.3
  48 15 695.37 4.6 325.08 11.3
")
HTC_Legend$device <- "HTC Legend"
HTC_Legend$rho_tx <- HTC_Legend$rho_tx/1000
HTC_Legend$rho_rx <- HTC_Legend$rho_rx/1000
new <- as.data.frame(list("HTC Legend", 0.1295, 8.7, 635.27/1000, 1.6))
names(new) <- names(fixed_parms)
fixed_parms <- rbind(fixed_parms, new)

HTC_Legend$rho_tx_e <- HTC_Legend$rho_tx * HTC_Legend$rho_tx_e/100
HTC_Legend$rho_rx_e <- HTC_Legend$rho_rx * HTC_Legend$rho_rx_e/100

samsung_note <- read.table(header=T, text="
  MCS TXP rho_tx rho_tx_e rho_rx rho_rx_e
  6 6 605.15 1.0 54.08 12.0
  6 9 616.22 1.1 54.08 12.0
  6 12 626.49 1.5 54.08 12.0
  6 15 643.94 1.2 54.08 12.0
  12 6 609.73 1.5 58.20 11.5
  12 9 617.39 1.5 58.20 11.5
  12 12 630.65 1.6 58.20 11.5
  12 15 653.71 1.7 58.20 11.5
  24 6 637.82 2.2 82.35 6.6
  24 9 639.26 2.2 82.35 6.6
  24 12 641.54 1.6 82.35 6.6
  24 15 674.27 1.8 82.35 6.6
  48 6 677.06 3.4 124.19 13.3
  48 9 679.23 3.4 124.19 13.3
  48 12 698.42 3.0 124.19 13.3
  48 15 708.58 4.3 124.19 13.3
")
samsung_note$device <- "Samsung Galaxy Note"
samsung_note$rho_tx <- samsung_note$rho_tx/1000
samsung_note$rho_rx <- samsung_note$rho_rx/1000
new <- as.data.frame(list("Samsung Galaxy Note", 0.088, 4.4, 591.59/1000, 0.3))
names(new) <- names(fixed_parms)
fixed_parms <- rbind(fixed_parms, new)

samsung_note$rho_tx_e <- samsung_note$rho_tx * samsung_note$rho_tx_e/100
samsung_note$rho_rx_e <- samsung_note$rho_rx * samsung_note$rho_rx_e/100

raspberrypi <- read.table(header=T, text="
  MCS TXP rho_tx rho_tx_e rho_rx rho_rx_e
  6 6 593.6 0.45 5.1 35.3
  6 9 627.7 0.37 5.1 35.3
  6 12 687.8 0.70 5.1 35.3
  6 15 692.2 1.85 5.1 35.3
  12 6 583.3 0.82 6.5 23.6
  12 9 611.8 1.37 6.5 23.6
  12 12 674.6 0.84 6.5 23.6
  12 15 716.3 0.85 6.5 23.6
  24 6 565.2 0.96 31.6 23.7
  24 9 587.5 1.28 31.6 23.7
  24 12 653.82 1.17 31.6 23.7
  24 15 748.8 3.7 31.6 23.7
  48 6 599.7 0.84 63.4 8.06
  48 9 621.9 2.14 63.4 8.06
  48 12 693.7 1.56 63.4 8.06
  48 15 806.6 2.56 63.4 8.06
")
raspberrypi$device <- "Raspberry Pi"
raspberrypi$rho_tx <- raspberrypi$rho_tx/1000
raspberrypi$rho_rx <- raspberrypi$rho_rx/1000
new <- as.data.frame(list("Raspberry Pi", 0.126, 3.34, 2220.3/1000, 0.13))
names(new) <- names(fixed_parms)
fixed_parms <- rbind(fixed_parms, new)

raspberrypi$rho_tx_e <- raspberrypi$rho_tx * raspberrypi$rho_tx_e/100
raspberrypi$rho_rx_e <- raspberrypi$rho_rx * raspberrypi$rho_rx_e/100

fixed_parms$xfactor_e <- fixed_parms$xfactor * fixed_parms$xfactor_e/100
fixed_parms$rho_id_e <- fixed_parms$rho_id * fixed_parms$rho_id_e/100
