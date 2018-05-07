
# Introduction

<span class="newthought">Energy efficiency</span> is the ability to do more with less. When we talk about *green communications*, this means more connectivity, more capacity and more responsiveness at a lower energy cost. Unfortunately, these are competing goals, and all we can do in this tale is to fight against thermodynamics to seek for the elusive *optimality*.

It is straightforward to compute the minimum energy required to move a mass on a surface from point A to point B, as it depends on the friction coefficient. Drawing a parallelism, we are interested in the *friction* [@grover2015] of communicating a *bit* from point A to point B. As in the Newtonian example, our problem depends on the *substrate*, the specific technology and implementation. But when we deal with such complex systems as today's telecommunications networks, this estimation remains unfeasible.

We walk blindly towards an unknown lower bound. Fortunately, the set of possible strategies are limited and well-known [@samdanis2015green], and pursue a common objective, namely, that the energy consumption should be proportional to the transmitted information. These can be divided in three basic principles subject of active research, and their intent can be summarised as follows:

Speed scaling,
  ~ which tries to adapt the processing speed of network devices to the traffic load.
  
Powering down,
  ~ which aims to turn network devices off during inactivity periods. This is commonly implemented as the so-called *sleep states*, and their *depth* introduces an inherent trade-off with the time required to become active again.

Rate adaptation,
  ~ which tries to adapt the transmission rate of wireless cards according to the channel conditions^[This, as well as the *speed scaling* principle, is based on a direct relationship between consumption and transmission rate, which is not always the case.].

The aim of this thesis is to explore the above three strategies in the scope of wireless communications for mobile user devices at multiple layers, as will be introduced in the following sections: from the operating system to the low-level operation of the wireless card.

## Cross-Factor: Towards a New Energy Model

We are living in an era in which consumer electronics are becoming *wireless consumer electronics*. That is, just about any known gadget is capable of connecting to cellular, wireless Local Area Networks (WLAN) or wireless Personal Area Networks (WPAN) nowadays. The Internet of Things (IoT) is growing fast and wireless communications become its main driver. Due to the densification of wireless networks and the ubiquity of battery-powered devices, energy efficiency stands as a major research issue.

More and more devices around us are becoming *smart*, incorporating more processing power in order to do more things, and some of them are already comparable to a small laptop computer. As a consequence, not only do they share hardware components, but also software: in particular, the Linux kernel is spreading into billions of devices all over the world, whether inside of the popular Android operating system or other embedded systems.

Whereas a lot of research were and is devoted to obtain more energy-efficient hardware components (e.g., wireless cards, processors, screens), too little attention has been paid, in terms of energy, to a core software component that enables all these devices: the operating system and, inside it, the network stack.

<span class="newthought">The seminal paper</span> by @Feeney2001\cite{Feeney2001} gives the very first insight on energy consumption of wireless interfaces. This work was done on a per-frame basis by accounting for the energy drained by an 802.11 wireless card. Subsequent experimental work followed the same approach, showing that the energy consumption of wireless transmissions/receptions can be characterised using a simple linear model. This fact arises from the three typical states of operation of a wireless card: idle, transmitting and receiving.

The model, commonly expressed in terms of power, has a fixed part $\rho_{id}$, device-dependent, attributable to the idle state, and it grows linearly with the airtime percentage $\tau$ (i.e., the fraction of time in which the card is transmitting or receiving).

However, more recently, the novel work by @Serrano2014\cite{Serrano2014} performed extensive per-frame measurements for seven devices of different types (smartphones, tablets, embedded devices and wireless routers), and unveiled that actually there is a non-negligible per-frame processing toll ascribed to the frame crossing the network stack. This component emerges as a new offset proportional to the frame generation rate, and it is not explained by the *classical* model.

\pagebreak The currently accepted energy model is a multilinear model articulated into three main parts:

