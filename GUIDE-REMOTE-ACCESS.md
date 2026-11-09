# Remote access guide: phone + home PC + pizzeria POS

Goal: from any one of the 3 devices (Android phone, home Windows PC, pizzeria Windows POS) you can
**see the screen, control it, move files, run commands, turn it off, and turn it back on**.
Claude can also act on the PCs for you.

Do the phases in order. Each phase works on its own, so you can stop after any of them.

---

## The 5 pieces

| Piece | What it does | Tool (free) |
|---|---|---|
| 1. Private network | Puts all 3 devices on one private, encrypted network, even though they sit on different internet connections | **Tailscale** |
| 2. Screen control | See and use the PC's screen from another device | **RustDesk** (free for business use too) |
| 3. Power OFF / restart | Shut down from far away | RustDesk, or a one-click shortcut |
| 4. Power ON | Start a PC that is completely off | **Smart plug + a BIOS setting** (easiest), or Wake-on-LAN |
| 5. Claude's hands | Claude runs commands and clicks on the PCs for you | **Claude desktop app** + Remote Control |

---

## Phase 0: Before you start (10 min)

1. **POS warning.** Check your POS software's contract or ask the vendor whether you may install
   remote-access apps. Some vendors forbid it, or already install TeamViewer/AnyDesk for support.
   The POS handles card payments, so card data rules (PCI) apply. Do all POS work **outside
   service hours**.
2. Give each Windows PC a **strong password** and turn on **2-step verification** on your Google
   account and on every account below.
3. Write down for each PC: Windows version, whether it's on **cable (Ethernet) or Wi-Fi**, and the
   router brand. Cable matters for Phase 4.

## Phase 1: Private network with Tailscale (15 min)

Do this on all 3 devices, signed in to **the same account**:

1. Go to tailscale.com, click *Get started*, and sign in with Google.
2. **Phone:** install "Tailscale" from the Play Store, sign in, and switch it ON.
3. **Each PC:** download the Windows app from tailscale.com/download, install it, and sign in.
4. Open the admin page (login.tailscale.com/admin/machines). You should see 3 machines. For both
   PCs, click `...` → **Disable key expiry** so they never drop off the network.
5. Rename them `home-pc` and `pos-pizzeria`. Each one gets a fixed `100.x.x.x` address. Write
   those addresses down.

## Phase 2: Screen control with RustDesk (20 min)

1. **Each PC:** install RustDesk from rustdesk.com (the Windows installer, not the portable version).
2. In RustDesk, open **Settings → Security**:
   - Set a **permanent password** (long, and different on each PC).
   - Turn on **Enable direct IP access**. This lets RustDesk connect through Tailscale.
   - Make sure RustDesk is installed as a **service**, so it runs before you log in.
3. **Phone:** install RustDesk from the Play Store.
4. Test it: on the phone, type the PC's Tailscale address (`100.x.x.x`) in the ID box → Connect →
   enter the password. You now control that PC. RustDesk also has **file transfer** and works
   PC↔PC in both directions.

## Phase 3: Make the PCs reachable 24/7 (10 min per PC)

On **each PC**:

1. Settings → System → Power → **Sleep: Never** when plugged in. Screen off is fine.
2. Control Panel → Power Options → "Choose what the power buttons do" → **untick "Turn on fast
   startup"**.
3. Optional: set Windows to log in automatically so apps start after a reboot. Do this only on
   the home PC. Leave the POS on its normal lock screen.

**Power off from far away:** connect with RustDesk → Start → Shut down. Or ask Claude (Phase 5)
to run `shutdown /s /t 0`. To restart, use `shutdown /r /t 0`.

## Phase 4: Power ON from far away

A PC that is fully off can't hear the internet, so you need a helper. Pick one option:

### Option A: Smart plug (easiest, about €10–20 per PC). Recommended.
1. Buy a Wi-Fi smart plug with a phone app (TP-Link Tapo, Meross, …) for each PC.
2. Enter the PC's BIOS: restart, then press `Del` or `F2` at boot. Find **"Restore on AC Power
   Loss"** (also called "AC Back" or "After Power Failure") → set it to **Power On** → save.
3. To turn the PC on from anywhere: in the plug's app, switch **OFF**, wait 10 seconds, then
   switch **ON**. The PC boots by itself.
4. ⚠️ Only cut the plug when the PC is **already shut down**. Never cut power while it's running.

### Option B: Wake-on-LAN (free, but more technical, and works best on cable)
1. In the BIOS, enable **Wake on LAN / Power on by PCI-E**.
2. In Windows Device Manager → network card → Properties → Power Management, tick "Allow this
   device to wake the computer". Under Advanced, enable **Wake on Magic Packet**.
3. Something that is **always on at the same location** must send the wake signal. That can be
   your router (if it has a WoL feature), a Raspberry Pi running Tailscale + UpSnap, or an old
   Android phone left plugged in there with Tailscale and a WoL app.

## Phase 5: Give Claude hands on the PCs

1. On each PC, install the **Claude desktop app** (claude.ai/download) and sign in with your
   account.
2. In the app, open **Settings → Claude Code → Remote Control** and add a working folder (for
   example `C:\Claude`). Keep the app running. You can set it to start with Windows.
3. From your phone, open the Claude app → Code, start a session, and ask me to work on
   `home-pc` or `pos-pizzeria`. You approve the connection on screen, and then I can run
   commands, read and edit files, install things, and shut the PC down. **Computer use** inside
   the desktop app also lets me look at the screen and click.
4. Limits to know about: one Claude session attaches to **one computer**, so open a new session
   for the other PC. I only act while you're talking to me. The PC must be on and the app must be
   running.

## Phase 6: Safety net

- One person (you) owns all the accounts, and 2-step verification is on everywhere.
- Back up the POS before changing anything on it: a Windows restore point, plus a copy of the POS
  database if the vendor allows it.
- If a phone is lost: remove it in the Tailscale admin page and change the RustDesk passwords.

---

### Checklist
- [ ] Phase 0: POS vendor OK, strong passwords, 2-step verification
- [ ] Phase 1: Tailscale on all 3 devices, key expiry disabled on both PCs
- [ ] Phase 2: RustDesk on all 3, permanent password, direct IP on
- [ ] Phase 3: sleep off, fast startup off
- [ ] Phase 4: smart plug + BIOS "Power On" (or Wake-on-LAN)
- [ ] Phase 5: Claude desktop app + Remote Control folder on both PCs
- [ ] Phase 6: POS backup
