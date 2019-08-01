
# Leveraging Micro-Sleep Opportunities in 802.11 {#ch:05}

<span class="newthought">In this chapter</span>, we revisit the idea of packet overhearing as a trigger for sleep opportunities, and we take it one step further to the range of microseconds. To this end, we experimentally explore the timing limitations of 802.11 cards. Then, we analyse 802.11 to identify potential micro-sleep opportunities, taking into account practical CSMA-related issues (e.g., capture effect, hidden nodes) not considered in prior work.

Building on this knowledge, we design $\mu$Nap, a local standard-compliant energy-saving mechanism for 802.11 WLANs. With $\mu$Nap, a station is capable of saving energy during packet overhearing autonomously, with full independence from the 802.11 capabilities supported or other power saving mechanisms in use, which makes it backwards compatible and incrementally deployable.

Finally, the performance of the algorithm is evaluated based on our measurements and real wireless traces. In a brief discussion of the impact and applicability of our mechanism, we draw attention to the need for standardising hardware capabilities in terms of energy in 802.11.

## State Transition Times in 802.11 Cards {#state-transition-times}

From the hardware point of view, the standard Power Save (PS) mechanism requires supporting two states of operation: the *awake state* and the *sleep state*. The latter is implemented using a secondary low-frequency clock. Indeed, it is well-known that the power consumption of digital devices is proportional to the clock rate [@Zhang2012]. In fact, other types of devices, such as microcontroller-based devices or modern general-purpose CPUs, implement sleep states in the same way.

For any microcontroller-based device with at least an idle state and a sleep state, one would expect the following behaviour for an ideal sleep. The device was in idle state, consuming $P_\mathrm{idle}$, when, at an instant $t_\mathrm{off}$, the sleep state is triggered and the consumption falls to $P_\mathrm{sleep}$. A secondary low-power clock decrements a timer of duration $\Delta t_\mathrm{sleep} = t_\mathrm{on} - t_\mathrm{off}$, and then the expiration of this timer triggers the wake-up at $t_\mathrm{on}$. The switching between states would be instantaneous and the energy saving would be