\begin{equation}
 \overline{P}(\tau_i, \lambda_i) = \underbrace{\rho_\mathrm{id} + \sum_{i\in\mathrm{\{tx,rx\}}} \rho_i \tau_i}_{\text{classical model}} + \sum_{i\in\mathrm{\{g,r\}}} \gamma_{\mathrm{x}i} \lambda_i
 (\#eq:new-energy-model)
\end{equation}

where the first two addends correspond to the classical model and the third is the contribution described in @Serrano2014. This model can be subdivided into five components:

- A platform-specific baseline power consumption that accounts for the energy consumed just by the fact of being powered on, but with no network activity. This component is commonly referred to as *idle consumption*, $\rho_\mathrm{id}$.
- A component that accounts for the energy consumed in transmission, which grows linearly with the airtime percentage $\tau_\mathrm{tx}$\marginnote{$\overline{P_\mathrm{tx}}(\tau_\mathrm{tx}) = \rho_\mathrm{tx} \tau_\mathrm{tx}$}. The slope $\rho_\mathrm{tx}$ depends linearly on the radio transmission parameters MCS and TXP.
- A component that accounts for the energy consumed in reception, which grows linearly with the airtime percentage $\tau_\mathrm{rx}$\marginnote{$\overline{P_\mathrm{rx}}(\tau_\mathrm{rx}) = \rho_\mathrm{rx} \tau_\mathrm{rx}$}. The slope $\rho_\mathrm{rx}$ depends linearly on the radio transmission parameter MCS.
- A new component, called *generation cross-factor* or $\gamma_{\mathrm{xg}}$, that accounts for a per-frame energy processing toll in transmission, which grows linearly with the traffic rate $\lambda_\mathrm{g}$ generated\marginnote{$\overline{P_\mathrm{xg}}(\lambda_\mathrm{g}) = \gamma_\mathrm{xg} \lambda_\mathrm{g}$}. The slope $\gamma_\mathrm{xg}$ depends on the computing characteristics of the device.
- A new component, called *reception cross-factor* or $\gamma_{\mathrm{xr}}$, that accounts for a per-frame energy processing toll in reception, which grows linearly with the traffic rate $\lambda_\mathrm{r}$ received\marginnote{$\overline{P_\mathrm{xr}}(\lambda_\mathrm{r}) = \gamma_\mathrm{xr} \lambda_\mathrm{r}$}. Likewise, the slope $\gamma_\mathrm{xr}$ depends on the computing characteristics of the device.

Therefore, the average power consumed $\overline{P}$ is a function of five device-dependent parameters ($\rho_i, \gamma_{\mathrm{x}i}$) and four traffic-dependent ones ($\tau_i, \lambda_i$).

The results obtained with this new multilinear model showed that the so-called cross-factor accounts for 50% to 97% of the per-frame energy consumption. Additional findings showed that it is independent of the CPU load on some devices and *almost* independent of the frame size.

Therefore, this inspired us to deepen into the roots of the cross-factor, to deseed its components and analyse its causes. To this aim, it is of paramount importance the conception of a comprehensive, high-accuracy and high-precision measurement framework that enables us to measure the consumption of a wide range of mobile devices.

## Micro-Sleep Opportunities in 802.11

IEEE 802.11 is an extremely common technology for broadband Internet access. Energy efficiency stands as a major issue due to the intrinsic CSMA mechanism, which forces the network card to stay active performing *idle listening*, while most of the 802.11-capable terminals run on batteries.

The 802.11 standard developers are fully aware of the energy issues that WiFi poses on battery-powered devices and have designed mechanisms to reduce energy consumption. One of such mechanisms is the Power Save (PS) mode, which is widely deployed among commercial wireless cards, although unevenly supported in software drivers. With this mechanism, a station (STA) may enter a doze state during long periods of time, subject to prior notification, if it has nothing to transmit. Meanwhile, packets addressed to this dozing STA are buffered and signalled in the Traffic Indication Map (TIM) attached to each beacon frame.

The PS mechanism dramatically reduces the power consumption of a wireless card. However, the counterpart is that, since the card is put to sleep for hundreds of milliseconds, the user experiences a serious performance degradation because of the delays incurred. The automatic power save delivery (APSD) introduced by the 11e amendment (@Perez-Costa2010\cite{Perez-Costa2010} give a nice overview) is based on this mechanism, and aims to improve the downlink delivery by taking advantage of QoS mechanisms, but has not been widely adopted.

More recently, the 11ac amendment improves the PS capabilities with the VHT TXOP (Very High Throughput, Transmission Opportunity) PS mechanism. Basically, an 11ac STA can doze during other STAs' TXOPs. This capability is announced within the new VHT framing format, so that the AP knows that it cannot send traffic to those STAs until the TXOP's natural end, even if it is interrupted earlier. Still, the potential dozing is in the range of milliseconds and may lead to channel underuse if these TXOPs are not fully exploited.

Considering shorter timescales, packet overhearing (i.e., listening to the wireless while there is an ongoing transmission addressed to other station) has been identified as a potential source of energy waste [@basu2004]. Despite this, our measurements found no trace of mechanisms in commercial wireless card to lessen its impact.

Taking advantage on the energy measurement framework built for this thesis, we further investigate the timing capabilities for transitioning between operational states of a commercial off-the-shelf (COTS) wireless card. Based on this, we propose $\mu$Nap, a practical algorithm to leverage micro-sleep opportunities in 802.11 WLANs.

## Rate Adaptation and Power Control in 802.11

At the beginning of this introduction, we have identified rate adaptation as one of the three basic strategies that can be applied to achieve proportionality between energy consumption and traffic load. Nevertheless, energy efficiency has not been the main driver for research in the fields of rate adaptation and power control in 802.11.

Rate adaptation (RA) algorithms are responsible for selecting the most appropriate modulation and coding scheme (MCS) to use given an estimation of the link conditions, being the frame losses one of the main indicators of such conditions. In general, the challenge lies in distinguishing between those losses due to collisions and those due to poor radio conditions, because they should trigger different reactions. In addition, the performance figure to optimise is commonly the throughput or a related one such as, e.g., the time required to deliver a frame.

On the other hand, network densification is becoming a common tool to provide better coverage and capacity. However, densification brings new problems, especially for 802.11, given the limited amount of orthogonal channels available, which leads to performance and reliability issues due to radio frequency interference. In consequence, some RA schemes also incorporate transmission power control (TPC), which tries to minimise the transmission power (TXP) with the purpose of reducing interference between nearby networks. As in the case of "vanilla" RA, the main performance figure to optimise is also the throughput.

It is generally assumed that optimality in terms of throughput also implies optimality in terms of energy efficiency. However, some previous work [@Li2012;@khan2013] has shown that throughput maximisation does not result in energy efficiency maximisation, at least for 802.11n. However, we still lack a proper understanding of the causes behind this "non-duality", as it may be caused by the specific design of the algorithms studied, an extra consumption caused by the complexity of MIMO techniques, or any other reason.

This thesis revisits RA-TPC in 802.11 within the context of energy efficiency. We first conduct an analytical study, and then we evaluate the performance, in terms of energy, of several state-of-the-art RA-TPC algorithms by simulation. Our results unveil that the trade-off shown by previous studies is in turn inherent to 802.11 operation. Particularly, we show that the link quality conditions which trigger mode transitions (changes of MCS/TXP) may be source of inefficiencies. Nonetheless, our analyses provide some heuristics that can be used along the energy parameters of the wireless card to mitigate such inefficiencies.

## Applied Simulation Modelling for Energy Efficiency

Simulation frameworks are undoubtedly one of the most important tools for the analysis and design of communication networks and protocols. Their applications are numerous, including the performance evaluation of existing or novel proposals, dimensioning of resources and capacity planning, or the validation of theoretical analyses.

Simulation frameworks make a number of simplifying assumptions to reduce complexity so the development of the scenario is easier and numerical figures are obtained faster. This "complexity" axis goes from very specialised, large simulation tools such as NS-3, OMNeT++, OPNET, to *ad-hoc* simulation tools, consisting on hundreds of lines of code, typically used to validate a very specific part of the network or a given mathematical analysis. The latter are often developed over general-purpose languages such as C/C++ or Python, over numerical frameworks such as Matlab, or over some framework for discrete-event simulation (DES).

On the one hand, the complexity of specialised tools (as their cost, if applicable) preclude their use for short-to-medium research projects, as the learning curve is typically steep plus they are difficult to extend, which is mandatory to test a novel functionality. On the other hand, the development of ad-hoc tools also require some investment of time and resources, lack a proper validation of their functionality, and, furthermore, there is no code maintenance once the project is finished, for the few cases in which the code is made publicly available.

Last but not least, the monitoring of variables of interest typically stands out as a first-order problem. Most simulators require a specific effort in this regard, so that the modeller has to ponder which parameters must be monitored, and where and how this should be done. Therefore, the design of the scenario is intrinsically linked to data collection.

The research experience gained over the course of this thesis have made us aware of the need for new simulation tools committed to the middle-way approach: less specificity and complexity in exchange for faster prototyping, while supporting efficient simulation at a low implementation cost. As a result, we developed `simmer`, a process-oriented and trajectory-based DES package for R, which is designed to be an easy-to-use yet powerful framework. Its most noteworthy characteristic is the automatic monitoring capability, which allows the user to focus on the system model. The use of this simulator in networking is demonstrated through the energy modelling of a 5G-inspired scenario.

## Thesis Overview

The remainder of this thesis is organised as follows. Chapter \@ref(ch:02) presents the relevant literature related to the topics introduced in this chapter. Then, the dissertation is divided into three thematic parts: *experimentation*, *mathematical modelling* and *simulation*. Chapter \@ref(ch:03) presents a comprehensive energy measurement framework, which has been a fundamental pillar of this thesis. Building on this, Chapter \@ref(ch:04) delves into the roots of the cross-factor by exploring the energy consumption of the Linux network stack. Chapter \@ref(ch:05) completes the experimental part with a study of the timing constraints of a COTS wireless card, which is developed into a standard-compliant algorithm to leverage micro-sleep opportunities in 802.11 WLANs. Chapter \@ref(ch:06) presents a joint goodput-energy model that unveils an inherent trade-off between througput and energy efficiency maximisation in 802.11 when RA-TPC techniques are applied. Chapter \@ref(ch:07) further extends the latter work by simulating and comparing the performance of several representative RA-TPC algorithms. Closing the simulation part, Chapter \@ref(ch:08) presents our novel DES framework, and showcases its versatility by analising the energy consumption of an Internet-of-Things scenario with thousands of metering devices. Finally, Chapter \@ref(ch:09) contains the thesis conclusions and future lines of work.

This thesis covers the following contributions:
@contrib-03, @contrib-04a, @contrib-04b, @contrib-05a, @contrib-05b, @contrib-06, @contrib-07, @contrib-08a, @contrib-08b.


Therefore, there is an overlap between this dissertation and the publications listed above. Additionally, the following contributions are not part of this thesis:
@flex5gware, @5gnorma, @11aa.

