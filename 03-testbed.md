\addtocontents{toc}{\partseparator}

# (PART) Experimentation {-}

# A Comprehensive Energy Measurement Framework {#ch:03}

<span class="newthought">Energy measurements</span> are typically conducted in an *ad-hoc* manner, with hardware and software tools specifically designed for a particular use case, and thus for limited electrical specifications. In this thesis, we are interested in measuring from small hardware components, such as wireless interfaces, to *energy debugging* [@Pathak2011], which implies whole-device mesurements. At the same time, potential wireless devices range from wearables and smartphones to access points and laptop computers. As a result, a flexible and reusable energy measurement framework for wireless communications must be able to cover a wide spectrum of electrical specifications (current, voltage and power) without losing accuracy or precision.

The main specifications for our framework are the following:

- High-accuracy, high-precision; in the range of mW.
- Avoid losing information between sampling periods, with events (transmission and reception of wireless frames) that last tens of microseconds.
- Support for a wide range of devices, from low- to high-powered devices, while keeping accuracy and precision.
- Support for synchronous measurements of multiple devices under test (DUTs), for network-related energy measurements (e.g., protocol/algorithm testing, energy optimisation of a network as a whole) as well as *stacked* measurements (e.g., measuring different components of a device at the same time).

Based on the above, we fist describe the selected instrumentation. A brief discussion follows about how to handle measurements and their associated uncertainty. We develop a method for automatic propagation and representation of uncertainty within the R language [@R-base]. Then, a testbed for whole-device measurements is proposed and validated. Finally, a complementary setup for per-component measurements is described and demonstrated by characterising a wireless interface.

## Instrumentation

Although there are integrated solutions in the market, known as *power analysers*, these are expensive instruments mainly aimed at characterising AC power (e.g., power factor, harmonics). Instead, we are interested in (time varying) DC power, and breaking the problem into its constituent parts (i.e., power supply, signal adaptation and data acquisition) enables not only more flexibility, but a wider choice at lower prices.

The most power-hungry devices within the scope of this thesis are laptop computers. Most of these devices rarely surpass the barrier of 100 W^[For instance, typical Dell computers bring 65 or 90 W AC adapters with maximum voltages of 19.5 V.]. Therefore, we selected the Keithley 2304A DC Power Supply, which is optimised for testing battery-operated wireless communication devices^[Up to 100 W, 20 V, 5 A.] that undergo substantial load changes for very short time intervals. This power supply simulates a battery's response during a large load change by minimising the maximum drop in voltage and recovering to within 100 mV of the original voltage within 40 $\mu$s.

As the measurement device, we selected the National Instruments PCI-6289 card, a high-accuracy multifunction data acquisition (DAQ) device. It has 32 analogue inputs (16 differential or 32 single ended) with 7 input ranges optimised for 18-bit input accuracy, up to 625 kS/s single channel or 500 kS/s multi-channel (aggregate). The timing resolution is 50 ns with an accuracy of 50 ppm of sample rate.

Finally, the required signals (current and voltage) must be extracted and adapted to the DAQ's input specifications. A custom three-port circuit, specifically designed by our university's Technical Office in Electronics, converts the current signal to voltage, and adapts the voltage signal to the DAQ's input limits without loss of precision. Two distinct designs, with different input specifications, were built (see Appendix \@ref(measurement-circuitry-schematics) for further details).

(ref:circuit) Measurement circuit (simplified) devoted to extract and adapt the signals to the DAQ input requirements.