\begin{equation}
 E_\mathrm{save} = (P_\mathrm{idle} - P_\mathrm{sleep}) \cdot \Delta t_\mathrm{sleep}
 (\#eq:idealsleep)
\end{equation}

\SPACE
This estimate could be considered valid for a time scale in the range of tens of milliseconds at least, but this is no longer true for micro-sleeps. Instead, Figure \@ref(fig:timing) presents a conceptual breakdown of a generic micro-sleep.

(ref:timing) Generic sleep breakdown.

<div class="figure" style="text-align: center">
<img src="img/05/timing.png" alt="(ref:timing)" width="416" />
<p class="caption">(\#fig:timing)(ref:timing)</p>
</div>

After the sleep state is triggered at $t_\mathrm{off}$, it takes $\Delta t_\mathrm{off}$ before the power consumption actually reaches $P_\mathrm{sleep}$. Similarly, after the wake-up is triggered at $t_\mathrm{on}$, it takes some time, $\Delta t_\mathrm{on}$, to reach $P_\mathrm{idle}$. Finally, the circuitry might need some additional time $\Delta t_\mathrm{ready}$ to stabilise and operate normally. Thus, the most general expression for the energy saved in a micro-sleep is the following:

\begin{equation}
\begin{split}
 E'_\mathrm{save} =&~ E_\mathrm{save} - E_\mathrm{waste} \\
 =&~ (P_\mathrm{idle} - P_\mathrm{sleep}) \cdot (\Delta t_\mathrm{sleep} -\Delta t_\mathrm{ready}) \\
 &- \int_{\Delta t_\mathrm{off} \cup \Delta t_\mathrm{on}} (P - P_\mathrm{sleep}) \cdot dt
\end{split}
(\#eq:realsleep)
\end{equation}

where we have considered a general waveform $P(t)$ for the transients $\Delta t_\mathrm{off}$ and $\Delta t_\mathrm{on}$. $E_\mathrm{waste}$ represents an energy toll per sleep when compared to the ideal case.

<span class="newthought">Our next objective</span> is to quantify these limiting parameters, which can be defined as follows:

$\Delta t_\mathrm{off}$
  ~ is the time required to switch from idle power and to sleep power consumption.
  
$\Delta t_\mathrm{on}$
  ~ is the time required to switch from sleep power to idle power consumption.
  
$\Delta t_\mathrm{ready}$
  ~ is the time required for the electronics to stabilise and become ready to transmit/receive.

The sum of this set of parameters defines the minimum sleep time, $\Delta t_\mathrm{sleep,min}$, for a given device:

\begin{equation}
 \Delta t_\mathrm{sleep,min} = \Delta t_\mathrm{off} + \Delta t_\mathrm{on} + \Delta t_\mathrm{ready}
 (\#eq:sleepmin)
\end{equation}

\SPACE
Performing this experimental characterisation requires the ability to timely trigger the sleep mode on demand. As stated in Section \@ref(anatomy-of-a-laptop-computer), most COTS cards are not suitable for this task, because they implement all the low-level operations in an internal proprietary binary firmware. However, those cards based on the open-source driver `ath9k`, like the one presented in previous chapters^[Atheros AR9280.] are well suited for our needs. The driver has access to very low level functionality (e.g., supporting triggering the sleep mode by just writing into a register).

<span class="newthought">This characterisation</span> follows the setup depicted in Section \@ref(per-component-measurements), Figure \@ref(fig:testbed-card). The card under test is associated to an access point (AP) in 11a mode to avoid any interfering traffic from neighbouring networks. This AP is placed very close to the node to obtain the best possible signal quality, as we are simply interested in not losing the connectivity for this experiment. With this setup, the idea is to trigger the sleep state, then bring the interface back to idle and finally trigger the transmission of a buffered packet as fast as possible, in order to find the timing constraints imposed by the hardware in the power signature. From an initial stable power level, with the interface associated and in idle mode, we would expect a falling edge to a lower power level corresponding to the sleep state. Then the power level would raise again to the idle level and, finally, a big power peak would mark the transmission of the packet. By correlating the timestamps of our commands and the timestamps of the measured power signature, we will be able to measure the limiting parameters $\Delta t_\mathrm{off}, \Delta t_\mathrm{on}, \Delta t_\mathrm{ready}$. 

The methodology to reproduce these steps required hacking the `ath9k` driver to timely trigger write operations in the proper card registers, and to induce a transmission of a pre-buffered packet directly in the device without going through the entire network stack. A simple hack in the `ath9k` module^[Available at [https://github.com/Enchufa2/crap/tree/master/ath9k/downup](https://github.com/Enchufa2/crap/tree/master/ath9k/downup).] allows us to perform the following experiment:

0. Initially, the card is in idle state, connected to the AP.
1. A RAW socket (Linux `AF_PACKET` socket) is created and a socket buffer is prepared with a fake packet.
2. $t_\mathrm{off}$ is triggered by writing a register in the card, which has proved to be almost instantaneous in kernel space.
3. A micro-delay of 60 $\mu$s is introduced in order to give the card time to react.
4. $t_\mathrm{on}$ is triggered with another register write.
5. Another timer sets a programmable delay.
6. The fake frame is sent using a low-level interface, i.e., calling the function `ndo_start_xmit()` from the `net_device` operations directly. By doing this, we try to spend very little time in kernel.

The power signature recorded as a result of this experiment is shown in Figure \@ref(fig:sleep-tx) (left).

(ref:sleep-tx) Atheros AR9280 timing characterisation.

<div class="figure" style="text-align: center">
<img src="05-unap_files/figure-html/sleep-tx-1.png" alt="(ref:sleep-tx)" width="49%" /><img src="05-unap_files/figure-html/sleep-tx-2.png" alt="(ref:sleep-tx)" width="49%" />
<p class="caption">(\#fig:sleep-tx)(ref:sleep-tx)</p>
</div>

As we can see, the card spends $\Delta t_\mathrm{off} = 50$ $\mu$s consuming $P_\mathrm{idle}$ and then it switches off to $P_\mathrm{sleep}$ in only 10 $\mu$s. Then, $t_\mathrm{on}$ is triggered. Similarly, the card spends $\Delta t_\mathrm{on} = 50$ $\mu$s consuming $P_\mathrm{sleep}$ and it wakes up almost instantaneously. Note that the transmission of the packet is triggered right after the $t_\mathrm{on}$ event and the frame spends very little time at the kernel (the time spent in kernel corresponds to the width of the rectangle labelled as `start_xmit` in the graph). Nonetheless, the card sends the packet 200 $\mu$s after returning to idle, even though the frame was ready for transmission much earlier.

To understand the reasons for the delay in the frame transmission observed above, we performed an experiment in which frame transmissions were triggered at different points in time by introducing different delays between the $t_\mathrm{on}$ and `start_xmit` events. Figure \@ref(fig:sleep-tx) (right) shows that the card starts transmitting always in the same instant whenever the kernel triggers the transmission within the first 250 $\mu$s right after the $t_\mathrm{on}$ event (lines 0 and 200). Otherwise, the card starts transmitting almost instantaneously (line 350). This experiments demonstrate that the device needs $\Delta t_\mathrm{ready} = 200$ $\mu$s to get ready to transmit/receive after returning to idle.

<span class="newthought">Summing up</span>, our experiments show that, if we want to bring this card to sleep during a certain time $\Delta t_\mathrm{sleep}$, we should take into account that it requires a minimum sleep time $\Delta t_\mathrm{sleep,min}=300$ $\mu$s. Therefore, $\Delta t_\mathrm{sleep} \geq \Delta t_\mathrm{sleep,min}$ must be satisfied, and we must program the $t_\mathrm{on}$ interrupt to be triggered $\Delta t_\mathrm{on} + \Delta t_\mathrm{ready}=250$ $\mu$s before the end of the sleep. Note also that the card wastes a fixed time $\Delta t_\mathrm{waste}$ consuming $P_\mathrm{idle}$:

\begin{equation}
 \Delta t_\mathrm{waste} = \Delta t_\mathrm{off} + \Delta t_\mathrm{ready}
 (\#eq:twaste)
\end{equation}

which is equal to 250 $\mu$s also. Thus, the total time in sleep state is $\Delta t_\mathrm{sleep} - \Delta t_\mathrm{waste}$, and the energy toll from Equation \@ref(eq:realsleep) can be simplified as follows:

\begin{equation}
 E_\mathrm{waste} \approx (P_\mathrm{idle} - P_\mathrm{sleep})\cdot\Delta t_\mathrm{waste}
 (\#eq:Ewaste)
\end{equation}

## Protocol Analysis and Practical Issues

The key idea of this chapter is to put the interface to sleep during packet overhearing while meeting the constraint $\Delta t_\mathrm{sleep,min}$ identified in the previous section. Additionally, such a mechanism should be local in order to be incrementally deployable, standard-compliant, and should take into account real-world practical issues. For this purpose, we first identify potential micro-sleep opportunities in 802.11, and explore well-known practical issues of WLAN networks that had not been addressed by previous energy-saving schemes.

### Identifying Potential Micro-Sleep Opportunities

Due to the CSMA mechanism, an 802.11 station (STA) receives every single frame from its Service Set Identifier (SSID) or from others in the same channel (even some frames from overlapping channels). Upon receiving a frame, a STA checks the Frame Check Sequence (FCS) for errors and then, and only after having received the entire frame, it discards the frame if it is not the recipient. In 802.11 terminology, this is called *packet overhearing*. Since packet overhearing consumes the power corresponding to a full packet reception that is not intended for the station, it represents a source of inefficiency. Thus, we could avoid this unnecessary power consumption by triggering micro-sleeps that bring the wireless card to a low-energy state.

Indeed, the Physical Layer Convergence Procedure (PLCP) carries the necessary information (rate and length) to know the duration of the PLCP Service Data Unit (PSDU), which consists of a MAC frame or an aggregate of frames. And the first 10 bytes of a MAC frame indicate the intended receiver, so a frame could be discarded very early, and the station could be brought to sleep if the hardware allows for such a short sleeping time. Therefore, the most naive micro-sleep mechanism could determine, given the constraint $\Delta t_\mathrm{sleep,min}$, whether the interface could be switched off in a frame-by-frame basis. And additionally, this behaviour can be further improved by leveraging the 802.11 virtual carrier-sensing mechanism. 

Virtual carrier-sensing allows STAs not only to seize the channel for a single transmission, but also to signal a longer exchange with another STA. For instance, this exchange can include the acknowledgement sent by the receiver, or multiple frames from a station in a single transmission opportunity (TXOP). MAC frames carry a duration value that updates the Network Allocation Vector (NAV), which is a counter indicating how much time the channel will be busy due to the exchange of frames triggered by the current frame. This duration field is, for our benefit, enclosed in the first 10 bytes of the MAC header too. Therefore, the NAV could be exploited to obtain substantial gains in terms of energy. 

<span class="newthought">In order to unveil</span> potential sleeping opportunities within the different states of operation in 802.11, first of all we review the setting of the NAV. 802.11 comprises two families of channel access methods. Within the legacy methods, the Distributed Coordination Function (DCF) is the basic mechanism with which all STAs contend employing CMSA/CA with binary exponential backoff. In this scheme, the duration value provides single protection: the setting of the NAV value is such that protects up to the end of one frame (data, management) plus any additional overhead (control frames)^[For instance, this could be the ACK following a data frame or the CTS + data + ACK following an RTS.].

When the Point Coordination Function (PCF) is used, time between beacons is rigidly divided into contention and contention-free periods (CP and CFP, respectively). The AP starts the CFP by setting the duration value in the beacon to its maximum value^[Which is 32 768; see @80211 [Table 8-3] for further details about the duration/ID field encoding]. Then, it coordinates the communication by sending CF-Poll frames to each STA. As a consequence, a STA cannot use the NAV to sleep during the CFP, because it must remain CF-pollable, but it still can doze during each individual packet transmission. In the CP, DCF is used.

802.11e introduces traffic categories (TC), the concept of TXOP, and a new family of access methods called Hybrid Coordination Function (HCF), which includes the Enhanced Distributed Channel Access (EDCA) and the HCF Controlled Channel Access (HCCA). These two methods are the QoS-aware versions of DCF and PCF respectively.

Under EDCA, there are two classes of duration values: single protection, as in DCF, and multiple protection, where the NAV protects up to the end of a sequence of frames within the same TXOP. By setting the appropriate TC, any STA may start a TXOP, which is zero for background and best-effort traffic, and of several milliseconds for video and audio traffic as defined in the standard^[See @80211 [Table 8-105].]. A non-zero TXOP may be used for dozing, as 11ac does, but these are long sleeps and the AP needs to support this feature, because a TXOP may be truncated at any moment with a CF-End frame, and it must keep buffering any frame directed to any 11ac dozing STA until the NAV set at the start of the TXOP has expired.

HCCA works similarly to PCF, but under HCCA, the CFP can be started at almost any time. In the CFP, when the AP sends a CF-poll to a STA, it sets the NAV of other STAs for an amount equal to the TXOP. Nevertheless, the AP may reclaim the TXOP if it ends too early (e.g., the STA has nothing to transmit) by resetting the NAV of other STAs with another CF-Poll. Again, the NAV cannot be locally exploited to perform energy saving during a CFP.

Finally, there is another special case in which the NAV cannot be exploited either. 802.11g was designed to bring the advantages of 11a to the 2.4 GHz band. In order to interoperate with older 11b deployments, it introduces CTS-to-self frames (also used by more recent amendments such as 11n and 11ac). These are standard CTS frames, transmitted at a legacy rate and not preceded by an RTS, that are sent by a certain STA to itself to seize the channel before sending a data frame. In this case, the other STAs cannot know which will be the destination of the next frame. Therefore, they should not use the duration field of a CTS for dozing.

### Impact of Capture Effect

It is well-known that a high-power transmission can totally blind another one with a lower SNR. Theoretically, two STAs seizing the channel at the same time yields a collision. However, in practice, if the power ratio is sufficiently high, a wireless card is able to decode the high-power frame without error, thus ignoring the other transmission. This is called *capture effect*, and although not described by the standard, it must be taken into account as it is present in real deployments.

According to @Lee2007\cite{Lee2007}, there are two types of capture effect depending on the order of the frames: if the high-power frame comes first, it is called *first* capture effect; otherwise, it is called *second* capture effect. The first one is equivalent to receiving a frame and some noise after it, and then it has no impact in our analysis. In the second capture effect, the receiving STA stops decoding the PLCP of the low-power frame and switches to another with higher power. If the latter arrives *before* a power-saving mechanism makes the decision to go to sleep, the mechanism introduces no misbehaviour.

However, @Lee2007 suggests that a high-power transmission could blind a low-power one *at any time*, even when the actual data transmission has begun. This is called *Message in Message* (MIM) in the literature [@mim1;@mim2], and it could negatively impact the performance of an interface implementing an energy-efficiency mechanism based on packet overhearing. In the following, we will provide new experimental evidence supporting that this issue still holds in modern wireless cards.

<span class="newthought">We evaluated</span> the properties of the MIM effect with an experimental setup consisting of a card under test, a brand new 802.11ac three-stream Qualcomm Atheros QCA988x card, and three additional helper nodes. These are equipped with Broadcom KBFG4318 802.11g cards, whose behaviour can be changed with the open-source firmware OpenFWWF [@openfwwfweb]. We disable the carrier sensing and back-off mechanisms so that we can decide the departure time of every transmitted frame with 1 $\mu$s granularity with respect to the internal 1MHz clock.

(ref:secondcapture) Measurement setup for the MIM effect.

<div class="figure" style="text-align: center">
<img src="img/05/testbed-francesco.png" alt="(ref:secondcapture)" width="50%" />
<p class="caption">(\#fig:secondcapture)(ref:secondcapture)</p>
</div>

Figure \@ref(fig:secondcapture) depicts the measurement setup, which consists of a node equipped with our Atheros card under test (*ath*), a synchronization (Sync) node, a *high energy* (HE) node and a *low energy* (LE) node. These two HE and LE nodes were manually carried around at different distances with respect to the *ath* node until we reached the desired power levels.

The Sync node transmits 80-byte long beacon-like frames periodically at 48 Mbps, one beacon every 8192 $\mu$s: the time among consecutive beacons is divided in 8 schedules of 1024 $\mu$s. Inside each schedule, time is additionally divided into 64 micro-slots of 16  $\mu$s. We then program the firmware of the HE and LE nodes to use the beacon-like frames for keeping their clocks synchronised and to transmit a single frame (138-$\mu$s long) per schedule starting at a specific micro-slot. This allows us to always start the transmission of the *low energy* frame from the LE node before the *high energy* frame from the HE node, and to configure the exact delay $\Delta t$ as a multiple of the micro-slot duration. 

For instance, we set up a $\Delta t = 32$ $\mu$s by configuring LE node to transmit at slot 15, HE node at slot 17. By moving LE node away from the *ath* node while the HE node is always close, we are able to control the relative power difference $\Delta P$ received by the *ath* node between frames coming from the LE and HE nodes. With the configured timings, we are able to replicate the reception experiment at the *ath* node approximately 976 times per second, thus collecting meaningful statistics in seconds. 

<table>
<caption>(\#tab:secondcapturet)Message-in-message effect.</caption>
 <thead>
<tr>
<th style="border-bottom:hidden" colspan="2"></th>
<th style="border-bottom:hidden; padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">LE frames</div></th>
<th style="border-bottom:hidden; padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">HE frames</div></th>
</tr>
  <tr>
   <th style="text-align:center;"> $\Delta P$ [dB] </th>
   <th style="text-align:right;"> $\Delta t$ [$\mu$s] </th>
   <th style="text-align:right;"> $\%$ rx </th>
   <th style="text-align:right;"> $\%$ err </th>
   <th style="text-align:right;"> $\%$ rx </th>
   <th style="text-align:right;"> $\%$ err </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:center;vertical-align: middle !important;" rowspan="5"> $\leq$ 5 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0.04 </td>
   <td style="text-align:right;"> 50.00 </td>
   <td style="text-align:right;"> 92.00 </td>
   <td style="text-align:right;"> 17.67 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> 16 </td>
   <td style="text-align:right;"> 0.40 </td>
   <td style="text-align:right;"> 0.00 </td>
   <td style="text-align:right;"> 2.15 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> 32 </td>
   <td style="text-align:right;"> 99.32 </td>
   <td style="text-align:right;"> 99.96 </td>
   <td style="text-align:right;"> 0.24 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> $\geq$ 48 </td>
   <td style="text-align:right;"> 99.10 </td>
   <td style="text-align:right;"> 99.75 </td>
   <td style="text-align:right;"> 0.34 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> $\geq$ 144 </td>
   <td style="text-align:right;"> 98.94 </td>
   <td style="text-align:right;"> 0.00 </td>
   <td style="text-align:right;"> 97.32 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   <td style="text-align:center;vertical-align: middle !important;" rowspan="7"> $\geq$ 35 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0.18 </td>
   <td style="text-align:right;"> 0.00 </td>
   <td style="text-align:right;"> 99.37 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> 16 </td>
   <td style="text-align:right;"> 0.37 </td>
   <td style="text-align:right;"> 1.11 </td>
   <td style="text-align:right;"> 91.87 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> 32 </td>
   <td style="text-align:right;"> 0.39 </td>
   <td style="text-align:right;"> 78.95 </td>
   <td style="text-align:right;"> 89.89 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> 48 </td>
   <td style="text-align:right;"> 1.54 </td>
   <td style="text-align:right;"> 68.00 </td>
   <td style="text-align:right;"> 95.58 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> 64 </td>
   <td style="text-align:right;"> 3.22 </td>
   <td style="text-align:right;"> 98.73 </td>
   <td style="text-align:right;"> 89.83 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> 128 </td>
   <td style="text-align:right;"> 60.35 </td>
   <td style="text-align:right;"> 99.96 </td>
   <td style="text-align:right;"> 39.24 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
  <tr>
   
   <td style="text-align:right;"> $\geq$ 144 </td>
   <td style="text-align:right;"> 95.33 </td>
   <td style="text-align:right;"> 0.00 </td>
   <td style="text-align:right;"> 99.64 </td>
   <td style="text-align:right;"> 0.00 </td>
  </tr>
</tbody>
</table>

<span class="newthought">We obtained</span> the results shown in Table \@ref(tab:secondcapturet). When the energy gap is small ($\le$ 5 dB), the MIM effect never enters into play as we can see from the first part of Table \@ref(tab:secondcapturet). If the two frames are transmitted at the same time, then the QCA card receives the majority of the HE frames (92%) despite some of them are broken (17%); almost no LE frames are received. By increasing the delay to 16 $\mu$s, the QCA card stops working: the short delay means that the HE frame collide with the LE one at the PLCP level. The energy gap does not allow the QCA correlator to restart decoding a new PLCP and, in fact, only a few frames are sporadically received. Further increasing the delay allows the QCA card to correctly receive the PLCP preamble of the LE frame, but then the PDU decoding is affected by errors (e.g., delay set to 48 $\mu$s) because of collision. Finally, if the delay is high enough so that both frames fit into a schedule, the QCA card receives everything correctly ($\ge$ 144 $\mu$s).

When the energy gap exceeds a threshold (i.e., more than 35 dB), then the behaviour of the QCA card changes radically as we can see from the second part of Table \@ref(tab:secondcapturet): first, with no delay, all high energy frames are received (expected given that they overkill the others); second, when both frame types fit in the schedule, all of them are received, which confirms that the link between LE node and the QCA is still very good. But, unlike the previous case, HE frames are received regardless of the delay, which means that the correlator restarts decoding the PLCP of the second frame because of the higher energy, enough for distinguishing it from the first frame that simply turns into a negligible noise.

Thus, our experiments confirm that the MIM effect actually affects modern wireless cards, and therefore it should be taken into account in any micro-sleep strategy. Let us consider, for instance, a common infrastructure-based scenario in which certain STA receives low-power frames from a distant network in the same channel. If the AP does not see them, we are facing the hidden node problem. It is clear that none of these frames will be addressed to our STA, but, if it goes to sleep during these transmissions, it may lose potential high-power frames from its BSSID. Therefore, if we perform micro-sleeps under hidden node conditions, in some cases we may lose frames that we would receive otherwise thanks to the capture effect. The same situation may happen within the local BSSID (the low-power frames belong to the same network), but this is far more rare, as such a hidden node will become disconnected sooner or later.

<span class="newthought">In order to circumvent</span> these issues, a STA should only exploit micro-sleep opportunities arising from its own network. To discard packets originating from other networks, the algorithm looks at the BSSID in the receiver address within frames addressed to an AP. If the frame was sent by an AP, it only needs to read 6 additional bytes (in the worst case), which are included in the transmitter address. Even so, these additional bytes do not necessarily involve consuming more time, depending on the modulation. For instance, for OFDM 11ag rates, this leads to a time increase of 8 $\mu$s at 6 and 9 Mbps, 4 $\mu$s at 12, 18 and 36 Mbps, and no time increase at 24, 48 and 54 Mbps.

### Impact of Errors in the MAC Header

Taking decisions without checking the FCS (placed at the end of the frame) for errors or adding any protection mechanism may lead to performance degradation due to frame loss. This problem was firstly identified by @Balaji2010\cite{Balaji2010} and @Prasad2014\cite{Prasad2014} which, based on purely qualitative criteria, reached opposite conclusions. The first work advocates for the need for a new CRC to protect the header bits while the latter dismisses this need. This section is devoted to analyse quantitatively the impact of errors.

<span class="newthought">At a first stage</span>, we need to identify, field by field, which cases are capable of harming the performance of our algorithm due to frame loss. The duration/ID field (2 bytes) and the MAC addresses (6 bytes each) are an integral part of our algorithm. According to its encoding, the duration/ID field will be interpreted as an actual duration *if and only if the bit 15 is equal to 0*. Given that the bit 15 is the most significant one, this condition is equivalent to the value being smaller than 32 768. Therefore, we can distinguish the following cases in terms of the possible errors:

- *An error changes the bit 15 from 0 to 1*. The field will not be interpreted as a duration and hence we will not go to sleep. We will be missing an opportunity to save energy, but there will be no frame loss and, therefore, the network performance will not be affected.
- *An error changes the bit 15 from 1 to 0*. The field will be wrongly interpreted as a duration. The resulting *sleep* will be up to 33 ms longer than required, with the potential frame loss associated.
- *With the bit 15 equal to 0, an error affects the previous bits*. The resulting *sleep* will be shorter or longer that the real one. In the first case, we will be missing an opportunity to save energy; in the second case, there is again a potential frame loss.
 
Regarding the receiver address field, there exist the following potential issues:

- *A multicast address changes but remains multicast*. The frame will be received and discarded, i.e., the behaviour will be the same as with no error. Hence, it does not affect.
- *A unicast address changes to multicast*. The frame will be received and discarded after detecting the error. If the unicast frame was addressed to this host, it does not affect. If it was addressed to another host, we will be missing an opportunity to save energy.
- *A multicast address changes to unicast*. If the unicast frame is addressed to this host, it does not affect. If it is addressed to another host, we will save energy with a frame which would be otherwise received and discarded.
- *Another host's unicast address changes to your own*. This case is very unlikely. The frame will be received and discarded, so we will be missing an opportunity to save energy.
- *Your own unicast address changes to another's*. We will save energy with a frame otherwise received and discarded.

As for the transmission address field, this is checked as an additional protection against the undesirable effects of the already discussed intra-frame capture effect. If the local BSSID in a packet changes to another BSSID, we will be missing an opportunity to save energy. It is extremely unlikely that an error in this field could lead to frame loss: a frame from a foreign node (belonging to another BSSID and hidden to our AP) should contain an error that matches the local BSSID in the precise moment in which our AP tries to send us a frame^[Note that this frame might be received because of the MIM effect explained previously.].

Henceforth, we draw the following conclusions:

- Errors at the MAC addresses *do not produce frame loss*, because under no circumstances they imply frame loss. The only impact is that there will be several new opportunities to save energy and several others will be wasted.
- Errors at the duration/ID field, however, *may produce frame loss* due to frame loss in periods of time up to 33 ms. Also several energy-saving opportunities may be missed without yielding any frame loss.
- An error burst affecting both the duration/ID field and the receiver address may potentially change the latter in a way that the frame would be received (multicast bit set to 1) and discarded, and thus preventing the frame loss.

<span class="newthought">From the above</span>, we have that the only case that may yield performance degradation in terms of frame loss is when we have errors in the duration/ID field. In the following, we are going to analytically study and quantify the probability of frame loss in this case. For our analysis, we first consider statistically independent single-bit errors. Each bit is considered the outcome of a Bernoulli trial with a success probability equal to the bit error probability $p_{b}$. Thus, the number of bit errors, $X$, in certain field is given by a Binomial distribution $X\sim \operatorname{B}(N, p_b)$, where $N$ is the length of that field. 

With these assumptions, we can compute the probability of having more than one erroneous bit, $\Pr(X \geq 2)$, which is three-four orders of magnitude smaller than $p_b$ with realistic $p_b$ values. Therefore, we assume that we never have more than one bit error in the frame header, so the probability of receiving an erroneous duration value with a single-bit error, $p_{e,b}$, is the following:

\begin{equation}
 p_{e,b} \approx 1 - (1 - p_b)^{15} (\#eq:peb)
\end{equation}

\SPACE
However, not all the errors imply a duration value greater than the original one, but only those which convert a zero into a one. Let us call $\operatorname{Hw}(i)$ the Hamming weight, i.e., the number of ones in the binary representation of the integer $i$. The probability of an erroneous duration value greater than the original, $p_{eg,b}$, is the following:

\begin{equation}
 p_{eg,b}(i) = p_{e,b}\cdot \frac{15 -\operatorname{Hw}(i)}{15}
 (\#eq:pegb)
\end{equation}

which represents a fraction of the probability $p_{e,b}$ and depends on the original duration $i$ (before the error). 

In order to understand the implications of the above analysis in real networks, we have analysed the SIGCOMM'08 data set [@umd-sigcomm2008-2009-03-02] and gathered which duration values are the most common. In the light of the results depicted in Table \@ref(tab:duration), it seems reasonable to approximate $p_{eg,b}/p_{e,b} \approx 1$, because it is very likely that the resulting duration will be greater than the original. 

<table>
<caption>(\#tab:duration)Most frequent duration values.</caption>
 <thead>
  <tr>
   <th style="text-align:right;"> Duration </th>
   <th style="text-align:right;"> $\%$ </th>
   <th style="text-align:right;"> $p_{eg,b}/p_b$ </th>
   <th style="text-align:left;"> Cause </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:right;"> 44 </td>
   <td style="text-align:right;"> 62.17 </td>
   <td style="text-align:right;"> 0.88 </td>
   <td style="text-align:left;"> SIFS + ACK at 24 Mbps </td>
  </tr>
  <tr>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 25.23 </td>
   <td style="text-align:right;"> 1.00 </td>
   <td style="text-align:left;"> Broadcast, multicast frames </td>
  </tr>
  <tr>
   <td style="text-align:right;"> 60 </td>
   <td style="text-align:right;"> 6.54 </td>
   <td style="text-align:right;"> 0.73 </td>
   <td style="text-align:left;"> SIFS + ACK at 6 Mbps </td>
  </tr>
  <tr>
   <td style="text-align:right;"> 48 </td>
   <td style="text-align:right;"> 5.82 </td>
   <td style="text-align:right;"> 0.87 </td>
   <td style="text-align:left;"> SIFS + ACK at 12 Mbps </td>
  </tr>
</tbody>
</table>

Finally, we can approximate $p_b$ by the BER and, based on the above data and considerations, the frame loss probability, $p_{\mathrm{loss}}$, due to an excessive sleep interval using a single-bit error model is the following:

\begin{equation}
 p_{\mathrm{loss}} = p_{eg,b} \approx p_{e,b} \approx 1 - (1 - \mathrm{BER})^{15}
 (\#eq:plossbit)
\end{equation}

\SPACE
<span class="newthought">This analysis assumes</span> independent errors. However, it is well known that errors typically occur in bursts. In order to understand the impact of error bursts in our scheme, we analyse a scenario with independent error bursts of length $X$ bits, where $X$ is a random variable. To this end, we use the Neyman-A contagious model [@neyman1939new], which has been successfully applied in telecommunications to describe burst error distributions^[E.g., by @s614, @becam1985validite and @irvin1991monitoring.]. This model assumes that both the bursts and the burst length are Poisson-distributed. Although assuming independency between errors in the same burst may not be accurate, it has been shown that the Neyman-A model performs well for short intervals [@cornaglia1996letter], which is our case.

The probability of having $k$ errors in an interval of $N$ bits, given the Neyman-A model, is the following:

\begin{equation}
 p_N(k) = \frac{\lambda_b^k}{k!}e^{-\lambda_B}\sum_{i=0}^\infty\frac{i^k}{i!}\lambda_B^i e^{-i\lambda_b}
 (\#eq:pNk)
\end{equation}

where

$\lambda_b$
  ~ is the average number of bits in a burst.
  
$\lambda_B$
  ~ $= Np_b/\lambda_b$ is the average number of bursts.

This can be transformed into a recursive formula with finite sums:

\begin{equation}
\begin{split}
 p_N(k) &= \frac{\lambda_B\lambda_b e^{-\lambda_b}}{k}\sum_{j=0}^{k-1} \frac{\lambda_b^j}{j!}p_N(k-1-j) \\
 p_N(0) &= e^{-\lambda_B\left(1-e^{-\lambda_b}\right)} 
\end{split}
(\#eq:pN0)
\end{equation}

\SPACE
Following the same reasoning as for the single-bit case, we can assume one burst at a time which will convert the duration value into a higher one. Then, the frame loss probability is the following:

\begin{equation}
 p_{\mathrm{loss}} = \sum_{k=1}^{15} p_{15}(k)
 (\#eq:plossburst)
\end{equation}

with parameters $\lambda_b$ and $p_b \approx \mathrm{BER}$.

Figure \@ref(fig:ploss) evaluates both error models as a function of BER. As expected, the single-bit error model is an upper bound for the error burst model and represents a worst-case scenario. At most, the frame loss probability is one order of magnitude higher than BER. Therefore, we conclude that the frame loss is negligible for reasonable BERs and, consequently, the limited benefit of an additional CRC does not compensate the issues.

(ref:ploss) Frame loss probability given a BER level.

<div class="figure" style="text-align: center">
<img src="05-unap_files/figure-html/ploss-1.png" alt="(ref:ploss)" width="480" />
<p class="caption">(\#fig:ploss)(ref:ploss)</p>
</div>


## $\mu$Nap Algorithm


In the following, we present $\mu$Nap, which builds upon the insights provided in previous sections and tries to save energy during the channel transmissions in which the STA is not involved. However, not all transmissions addressed to other stations are eligible for dozing, as the practical issues derived from the capture effect may incur in performance degradation. Therefore, the algorithm must check both the receiver as well as the transmitter address in the MAC header in order to determine whether the incoming frame is addressed to another station *and* it comes from within the same network.

If these conditions are met, a basic micro-sleep will last the duration of the rest of the incoming frame plus an inter-frame space (SIFS). Unfortunately, the long times required to bring an interface back and forth from sleep, as discovered in Section \@ref(state-transition-times), shows that this basic micro-sleep may not be long enough to be exploitable. Thus, the algorithm should take advantage of the NAV field whenever possible. Our previous analysis shows that this duration information stored in the NAV is not exploitable in every circumstance: the interface can leverage this additional time during CPs and it must avoid any NAV set by a CTS packet.

Finally, after a micro-sleep, two possible situations arise:

- The card wakes up at the end of a frame exchange. For instance, after a data + ACK exchange. In this case, all STAs should wait for a DIFS interval before contending again.
- The card wakes up in the middle of a frame exchange. For instance, see Figure \@ref(fig:fragments), where an RTS/CTS-based fragmented transmission is depicted.

(ref:fragments) RTS/CTS-based fragmented transmission example and $\mu$Nap's behaviour.

<div class="figure" style="text-align: center">
<img src="img/05/fragments.png" alt="(ref:fragments)" width="606" />
<p class="caption">(\#fig:fragments)(ref:fragments)</p>
</div>
 
In the latter example, an RTS sets the NAV to the end of a fragment, and our algorithm triggers the sleep. This first fragment sets the NAV to the end of the second fragment, but it is not seen by the dozing STA. When the latter wakes up, it sees a SIFS period of silence and then the second fragment, which sets its NAV again and may trigger another sleep. This implies that the STA can doze for an additional SIFS, as Figure \@ref(fig:fragments) shows, and wait in idle state until a DIFS is completed before trying to contend again.

<span class="newthought">Based on the above</span>, Algorithm \@ref(fig:unap) describes the main loop of a wireless card's microcontroller that would implement our mechanism. When the first 16 bytes of the incoming frame are received, all the information needed to take the decision is available: the duration value ($\Delta t_\mathrm{NAV}$), the receiver address ($R_A$) and the transmitter address ($T_A$). The ability to stop a frame's reception at any point has been demonstrated to be feasible [@berger2014]. Note that MAC addresses can be efficiently compared in a streamed way, so that the first differing byte (if the first byte of the $R_A$ has the multicast bit set to zero, i.e., $R_A$ is unicast) triggers our sleep procedure (`Set_Sleep` in Algorithm \@ref(fig:unap)). In addition, the main loop should keep up to date a global variable ($C$) indicating whether the contention is currently allowed (CP) or not (CFP). This is straightforward, as every CFP starts and finishes with a beacon frame.

<div class="figure" style="text-align: center">
<img src="img/05/algorithm.svg" alt="$\mu$Nap implementation. Main loop modification to leverage micro-sleeps."  />
<p class="caption">(\#fig:unap)$\mu$Nap implementation. Main loop modification to leverage micro-sleeps.</p>
</div>

The `Set_Sleep` procedure takes as input the remaining time until the end of the incoming frame ($\Delta t_\mathrm{DATA}$) and the duration value ($\Delta t_\mathrm{NAV}$). The latter is used only if it is a valid duration value and a CP is active. Then, the card may doze during $\Delta t_\mathrm{sleep}$ (if this period is greater than $\Delta t_\mathrm{sleep,min}$), wait for a DIFS to complete and return to the main loop.

Finally, it is worth noting that this algorithm is deterministic, as it is based on a set of conditions to trigger the sleep procedure. It works locally with the information already available in the protocol headers, without incurring in any additional control overhead and without impacting the normal operation of 802.11. Specifically, our analytical study of the impact of errors in the first 16 bytes of the MAC header shows that the probability of performance degradation is comparable to the BER under normal channel conditions. Therefore, the overall performance in terms of throughput and delay is completely equivalent to normal 802.11.

\PSalgorithm{!h}{fig:unap}{$\mu$Nap implementation. Main loop modification to leverage micro-sleeps.}

\cleardoublepage

## Performance Evaluation

This section is devoted to evaluate the performance of $\mu$Nap. First, through trace-driven simulation, we show that $\mu$Nap significantly reduces the overhearing time and the energy consumption in a real network. Secondly, we analyse the impact of the timing constraints imposed by the hardware, which are specially bad in the case of the AR9280, and we discuss the applicability of $\mu$Nap in terms of those parameters and the evolution trends in the 802.11 standard.

### Evaluation with Real Traces

In the following, we conduct an evaluation to assess how much energy might be saved in a real network if all STAs implement $\mu$Nap using the AR9280. The reasons for this are twofold. On the one hand, the timing properties of this interface are particularly bad if we think of typical frame durations in 802.11, which means that many micro-sleep opportunities will be lost due to hardware constraints. On the other hand, it does not support newer standards that could potentially lead to longer micro-sleep opportunities through mechanisms such as frame aggregation. Therefore, an evaluation based on an 11a/g network and the AR9280 chip represents a worst case scenario for our algorithm.

For this purpose, we used 802.11a wireless traces with about 44 million packets, divided in 43 files, from the SIGCOMM'08 data set [@umd-sigcomm2008-2009-03-02]. The methodology followed to parse each trace file is as follows. Firstly, we discover all the STAs and APs present. Each STA is mapped into its BSSID and a bit array is developed in order to hold the status at each point in time (online or offline). It is hard to say when a certain STA is offline from a capture, because they almost always disappear without sending a disassociation frame. Thus, we use the default rule in `hostapd`, the daemon that implements the AP functionality in Linux: a STA is considered online if it transmitted a frame within the last 5 min.

Secondly, we measure the amount of time that each STA spends (without our algorithm) in the following states: transmission, reception, overhearing and idle. We consider that online STAs are always awake; i.e., even if a STA announces that it is going into PS mode, we ignore this announcement. We measure also the amount of time that each STA would spend (with our algorithm) in transmission, reception, overhearing, sleep and idle. Transmission and reception times match the previous case, as expected. As part of idle time, we account separately the wasted time in each micro-sleep as a consequence of hardware limitations (the fixed toll $\Delta t_\mathrm{waste}$). After this processing, there are a lot of duplicate unique identifiers (MAC addresses), i.e., STAs appearing in more than one trace file. Those entries are summarised by aggregating the time within each state.

<span class="newthought">At this point</span>, let us define the *activity* time as the sum of transmission, reception, overhearing, sleep and wasted time. We do not take into account the idle time since our goal is to understand how much power we can save in the periods of activity, which are the only ones that consume power in wireless transmissions (the scope of our mechanism). Using the definition above, we found that the majority of STAs reveals very little activity (they are connected for a few seconds and disappear). Therefore, we took the upper decile in terms of activity, thus obtaining the 42 more active STAs.

(ref:eval-agg) Normalised activity aggregation (left) and energy consumption aggregation (right) of all STAs.

<div class="figure" style="text-align: center">
<img src="05-unap_files/figure-html/eval-agg-1.png" alt="(ref:eval-agg)" width="49%" /><img src="05-unap_files/figure-html/eval-agg-2.png" alt="(ref:eval-agg)" width="49%" />
<p class="caption">(\#fig:eval-agg)(ref:eval-agg)</p>
</div>

The activity aggregation of all STAs is normalised and represented in Figure \@ref(fig:eval-agg) (left). Transmission (tx) and reception (rx) times are labelled as *common*, because STAs spend the same time transmitting and receiving both with and without our algorithm. It is clear that our mechanism effectively reduces the total overhearing (ov) time from a median of 70% to a 30% approximately (a 57% reduction). The card spends consistently less time in overhearing because this overhearing time difference, along with some idle (id) time from inter-frame spaces, turns into micro-sleeps, that is, sleep (sl) and wasted (wa) time.

This activity aggregation enables us to calculate the total energy consumption using the power values from the thorough characterisation presented in Section \@ref(characterisation-of-a-cots-device). Figure \@ref(fig:eval-agg) (right) depicts the energy consumption in units of mAh (assuming a typical 3.7-V battery). The energy savings overcome 1200 mAh even with the timing limitations of the AR9280 card, which (i) prevents the card from going to sleep when the overhearing time is not sufficiently long, and (ii) wastes a long fixed time in idle during each successful micro-sleep. This reduction amounts to a 21.4% of the energy spent in overhearing and a 15.8% of the total energy during the activity time, when the transmission and reception contributions are also considered.

(ref:eval-sta) Normalised activity (left) and energy consumption (right) per STA.

<div class="figure" style="text-align: center">
<img src="05-unap_files/figure-html/eval-sta-1.png" alt="(ref:eval-sta)" width="49%" /><img src="05-unap_files/figure-html/eval-sta-2.png" alt="(ref:eval-sta)" width="49%" />
<p class="caption">(\#fig:eval-sta)(ref:eval-sta)</p>
</div>

Figure \@ref(fig:eval-sta) provides a breakdown of the data by STA. The lower graph shows the activity breakdown per STA for our algorithm (transmission bars, in white, are very small). Overhearing time is reduced to a more or less constant fraction for all STAs (i.e., with the algorithm, the overhearing bars represent more or less a 30% of the total activity for all STAs), while less participative STAs (left part of the graph) spend more time sleeping. The upper graph shows the energy consumption per STA with our algorithm along with the energy-saving in dark gray, which is in the order of tens of mAh per STA.

### Impact of Timing Constraints

The performance gains of $\mu$Nap depend on the behaviour of the circuitry. Its capabilities, in terms of timing, determine the maximum savings that can be achieved. Particularly, each micro-sleep has an efficiency (in comparison to an ideal scheme in which the card stays in sleep state over the entire duration of the micro-sleep) given by

\begin{equation}
 \frac{E'_\mathrm{save}}{E_\mathrm{save}} = \frac{E_\mathrm{save} - E_\mathrm{waste}}{E_\mathrm{save}} \approx 1 - \frac{\Delta t_\mathrm{waste}}{\Delta t_\mathrm{sleep}}
 (\#eq:fracsave)
\end{equation}

which results from the combination of Equations \@ref(eq:idealsleep), \@ref(eq:realsleep) and \@ref(eq:Ewaste).

Figure \@ref(fig:savings) represents this sleep efficiency for the AR9280 card ($\Delta t_\mathrm{waste}=250$) along with other values. It is clear that an improvement of $\Delta t_\mathrm{waste}$ is fundamental to boost performance in short sleeps.

(ref:savings) Sleep efficiency $E'_\mathrm{save}/E_\mathrm{save}$ as $\Delta t_\mathrm{waste}$ decreases.

<div class="figure" style="text-align: center">
<img src="05-unap_files/figure-html/savings-1.png" alt="(ref:savings)" width="480" />
<p class="caption">(\#fig:savings)(ref:savings)</p>
</div>

Similarly, the constraint $\Delta t_\mathrm{sleep,min}$ limits the applicability of $\mu$Nap, especially in those cases where the NAV cannot be used to extend the micro-sleep. For instance, let us consider the more common case in 11a/b/g networks: the transmission of a frame (up to 1500 bytes long) plus the corresponding ACK. Then,

\begin{equation}
 \Delta t_\mathrm{sleep,min} \le \Delta t_\mathrm{DATA} + \Delta t_\mathrm{SIFS} + \Delta t_\mathrm{ACK} + \Delta t_\mathrm{SIFS} (\#eq:tsleepmin)
\end{equation}

and expanding the right side of the inequality,

\begin{equation*}
 \Delta t_\mathrm{sleep,min} \le \frac{8(14+l_\mathrm{min}+4)}{\lambda_\mathrm{DATA}} + \Delta t_\mathrm{PLCP} + \frac{8(14+2)}{\lambda_\mathrm{ACK}} + 2\Delta t_\mathrm{SIFS}
\end{equation*}

\SPACE
Here, we can find $l_\mathrm{min}$, which is the minimum amount of data (in bytes, and apart from the MAC header and the FCS) that a frame must contain in order to last $\Delta t_\mathrm{sleep,min}$. Based on this $l_\mathrm{min}$, Figure \@ref(fig:applicability) defines the applicability in 802.11a DCF in terms of frame sizes ($\le 1500$ bytes) that last $\Delta t_\mathrm{sleep,min}$ at least. Again, an improvement in $\Delta t_\mathrm{waste}$ would boost not only the energy saved per sleep, but also the general applicability defined in this way.

(ref:applicability) Algorithm applicability for common transmissions ($\le 1500$ bytes $+$ ACK) in 802.11a DCF mode.

<div class="figure" style="text-align: center">
<img src="05-unap_files/figure-html/applicability-1.png" alt="(ref:applicability)" width="787.2" />
<p class="caption">(\#fig:applicability)(ref:applicability)</p>
</div>

The applicability of $\mu$Nap may also be affected by the evolution of the standard. Particularly, 802.11n introduced, and 802.11ac followed, a series of changes enabling high and very high throughput respectively, up to Gigabit in the latter case. This improvement is largely based on MIMO and channel binding: multiple spatial and frequency streams. Nevertheless, a single 20-MHz spatial stream is more or less equivalent to 11ag. Some enhancements (shorter guard interval and coding enhancements) may boost the throughput of a single stream from 54 to 72 Mbps under optimum conditions. Yet it is also the case that the PLCP is much longer to accommodate the complexity of the new modulation coding schemes (MCSs). This overhead not only extends each transmission, but also encourages the use of frame aggregation. Thus, the increasing bandwidth, in current amendments or future ones, does not necessarily imply a shorter airtime in practice, and our algorithm is still valid. 

<span class="newthought">Reducing</span> PHY's timing requirements is essential to boost energy savings, but its feasibility should be further investigated. Nonetheless, there are some clues that suggest that there is plenty of room for improvement. In the first place, $\Delta t_\mathrm{off}$ and $\Delta t_\mathrm{on}$ should depend on the internal firmware implementation (i.e., the complexity of saving/restoring the state). Secondly, Figure \@ref(fig:sleep-tx) (left) indicates that a transmission is far more aggressive, in terms of a sudden power rise, than a return from sleep. From this standpoint, $\Delta t_\mathrm{ready} = 200$ $\mu$s would be a pessimistic estimate of the time required by the circuitry to stabilise. Last, but not least, the 802.3 standard goes beyond 802.11 and, albeit to a limited extent, it defines some timing parameters^[E.g., $\Delta t_\mathrm{w_{phy}}$ would be equivalent to our $\Delta t_\mathrm{on}+\Delta t_\mathrm{ready}$.] of the PHYs, which are in the range of tens of $\mu$s in the worst case^[See @8023 [Table 78-4]].

Due to these reasons, WiFi card manufacturers should push for a better power consumption behaviour, which is necessary to boost performance with the power-saving mechanism presented in this paper. Furthermore, it is necessary for the standardisation committees and the manufacturers to collaborate to agree on power consumption behaviour guidelines for the hardware (similarly to what has been done with 802.3). Indeed, strict timing parameters would allow researchers and developers to design more advanced power-saving schemes.

## Summary

Based on a thorough characterisation of the timing constraints and energy consumption of 802.11 interfaces, we have exhaustively analysed the micro-sleep opportunities that are available in current WLANs. We have unveiled the practical challenges of these opportunities, previously unnoticed in the literature, and, building on this knowledge, we have proposed $\mu$Nap [@contrib-05a;@contrib-05b] an energy-saving scheme that is orthogonal to the existing standard PS mechanisms. Unlike previous attempts, our scheme takes into account the non-zero time and energy required to move back and forth between the active and sleep states, and decides when to put the interface to sleep in order to make the most of these opportunities while avoiding frame losses.

We have demonstrated the feasibility of our approach using a robust methodology and high-precision instrumentation, showing that, despite the limitations of COTS hardware, the use of our scheme would result in a 57% reduction in the time spent in overhearing, thus leading to an energy saving of 15.8% of the activity time according to our trace-based simulation. Finally, based on these results, we have made the case for the strict specification of energy-related parameters of 802.11 hardware, which would enable the design of platform-agnostic energy-saving strategies.