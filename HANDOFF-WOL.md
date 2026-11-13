# Handoff: fix remote Wake-on-LAN for the home PC

Paste this whole file as the first message of a new **local** Claude Code session running
on the home PC (environment "Local", not the cloud "Default").

## Goal
Make the home PC wake up reliably **from outside the house** (phone on 5G) with the
WolOn app, and make the DDNS name always point to the current public IP.
Diagnose: (1) does DDNS (No-IP) update after the IP changes? (2) does the router
"forget" the PC (ARP entry expires) after the PC has been off for a long time?
Do NOT reorganize the desktop.

## Hardware and network (already known)
- Home PC: Windows 11 Pro, name `MADANI`, user `Maalim Madani`
- Motherboard: BIOSTAR B760MX2-E PRO D4, AMI BIOS 5.27 (2025-05-08)
- NIC: Realtek Gaming 2.5GbE, interface `Ethernet`, MAC `F4-B5-20-65-0B-8C`
- PC LAN IP: `192.168.1.77` (DHCP reservation added in router: Réseau local → LAN → Liaison DHCP, name `PC-MAISON`)
- Tailscale IP of the PC: `100.113.55.97` (pizzeria POS is `100.86.68.117`)
- Router: ZTE F6600P (Algérie Télécom fiber ONT), admin at `http://192.168.1.1`, firmware V9.0.10P25N1
  - Internet connection is `omci_ipv4_pppoe_1` (PPPoE, public IPv4, NAT on). The `omci_ipv4_dhcp_2` 10.x connection is VoIP/TR069, ignore it.
  - Public IP is dynamic (was 197.203.135.224, now 105.105.56.107). No CGNAT (router WAN IP == whatismyip).
  - Router clock shows 1970 → SNTP probably not configured (Internet → SNTP). May break DDNS.
  - Firewall level currently **Low** (Internet → Sécurité → Pare-feu). Plan: set Middle at the end and re-test.

## What is already configured and verified
- BIOS (Advanced → ACPI Settings): `PME Wake up from S5` = Enabled, `Restore AC Power Loss` = Power On. Chipset → `CEC Ready` (ErP) = Disabled.
- Windows NIC: `Shutdown Wake-On-Lan` = Enabled, `Wake on Magic Packet` = Enabled, Fast Startup disabled, no sleep on AC.
- LAN wake works (phone on home Wi-Fi, WolOn LAN mode, 255.255.255.255 port 9).
- Router port forwarding (Internet → Sécurité → tab "Transfert de port"): rule `WOL-PC`, UDP,
  WAN connection omci_ipv4_pppoe_1, WAN port 40009 → LAN host `192.168.1.77` port 9.
  (Forwarding to 192.168.1.255 was accepted by the UI but did NOT work.)
- WAN wake from 5G **works** when WolOn uses the current raw public IP, including after the PC was off 5–10 min.
- It FAILED when WolOn used `madani-pc.ddns.net` right after a router reboot → DDNS had not updated.

## DDNS (No-IP)
- Account: the user's No-IP account (free plan; hostname must be confirmed every 30 days by email).
- Hostname: `madani-pc.ddns.net` (A record, Dynamic DNS enabled).
- A DDNS Key was generated for "DDNS Compatible Device". The router (Internet → DDNS) was set to
  provider No-IP, Activé, username/password = DDNS key credentials, hostname `all.ddnskey.com`.
  Credentials are with the user; never ask them to paste secrets in chat.
- No-IP shows times in US Pacific (UTC-8); Algeria is UTC+1.

## Phone app (WolOn, Android)
- Device "PC (internet)", WAN mode: MAC F4:B5:20:65:0B:8C, Router address currently `105.105.56.107`
  (raw IP, should become `madani-pc.ddns.net` once DDNS works), Router port 40009.
- Device "Home PC", LAN mode: 255.255.255.255 port 9.

## Tasks for this session
1. Check DDNS: compare `Resolve-DnsName madani-pc.ddns.net` with the current public IP
   (`(Invoke-RestMethod https://api.ipify.org)`). If different, inspect the router DDNS page
   (via the browser with the user) and fix: try hostname `madani-pc.ddns.net` instead of
   `all.ddnskey.com`, enable SNTP (server pool.ntp.org, GMT+1), check No-IP "DDNS Keys" page for last use.
   Consider a fallback updater: No-IP DUC on the PC only helps while the PC is on, so the router must be the updater.
2. Check whether the router forgets the PC: look in the router for an ARP table / static ARP
   (Réseau local or Gestion et diagnostic). If static ARP for 192.168.1.77 ↔ F4:B5:20:65:0B:8C exists, set it.
   Otherwise plan a long test (PC off ≥ 2 h, wake from 5G) and report.
3. If the router cannot keep the ARP entry, propose the backup: smart plug (BIOS already set to
   Power On after AC loss) or an always-on device at home sending WoL on the LAN.
4. At the end: set firewall to Middle and re-test WAN wake.
Report each step as passed / failed / blocked, in simple language (the user is not a developer;
they speak French and English).