<div class="figure" style="text-align: center">
<img src="img/03/circuit.png" alt="(ref:circuit)" width="50%" />
<p class="caption">(\#fig:circuit)(ref:circuit)</p>
</div>

Figure \@ref(fig:circuit) shows a simplified scheme of this circuit. The voltage drop in a small and high-precision resistor is amplified to measure the current signal. At the same time, a resistive divider couples the voltage signal. Considering that the DAQ card has certain settling time, it can be modelled as a small capacity which acts as a low pass filter. Thus, two buffers (voltage followers) are placed before the DAQ card to decrease the output impedance of the circuit [@ni2014].

A small command-line tool^[Available at [https://github.com/Enchufa2/daq-acquire](https://github.com/Enchufa2/daq-acquire)] was developed to perform measurements on the DAQ card using the open-source Comedi^[[http://comedi.org](http://comedi.org)] drivers and libraries.

Regarding the kernel instrumentation, we take advantage of SystemTap^[[https://sourceware.org/systemtap]((https://sourceware.org/systemtap))], an open-source infrastructure around the Linux kernel that dramatically simplifies information gathering on a running Linux system (kernel, modules and applications). It provides a scripting language for writing instrumentation. A SystemTap script is parsed into C code, compiled into a kernel module and hot-plugged into a live running system.

## Measurement and Uncertainty Analysis

The International Vocabulary of Metrology (VIM) defines a *quantity* as follows [@VIM:2012]:

> *A property of a phenomenon, body, or substance, where the property has a magnitude that can be expressed as a number and a reference*.

\noindent where most typically the number is a *quantity value*, attributed to a *measurand* and experimentally obtained via some measurement procedure, and the reference is a *measurement unit*.

Additionally, any quantity value must accommodate some indication about the quality of the measurement, a quantifiable attribute known as *uncertainty* (also traditionally known as *error*). The Guide to the Expression of Uncertainty in Measurement (GUM) defines *uncertainty* as follows [@GUM:2008]:

\tolerance 0

> *A parameter, associated with the result of a measurement, that characterises the dispersion of the values that could reasonably be attributed to the measurand*.

\fussy

Uncertainty can be mainly classified into *standard uncertainty*, which is the result of a direct measurement (e.g., electrical voltage measured with a voltmeter, or current measured with a amperimeter), and *combined standard uncertainty*, which is the result of an indirect measurement (i.e., the standard uncertainty when the result is derived from a number of other quantities by the means of some mathematical relationship; e.g., electrical power as a product of voltage and current). Therefore, provided a set of quantities with known uncertainties, the process of obtaining the uncertainty of a derived measurement is called *propagation of uncertainty*.

<span class="newthought">Traditionally</span>, computational systems have treated these three components (quantity values, measurement units and uncertainty) separately. Data consisted of bare numbers, and mathematical operations applied to them solely. Units were just metadata, and error propagation was an unpleasant task requiring additional effort and complex operations. Nowadays though, many software libraries have formalised *quantity calculus* as method of including units within the scope of mathematical operations, thus preserving dimensional correctness and protecting us from computing nonsensical combinations of quantities. However, these libraries rarely integrate uncertainty handling and propagation [@Flatter:2018].

Within the R environment, the `units` package [@CRAN:units;@Pebesma:2016:units] defines a class for associating unit metadata to numeric vectors, which enables transparent quantity derivation, simplification and conversion. This approach is a very comfortable way of managing units with the added advantage of eliminating an entire class of potential programming mistakes. Unfortunately, neither `units` nor any other package address the integration of uncertainties into quantity calculus.

In the following, we discuss propagation and reporting of uncertainty, and we present a framework for associating uncertainty metadata to R vectors, matrices and arrays, thus providing transparent, lightweight and automated propagation of uncertainty. This implementation also enables ongoing developments for integrating units and uncertainty handling into a complete solution.

### Propagation of Uncertainty

There are two main methods for propagation of uncertainty: the *Taylor series method* (TSM) and the *Monte Carlo method* (MCM). The TSM, also called the *delta method*, is based on a Taylor expansion of the mathematical expression that produces the output variables. As for the MCM, it is able to deal with generalised input distributions and propagates the error by Monte Carlo simulation.

The TSM is a flexible method of propagation of uncertainty that can offer different degrees of approximation given different sets of assumptions. The most common and well-known form of TSM is a first-order TSM assuming normality, linearity and independence. In the following, we will provide a short description. A full derivation, discussion and examples can be found in @Arras:1998.

Mathematically, an indirect measurement is obtained as a function of $n$ direct or indirect measurements, $Y = f(X_1, ..., X_n)$, where the distribution of $X_n$ is unknown *a priori*. Usually, the sources of random variability are many, independent and probably unknown as well. Thus, the central limit theorem establishes that an addition of a sufficiently large number of random variables tends to a normal distribution. As a result, the *first assumption* states that $X_n$ are normally distributed.

(ref:propagation) Illustration of linearity in an interval $\pm$ one standard deviation around the mean.

<div class="figure" style="text-align: center">
<img src="03-testbed_files/figure-html/propagation-1.png" alt="(ref:propagation)" width="480" />
<p class="caption">(\#fig:propagation)(ref:propagation)</p>
</div>

The *second assumption* presumes linearity, i.e., that $f$ can be approximated by a first-order Taylor series expansion around $\mu_{X_n}$ (see Figure \@ref(fig:propagation)). Then, given a set of $n$ input variables $X$ and a set of $m$ output variables $Y$, the first-order *error propagation law* establishes that

\begin{equation}
  \Sigma_Y = J_X \Sigma_X J_X^T (\#eq:assumption2)
\end{equation}

where $\Sigma$ is the covariance matrix and $J$ is the Jacobian operator. 

\pagebreak Finally, the *third assumption* supposes independency among the uncertainty of the input variables. This means that the cross-covariances are considered to be zero, and the equation above can be simplified into the most well-known form of the first-order TSM: 

\begin{equation}
  \left(\Delta y\right)^2 = \sum_i \left(\frac{\partial f}{\partial x_i}\right)^2\cdot \left(\Delta x_i\right)^2 (\#eq:TSM)
\end{equation}

\SPACE
In practice, as recommended in the GUM, this first-order approximation is good even if $f$ is non-linear, provided that the non-linearity is negligible compared to the magnitude of the uncertainty, i.e., $\mathbb{E}[f(X)]\approx f(\mathbb{E}[X])$. Also, this weaker condition is distribution-free: no assumptions are needed on the probability density functions (PDF) of $X_n$, although they must be reasonably symmetric.

### Reporting Uncertainty

The GUM defines four ways of reporting standard uncertainty and combined standard uncertainty. For instance, if the reported quantity is assumed to be a mass $m_S$ of nominal value 100 g:

> 1. $m_S = 100.02147$ g with (a combined standard uncertainty) $u_c$ = 0.35 mg.
> 2. $m_S = 100.02147(35)$ g, where the number in parentheses is the numerical value of (the combined standard uncertainty) $u_c$ referred to the corresponding last digits of the quoted result.
> 3. $m_S = 100.02147(0.00035)$ g, where the number in parentheses is the numerical value of (the combined standard uncertainty) $u_c$ expressed in the unit of the quoted result.
> 4. $m_S = (100.02147 \pm 0.00035)$ g, where the number following the symbol $\pm$ is the numerical value of (the combined standard uncertainty) $u_c$ and not a confidence interval.

Schemes (2, 3) and (4) will be referred to as *parenthesis* notation and *plus-minus* notation respectively. Although (4) is a very extended notation, the GUM explicitly discourages its use to prevent confusion with confidence intervals. Throughout this document, we will be using (2) unless otherwise specified.

### Automated Uncertainty Handling in R: The `errors` Package

Following the approach of the `units` package, this thesis develops a framework for automatic propagation and reporting of uncertainty: the `errors` package [@R-errors]. This R package aims to provide easy and lightweight handling of measurements with errors, including propagation using the first-order TSM presented in the previous section and a formally sound representation. Errors, given as (combined) standard uncertainties, can be assigned to numeric vectors, matrices and arrays, and then all the mathematical and arithmetic operations are transparently applied to both the values and the associated errors. The following example sets a simple vector with a 5% of error:


```r
library(errors)

x <- 1:5
errors(x) <- x * 0.05
x
```

```
## Errors: 0.05 0.10 0.15 0.20 0.25
## [1] 1 2 3 4 5
```

The `errors()` function assigns or retrieves a vector of errors, which is stored as an attribute of the class `errors`. Internally, the package provides S3 methods^[See "Writing R Extensions" for further details: [https://cran.r-project.org/doc/manuals/r-release/R-exts.html](https://cran.r-project.org/doc/manuals/r-release/R-exts.html)] for the generics belonging to the groups `Math`, `Ops` and `Summary`, plus additional operations such as subsetting (`[`, `[<-`, `[[`, `[[<-`), concatenation (`c()`), differentiation (`diff`), row and column binding (`rbind`, `cbind`), or coercion to data frame and matrix.


```r
data.frame(x, 3*x, x^2, sin(x), cumsum(x))
```

```
##         x  X3...x    x.2   sin.x. cumsum.x.
## 1 1.00(5)  3.0(2) 1.0(1)  0.84(3)   1.00(5)
## 2  2.0(1)  6.0(3) 4.0(4)  0.91(4)    3.0(1)
## 3  3.0(2)  9.0(5) 9.0(9)   0.1(1)    6.0(2)
## 4  4.0(2) 12.0(6)  16(2)  -0.8(1)   10.0(3)
## 5  5.0(2) 15.0(8)  25(2) -0.96(7)   15.0(4)
```

It is worth noting that both values and errors are stored with all the digits. However, when a single measurement or a column of measurements in a data frame are printed, the output is properly formatted to show a single significant digit for the error. This is achieved by providing S3 methods for `format()` and `print()`. The *parenthesis* notation is used by default, but this can be overridden through the appropriate option in order to use the *plus-minus* notation instead.

## Whole-Device Measurements

Figure \@ref(fig:testbed) shows the proposed testbed for whole-device measurements. It comprises two laptop computers ---the DUT and an access point (AP)--- and a controller. The controller is a workstation with the DAQ card installed and it performs the energy measurements. At the same time, it sends commands to the DUT and AP through a wired connection and monitors the wireless connection between DUT and AP through a probe.

(ref:testbed) Testbed for whole-device energy measurements. The *custom circuit* is the one sketched in Figure \@ref(fig:circuit).

<div class="figure" style="text-align: center">
<img src="img/03/testbed.png" alt="(ref:testbed)" width="478" />
<p class="caption">(\#fig:testbed)(ref:testbed)</p>
</div>

<span class="newthought">The experimental methodology</span> to characterise the DUT's energy parameters is as follows. Given a collection of network parameter values (modulation coding scheme or MCS, transmission power, packet size, framerate), we run steady experiments for several seconds in order to gather averaged measures. Each experiment comprises the steps shown in Figure \@ref(fig:sequence).

(ref:sequence) Measurement methodology. Time sequence of a whole-device experiment.

<div class="figure" style="text-align: center">
<img src="img/03/sequence.png" alt="(ref:sequence)" width="50%" />
<p class="caption">(\#fig:sequence)(ref:sequence)</p>
</div>

1. AP and DUT are configured. The DUT connects to the wireless network created by the AP and checks the connectivity. Setting up this network in a clear channel is highly advisable to avoid interference. The  5 GHz band, with an 802.11a-capable card, has good candidates.
 2. The packet counters of the wireless interfaces are saved for later use.
 3. Receiver and transmitter are started. We use the `mgen`^[[http://cs.itd.nrl.navy.mil/work/mgen](http://cs.itd.nrl.navy.mil/work/mgen)] traffic generator and a simple `netcat` at the receiver.
 4. The controller monitors the wireless channel and collects an energy trace that will be averaged later.
 5. Transmitter and Receiver are stopped.
 6. Because of the unreliability of the wireless medium, the packet counters, together with the monitoring information, are used to ensure that the experiment was successful (i.e., the traffic seen agrees with the configured parameters).

### Validation

In order to validate our measurement framework, several experiments were performed with one of the devices studied in @Serrano2014 as DUT. We selected the Soekris net4826-48 equipped with an Atheros AR5414-based 802.11a/b/g Mini-PCI card because it is the one with the largest cross-factor. The operating system (OS) was Linux Voyage with kernel 2.6.30 and the MadWifi driver v0.9.4.

The first task was to perform the energy breakdown given in @Serrano2014 in transmission mode:

User space 
  ~ The Soekris generates packets using `mgen`, but they are discarded before being delivered to the OS, by using the `sink` device rather than `udp`.
  
Kernel space
  ~ Packets cross the network stack and are discarded in the driver, by commenting the `hardstart` MadWifi command that performs the actual delivery of the frame to the wireless network interface card (NIC).

Wireless NIC
  ~ Packets are transmitted, i.e., are delivered to the wireless medium.

The NoACK functionality from 802.11e was activated in order to avoid ACK receptions. Therefore, Equation \@ref(eq:new-energy-model) can be simplified as follows to describe complete transmissions:

\begin{equation*}
 \overline{P}(\tau, \lambda) = \rho_{id} + \rho_{tx}\tau + \gamma_{xg}\lambda
 (\#eq:validation1)
\end{equation*}

\SPACE
Figure \@ref(fig:validation1) represents the equation above (red lines) and depicts how the energy toll splits across the processing chain with different parameters (blue and green lines). The dashed line depicts the idle consumption as a reference, $\rho_{id}=3.65(1)$ W.

(ref:validation1) Power consumption breakdown vs. airtime.

(ref:validation2) Power consumption offset ($\tau=0$) vs. framerate.

<div class="figure" style="text-align: center">
<img src="03-testbed_files/figure-html/validation1-1.png" alt="(ref:validation1)" width="480" />
<p class="caption">(\#fig:validation1)(ref:validation1)</p>
</div>

<div class="figure" style="text-align: center">
<img src="03-testbed_files/figure-html/validation2-1.png" alt="(ref:validation2)" width="480" />
<p class="caption">(\#fig:validation2)(ref:validation2)</p>
</div>

Indeed, these results are quite similar to @Serrano2014 and confirm that the cross-factor accounts for the largest part of the energy consumption. Moreover, @Serrano2014 reports that the cross-factor is *almost* independent of the packet size. Interestingly, our results have captured a small dependence that can be especially observed in the 600 fps case.

Finally, we can derive the cross-factor value and compare it. Taking the offset of the red regression lines of Figure \@ref(fig:validation1), we can plot Figure \@ref(fig:validation2) and fit these points with $\tau=0$. This regression yields the values $\rho_{id}=3.72(4)$ W ($3.65(1)$ W measured) and $\gamma_{xg}=1.46(7)$ mJ, quite close to the values reported in @Serrano2014.

## Per-Component Measurements

Figure \@ref(fig:testbed-card) shows the proposed testbed for per-component measurements. The component (a wireless card) is attached to the device through a flexible x1 PCI Express to Mini PCI Express adapter from Amfeltec. This adapter connects the PCI bus' data channels to the host and provides an ATX port so that the wireless card can be supplied by an external power source.

(ref:testbed-card) Testbed for per-component energy measurements.

<div class="figure" style="text-align: center">
<img src="img/03/testbed-card.png" alt="(ref:testbed-card)" width="50%" />
<p class="caption">(\#fig:testbed-card)(ref:testbed-card)</p>
</div>

Here, the same PC holds the DAQ card. In this way, the operations sent to the wireless card and the energy measurements can be correlated using the same timebase, which is required for the next section. For other type of experiments, this requirement can be relaxed, and the DAQ card can be hosted in a separate machine.

### Characterisation of a COTS Device

##### State Consumption Parametrisation {-}

In the following, we demonstrate a complete state parametrisation (power consumption in transmission, reception, overhearing, idle and sleep) of a commercial off-the-shelf (COTS) card: an Atheros AR9280-based 802.11a/b/g/n Half Mini-PCI Express card. All measurements (except for the sleep state) were taken with the wireless card associated to the AP in 11a mode to avoid any interfering traffic, and it was placed very close to the node to obtain the best possible signal quality. The reception of beacons is accounted in the baseline consumption (idle). 

The card under test performed transmissions/receptions to/from the AP at a constant rate and with fixed packet length. In order to avoid artifacts from the reception/transission of ACKs, UDP was used and the NoACK policy was enabled. Packet overhearing was tested by generating traffic of the same characteristics from a secondary STA placed in the same close range ($\sim$cm). Under these conditions, several values of airtime percentage were swept. For each experiment, current and voltage signals were sampled at 100 kHz and the average power consumption was measured with a basic precision of 1 mW over intervals of 3 s.

\pagebreak Regarding the sleep state, the card's `ath9k` driver internally defines three states of operation: *awake*, *network sleep* and *full sleep*. A closer analysis reveals that the card is *awake*, or in *active state*, when it is operational (i.e., transmitting, receiving or in idle state, whether as part of an SSID or in monitor mode), and it is in *full sleep* state when it is not operational at all (i.e., interface down or up but not connected to any SSID). The *network sleep* state is used by the 802.11 Power Save (PS) mechanism, but essentially works in the same way as *full sleep*, that is, it turns off the main reference clock and switches to a secondary 32 kHz one. Therefore, we saw that *full sleep* and *network sleep* are the same state in terms of energy: they consume exactly the same power. The only difference is that *network sleep* sets up a tasklet to wake the interface periodically (to receive the traffic indication map), as required by the PS mode.

(ref:power) Atheros AR9280 power consumption in 11a mode.

<div class="figure" style="text-align: center">
<img src="03-testbed_files/figure-html/power-1.png" alt="(ref:power)" width="480" />
<p class="caption">(\#fig:power)(ref:power)</p>
</div>

Figure \@ref(fig:power) shows our results for transmission, reception and overhearing. Idle and sleep consumptions were measured independently, are depicted with gray horizontal lines for reference. As expected, power consumptions in transmission/reception/overhearing state are proportional to airtime, thus the power consumption of such operations can be easily estimated by extrapolating the regression line to the 100% of airtime (gray vertical line).

These average values are shown in Table \@ref(tab:powert). First of all, reception and overhearing consumptions are the same within the error, and they are close to idle consumption. Transmission power is more than two times larger than reception. Finally, the sleep state saves almost the 70% of the energy compared to idle/reception.

<table>
<caption>(\#tab:powert)Atheros AR9280 power consumption.</caption>
 <thead>
  <tr>
   <th style="text-align:right;"> State </th>
   <th style="text-align:center;"> Mode </th>
   <th style="text-align:center;"> Channel </th>
   <th style="text-align:center;"> MHz </th>
   <th style="text-align:left;"> Power [W] </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:right;"> Transmission </td>
   <td style="text-align:center;vertical-align: middle !important;" rowspan="4"> 11a </td>
   <td style="text-align:center;vertical-align: middle !important;" rowspan="4"> 44 </td>
   <td style="text-align:center;vertical-align: middle !important;" rowspan="4"> 20 </td>
   <td style="text-align:left;"> 3.10(2) </td>
  </tr>
  <tr>
   <td style="text-align:right;"> Reception </td>
   
   
   
   <td style="text-align:left;"> 1.373(1) </td>
  </tr>
  <tr>
   <td style="text-align:right;"> Overhearing </td>
   
   
   
   <td style="text-align:left;"> 1.371(1) </td>
  </tr>
  <tr>
   <td style="text-align:right;"> Idle </td>
   
   
   
   <td style="text-align:left;"> 1.292(2) </td>
  </tr>
  <tr>
   <td style="text-align:right;"> Sleep </td>
   <td style="text-align:center;"> - </td>
   <td style="text-align:center;"> - </td>
   <td style="text-align:center;"> - </td>
   <td style="text-align:left;"> 0.424(2) </td>
  </tr>
  <tr>
   <td style="text-align:right;vertical-align: middle !important;" rowspan="2"> Idle </td>
   <td style="text-align:center;vertical-align: middle !important;" rowspan="2"> 11n </td>
   <td style="text-align:center;vertical-align: middle !important;" rowspan="2"> 11 </td>
   <td style="text-align:center;"> 20 </td>
   <td style="text-align:left;"> 1.137(4) </td>
  </tr>
  <tr>
   
   
   
   <td style="text-align:center;"> 40 </td>
   <td style="text-align:left;"> 1.360(4) </td>
  </tr>
</tbody>
</table>

##### Downclocking Consumption Characterisation {-}

As the AR9280's documentation states, its reference clock runs at 44 MHz for 20 MHz channels and at 88 MHz for 40 MHz channels in the 2.4 GHz band, and at 40 MHz for 20 MHz channels and at 80 MHz for 40 MHz channels in the 5 GHz band. Thus, as Table \@ref(tab:powert) shows, we measured two more results to gain additional insight into the behaviour of the main reference clock, which is known to be linear [@Zhang2012].

Using an 11n-capable AP, we measured the idle power in the 2.4 GHz band with two channel widths, 20 and 40 MHz. Note that the idle power in 11a mode (5 GHz band), with a 40 MHz clock, is higher than the idle power with a 44 MHz clock. This is because both bands are not directly comparable, as the 5 GHz one requires more amplification (the effect of the RF amplifier is out of the scope of this work).

With these two points, we can assume a higher error (of about 10 mW) and try to estimate a maximum and a minimum slope for the power consumed by the main clock as a function of the frequency $f$. The resulting averaged regression formula is the following:

\begin{equation}
 P(f) = 0.91(3) + 0.0051(5)f (\#eq:Pf)
\end{equation}

\SPACE
This result, although coarse, enables us to estimate how a downclocking approach should perform in COTS devices. It shows that the main consumption of the clock goes to the baseline power (the power needed to simply turn it on), and that the increment per MHz is low: 5.1(5) mW/MHz. As a consequence, power-saving mechanisms based on idle downclocking, such as the one developed by @Zhang2012, will not save too much energy compared to the sleep state of COTS devices. For instance, the x16 downclocking achieved by this mechanism applied to this Atheros card throws an idle power consumption of 1.10(2) W in 11a mode, i.e., about a 15% of saving according to Table \@ref(tab:powert), which is low compared to the 70% of its sleep state. This questions the effectiveness of complex schemes based on downclocking compared to simpler ones based on the already existing sleep state.

## Summary

We have built and validated a comprehensive, high-accuracy and high-precision energy measurement framework, which is capable of measuring a wide range of wireless devices, as well as multiple heterogeneous devices synchronously. Rigorous experimental methodologies have been introduced to characterise the energy parameters of devices and wireless components. Based on these, the framework has been validated against previous results from @Serrano2014, and a COTS wireless card, which will be used in further experiments throughout this thesis, has been studied and parametrised.

At the same time, measurement handling has been systematised into `errors` [@contrib-03], a lightweight R package for managing numeric data with associated standard uncertainties. The new class `errors` provides numeric operations with automated propagation of uncertainty through a first-order TSM, and a formally sound representation of measurements with errors. Using this package makes the process of computing indirect measurements easier and less error-prone.

Future work includes importing and exporting data with uncertainties, and providing the user with an interface for plugging uncertainty propagation methods from other packages. Finally, `errors` enables ongoing developments^[*Quantities for R*, a project funded by the R Consortium (see [https://www.r-consortium.org/projects/awarded-projects](https://www.r-consortium.org/projects/awarded-projects))] for integrating `units` and uncertainty handling into a complete solution for quantity calculus. Having a unified workflow for managing measurements with units and errors would be an interesting addition to the R ecosystem with very few precedents in other programming languages.
