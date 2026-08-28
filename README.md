# Hermes Agent + Workspace Installer

ติดตั้ง **Hermes Agent + Hermes Dashboard + Hermes Workspace** บน Ubuntu 24.04 พร้อมจัดการด้วย `systemd --user`

โปรเจกต์นี้ใช้:

* [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
* [outsourc-e/hermes-workspace](https://github.com/outsourc-e/hermes-workspace)

Hermes Workspace ทำหน้าที่เป็น Web UI ส่วน Hermes Agent เป็นตัว AI Agent/Gateway และ Hermes Dashboard ให้ API สำหรับ sessions, memory, skills, jobs และข้อมูลของ Agent

---

## Architecture

หลังติดตั้งจะมี 3 services:

```text
┌──────────────────────────────────────────────┐
│              Ubuntu 24.04 Server             │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Hermes Workspace                      │  │
│  │ HTTP :3000                            │  │
│  │ Web UI                                │  │
│  └──────────────────┬─────────────────────┘  │
│                     │                        │
│          ┌──────────┴──────────┐             │
│          ▼                     ▼             │
│  ┌─────────────────┐   ┌─────────────────┐  │
│  │ Hermes Gateway  │   │ Hermes Dashboard │  │
│  │ :8642           │   │ :9119            │  │
│  └─────────────────┘   └─────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

Default binding:

```text
Workspace   127.0.0.1:3000
Gateway     127.0.0.1:8642
Dashboard   127.0.0.1:9119
```

เมื่อต้องการเข้า Workspace จากเครื่องอื่น แนะนำให้เปิดเฉพาะ Workspace ผ่าน **Tailscale**

```text
PC / Laptop / Phone
        │
        │ Tailscale
        ▼
100.x.x.x:3000
        │
        ▼
Hermes Workspace
        │
        ├── 127.0.0.1:8642
        └── 127.0.0.1:9119
```

ไม่จำเป็นต้องเปิด `8642` และ `9119` ออก network

---

# Requirements

## Operating System

แนะนำ:

```text
Ubuntu 24.04 LTS
```

สถาปัตยกรรม:

```text
x86_64
```

หรือ ARM64 ที่รองรับ dependencies ของ Hermes

---

## User

ควรติดตั้งด้วย **normal user** ไม่ใช่ root

ตรวจสอบ:

```bash
whoami
```

ตัวอย่าง:

```text
user
```

ไม่ควรเป็น:

```text
root
```

ตรวจสอบ home:

```bash
echo $HOME
```

ตัวอย่าง:

```text
/home/user
```

---

# Installation

สมมติว่าไฟล์ชื่อ:

```text
install-hermes.sh
```

## 1. Download / Copy Script

ตัวอย่าง:

```bash
nano install-hermes.sh
```

วาง script แล้วบันทึก

หรือถ้ามีไฟล์อยู่แล้ว:

```bash
ls -lh install-hermes.sh
```

---

## 2. เพิ่ม execute permission

```bash
chmod +x install-hermes.sh
```

---

## 3. Run installer

```bash
./install-hermes.sh
```

**ไม่ต้องใช้:**

```bash
sudo ./install-hermes.sh
```

เพราะ Hermes Agent และ Workspace จะถูกติดตั้งใน user environment

ตัว installer จะใช้ `sudo` เฉพาะส่วนที่จำเป็น เช่น:

* apt packages
* Node.js
* pnpm
* system configuration

---

# What the Installer Does

Script จะดำเนินการตามลำดับดังนี้:

```text
1. ตรวจสอบ Ubuntu
2. ตรวจสอบ user
3. ติดตั้ง system dependencies
4. ติดตั้ง Node.js 22+
5. ติดตั้ง pnpm
6. ติดตั้ง Hermes Agent
7. สร้าง ~/.hermes
8. เปิด Hermes API Server
9. Clone Hermes Workspace
10. สร้าง .env
11. pnpm install
12. pnpm build
13. สร้าง systemd services
14. enable services
15. start services
16. health check
```

---

# Directory Structure

หลังติดตั้งโดยทั่วไปจะได้:

```text
~/
├── .hermes/
│   ├── .env
│   ├── skills/
│   └── logs/
│
├── hermes-workspace/
│   ├── .env
│   ├── package.json
│   ├── dist/
│   ├── node_modules/
│   └── ...
│
└── .config/
    └── systemd/
        └── user/
            ├── hermes-gateway.service
            ├── hermes-dashboard.service
            └── hermes-workspace.service
```

---

# Services

มีทั้งหมด 3 services

## Hermes Gateway

```text
hermes-gateway.service
```

Port:

```text
8642
```

ตรวจสอบ:

```bash
systemctl --user status hermes-gateway
```

---

## Hermes Dashboard

```text
hermes-dashboard.service
```

Port:

```text
9119
```

ตรวจสอบ:

```bash
systemctl --user status hermes-dashboard
```

---

## Hermes Workspace

```text
hermes-workspace.service
```

Port:

```text
3000
```

ตรวจสอบ:

```bash
systemctl --user status hermes-workspace
```

---

# Check All Services

ใช้:

```bash
systemctl --user --type=service | grep hermes
```

หรือ:

```bash
systemctl --user status hermes-gateway
systemctl --user status hermes-dashboard
systemctl --user status hermes-workspace
```

สถานะที่ต้องการ:

```text
Active: active (running)
```

---

# Health Check

## Gateway

```bash
curl http://127.0.0.1:8642/health
```

ควรได้ response ประมาณ:

```json
{
  "status": "ok"
}
```

---

## Dashboard

```bash
curl http://127.0.0.1:9119/api/status
```

ควรได้รับ JSON response

---

## Workspace

```bash
curl -I http://127.0.0.1:3000
```

ควรได้ HTTP response เช่น:

```text
HTTP/1.1 200 OK
```

---

# Check Ports

```bash
ss -lntp | grep -E ':3000|:8642|:9119'
```

ตัวอย่าง:

```text
127.0.0.1:8642
127.0.0.1:9119
127.0.0.1:3000
```

---

# Configure Remote Access with Tailscale

แนะนำให้ใช้ Tailscale สำหรับการเข้า Workspace จากเครื่องอื่น

## Install Tailscale

หากยังไม่ได้ติดตั้ง:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Login:

```bash
sudo tailscale up
```

ตรวจสอบ IP:

```bash
tailscale ip -4
```

ตัวอย่าง:

```text
100.100.100.10
```

ตรวจสอบ:

```bash
tailscale status
```

---

# Expose Workspace to Tailscale

ค่าเริ่มต้นของ Workspace คือ:

```text
127.0.0.1:3000
```

ดังนั้นเครื่องอื่นจะเข้าไม่ได้

แก้:

```bash
nano ~/.config/systemd/user/hermes-workspace.service
```

เปลี่ยน:

```ini
Environment=HOST=127.0.0.1
```

เป็น:

```ini
Environment=HOST=0.0.0.0
```

จากนั้น:

```bash
systemctl --user daemon-reload
systemctl --user restart hermes-workspace
```

ตรวจสอบ:

```bash
ss -lntp | grep :3000
```

ควรเห็น:

```text
0.0.0.0:3000
```

---

# Workspace Environment

ไฟล์:

```text
~/hermes-workspace/.env
```

ค่าที่สำคัญ:

```env
HERMES_API_URL=http://127.0.0.1:8642
HERMES_DASHBOARD_URL=http://127.0.0.1:9119

HOST=0.0.0.0
PORT=3000

NODE_ENV=production
```

จุดสำคัญคือ:

```env
HERMES_API_URL=http://127.0.0.1:8642
HERMES_DASHBOARD_URL=http://127.0.0.1:9119
```

**ไม่ต้องเปลี่ยนเป็น Tailscale IP** หาก Workspace, Gateway และ Dashboard อยู่เครื่องเดียวกัน

เพราะ Workspace เป็นตัวกลางในการติดต่อ Backend

---

# Workspace Password

แนะนำให้เปิด password protection หาก Workspace สามารถเข้าถึงผ่าน network ได้

แก้:

```bash
nano ~/hermes-workspace/.env
```

เพิ่ม:

```env
HERMES_PASSWORD=CHANGE_THIS_TO_A_STRONG_PASSWORD
```

ตัวอย่าง:

```env
HERMES_PASSWORD=MyVeryStrongPassword_2026!
```

จากนั้น:

```bash
systemctl --user restart hermes-workspace
```

**อย่า commit `.env` เข้า Git**

---

# Access from Another Computer

ดู Tailscale IP:

```bash
tailscale ip -4
```

สมมติ:

```text
100.100.100.10
```

จากเครื่องอื่นที่ติดตั้ง Tailscale แล้วเปิด:

```text
http://100.100.100.10:3000
```

ตัวอย่าง:

```text
http://100.100.100.10:3000
```

---

# Recommended Network Design

ควรใช้รูปแบบนี้:

```text
                    Tailscale
                       │
                       ▼
              ┌─────────────────┐
              │ Workspace :3000 │
              └────────┬────────┘
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
      Gateway :8642        Dashboard :9119
       localhost              localhost
```

ไม่แนะนำ:

```text
Internet
   │
   ├── :3000  Workspace
   ├── :8642  Gateway       ❌
   └── :9119  Dashboard     ❌
```

Gateway และ Dashboard ไม่ควรเปิด public โดยไม่จำเป็น

---

# systemd User Services

Installer ใช้:

```bash
systemctl --user
```

ไม่ใช่:

```bash
systemctl
```

ดังนั้นคำสั่งต้องมี `--user`

ตัวอย่าง:

```bash
systemctl --user restart hermes-gateway
```

---

# Enable Services

ตรวจสอบ:

```bash
systemctl --user is-enabled hermes-gateway
systemctl --user is-enabled hermes-dashboard
systemctl --user is-enabled hermes-workspace
```

ควรได้:

```text
enabled
enabled
enabled
```

---

# Enable Start After Reboot

Installer จะเปิด user lingering:

```bash
sudo loginctl enable-linger $USER
```

ตรวจสอบ:

```bash
loginctl show-user "$USER" | grep Linger
```

ควรได้:

```text
Linger=yes
```

ทำให้ `systemd --user` สามารถเริ่ม service หลัง reboot ได้ แม้ยังไม่ได้ login ผ่าน SSH

---

# Start / Stop / Restart

## Gateway

Start:

```bash
systemctl --user start hermes-gateway
```

Stop:

```bash
systemctl --user stop hermes-gateway
```

Restart:

```bash
systemctl --user restart hermes-gateway
```

---

## Dashboard

```bash
systemctl --user restart hermes-dashboard
```

---

## Workspace

```bash
systemctl --user restart hermes-workspace
```

---

# Restart Everything

แนะนำให้ restart ตามลำดับ:

```bash
systemctl --user restart hermes-gateway
sleep 3

systemctl --user restart hermes-dashboard
sleep 3

systemctl --user restart hermes-workspace
```

หรือ:

```bash
systemctl --user restart hermes-gateway hermes-dashboard hermes-workspace
```

---

# Logs

## Gateway

ดู log แบบ realtime:

```bash
journalctl --user -u hermes-gateway -f
```

ย้อนหลัง:

```bash
journalctl --user -u hermes-gateway -n 200 --no-pager
```

---

## Dashboard

```bash
journalctl --user -u hermes-dashboard -f
```

---

## Workspace

```bash
journalctl --user -u hermes-workspace -f
```

---

# Check Recent Errors

```bash
journalctl --user -u hermes-gateway \
    -u hermes-dashboard \
    -u hermes-workspace \
    -p warning \
    -n 200 \
    --no-pager
```

---

# Hermes CLI

ตรวจสอบ:

```bash
hermes --version
```

ดู help:

```bash
hermes --help
```

ดู config:

```bash
hermes config get
```

Setup:

```bash
hermes setup
```

เลือก model:

```bash
hermes model
```

ตรวจสอบระบบ:

```bash
hermes doctor
```

---

# Hermes Gateway Manual Test

หยุด service ก่อน หากต้องการ debug แบบ foreground:

```bash
systemctl --user stop hermes-gateway
```

จากนั้น:

```bash
hermes gateway run
```

จะเห็น log โดยตรงใน terminal

กด:

```text
Ctrl+C
```

แล้วกลับมา:

```bash
systemctl --user start hermes-gateway
```

---

# Hermes Dashboard Manual Test

หยุด service:

```bash
systemctl --user stop hermes-dashboard
```

รัน:

```bash
hermes dashboard --host 127.0.0.1 --port 9119
```

ทดสอบจาก terminal อีกตัว:

```bash
curl http://127.0.0.1:9119/api/status
```

---

# Workspace Manual Test

หยุด:

```bash
systemctl --user stop hermes-workspace
```

เข้า directory:

```bash
cd ~/hermes-workspace
```

รัน:

```bash
pnpm start
```

หรือสำหรับ development:

```bash
pnpm dev
```

---

# Updating Hermes Agent

Hermes Agent มีคำสั่ง update:

```bash
hermes update
```

หลัง update แนะนำ restart:

```bash
systemctl --user restart hermes-gateway
systemctl --user restart hermes-dashboard
systemctl --user restart hermes-workspace
```

ตรวจสอบ:

```bash
hermes --version
```

---

# Updating Hermes Workspace

เข้า directory:

```bash
cd ~/hermes-workspace
```

ดึง code:

```bash
git pull --ff-only
```

ติดตั้ง dependencies:

```bash
pnpm install
```

build:

```bash
pnpm build
```

restart:

```bash
systemctl --user restart hermes-workspace
```

---

# Full Workspace Update

```bash
cd ~/hermes-workspace

git pull --ff-only

pnpm install

pnpm build

systemctl --user restart hermes-workspace
```

---

# Troubleshooting

## Workspace Offline

ตรวจสอบ Gateway:

```bash
curl http://127.0.0.1:8642/health
```

ตรวจ Dashboard:

```bash
curl http://127.0.0.1:9119/api/status
```

ตรวจ Workspace:

```bash
curl -I http://127.0.0.1:3000
```

ดู logs:

```bash
journalctl --user -u hermes-workspace -n 200 --no-pager
```

---

# 401 Unauthorized / no_cookie

หากพบ:

```text
401
unauthenticated
no_cookie
Unauthorized
```

อย่าเพิ่งแก้ด้วยการปิด authentication แบบสุ่ม

ตรวจสอบ Workspace `.env`:

```bash
cat ~/hermes-workspace/.env
```

และ Hermes environment:

```bash
cat ~/.hermes/.env
```

ค้นหา authentication settings:

```bash
grep -E 'API_SERVER|HERMES_API' ~/.hermes/.env
```

และ:

```bash
grep -E 'HERMES_API|HERMES_DASHBOARD' ~/hermes-workspace/.env
```

ถ้า Hermes Gateway ใช้:

```env
API_SERVER_KEY=...
```

Workspace ต้องได้รับ token เดียวกันผ่าน:

```env
HERMES_API_TOKEN=...
```

ตัวอย่าง:

```env
HERMES_API_TOKEN=YOUR_API_SERVER_KEY
```

จากนั้น:

```bash
systemctl --user restart hermes-gateway
systemctl --user restart hermes-dashboard
systemctl --user restart hermes-workspace
```

---

# Dashboard Not Responding

ตรวจ process:

```bash
ps aux | grep '[h]ermes'
```

ตรวจ port:

```bash
ss -lntp | grep 9119
```

ตรวจ service:

```bash
systemctl --user status hermes-dashboard
```

ดู log:

```bash
journalctl --user -u hermes-dashboard -n 300 --no-pager
```

---

# Gateway Not Responding

```bash
systemctl --user status hermes-gateway
```

```bash
journalctl --user -u hermes-gateway -n 300 --no-pager
```

ตรวจ:

```bash
curl -v http://127.0.0.1:8642/health
```

---

# Port Already in Use

ตรวจสอบ:

```bash
sudo ss -lntp | grep -E ':3000|:8642|:9119'
```

หรือ:

```bash
sudo lsof -i :3000
sudo lsof -i :8642
sudo lsof -i :9119
```

หากมี Hermes process เก่าค้างอยู่ ให้ตรวจ:

```bash
ps aux | grep '[h]ermes'
```

อย่า kill process แบบสุ่มก่อนดูว่าเป็น service ตัวไหน

---

# Firewall

หากใช้ UFW:

```bash
sudo ufw status
```

สำหรับ Tailscale ไม่จำเป็นต้องเปิด ports ให้ Internet

หากต้องการจำกัด Workspace ให้รับเฉพาะ Tailscale ควรพิจารณา firewall policy เพิ่มเติมแทนการเปิด `3000/tcp` ให้ทุก interface

ตรวจ Tailscale interface:

```bash
ip addr show tailscale0
```

---

# Security Recommendations

## 1. ใช้ Tailscale

แนะนำ:

```text
Tailscale
    +
Workspace password
```

แทนการเปิด Workspace public โดยตรง

---

## 2. อย่า expose Gateway

ควรคง:

```text
127.0.0.1:8642
```

---

## 3. อย่า expose Dashboard

ควรคง:

```text
127.0.0.1:9119
```

---

## 4. อย่า commit secrets

ห้าม commit:

```text
.env
~/.hermes/.env
```

ตรวจ:

```bash
git status
```

---

## 5. Protect environment files

```bash
chmod 600 ~/.hermes/.env
chmod 600 ~/hermes-workspace/.env
```

---

# Complete Diagnostic

เมื่อมีปัญหา ให้รัน:

```bash
echo "===== SYSTEM ====="
uname -a
cat /etc/os-release | head

echo
echo "===== NODE ====="
node --version
pnpm --version

echo
echo "===== HERMES ====="
which hermes
hermes --version

echo
echo "===== TAILSCALE ====="
tailscale ip -4 || true
tailscale status || true

echo
echo "===== PORTS ====="
ss -lntp | grep -E ':3000|:8642|:9119' || true

echo
echo "===== SERVICES ====="
systemctl --user --no-pager status \
    hermes-gateway \
    hermes-dashboard \
    hermes-workspace

echo
echo "===== GATEWAY ====="
curl -fsS http://127.0.0.1:8642/health || true

echo
echo "===== DASHBOARD ====="
curl -fsS http://127.0.0.1:9119/api/status || true

echo
echo "===== WORKSPACE ====="
curl -I http://127.0.0.1:3000 || true
```

---

# Useful Commands

## All services

```bash
systemctl --user status hermes-gateway hermes-dashboard hermes-workspace
```

## Restart all

```bash
systemctl --user restart hermes-gateway hermes-dashboard hermes-workspace
```

## Logs all

```bash
journalctl --user \
    -u hermes-gateway \
    -u hermes-dashboard \
    -u hermes-workspace \
    -f
```

## Check ports

```bash
ss -lntp | grep -E ':3000|:8642|:9119'
```

## Check Tailscale

```bash
tailscale ip -4
tailscale status
```

## Check Hermes

```bash
hermes doctor
```

---

# Uninstall

## Stop services

```bash
systemctl --user disable --now hermes-workspace
systemctl --user disable --now hermes-dashboard
systemctl --user disable --now hermes-gateway
```

## Remove systemd units

```bash
rm -f ~/.config/systemd/user/hermes-gateway.service
rm -f ~/.config/systemd/user/hermes-dashboard.service
rm -f ~/.config/systemd/user/hermes-workspace.service

systemctl --user daemon-reload
```

## Remove Workspace

```bash
rm -rf ~/hermes-workspace
```

## Remove Hermes data

**คำเตือน:** ขั้นตอนนี้จะลบ configuration, memory, skills และข้อมูลของ Hermes ที่อยู่ใน `~/.hermes`

```bash
rm -rf ~/.hermes
```

ไม่ควรทำหากต้องการเก็บข้อมูลเดิมไว้

---

# Recommended Production Setup

สำหรับ server ที่ต้องการใช้งานจริง แนะนำ:

```text
Ubuntu 24.04
│
├── Tailscale
│
├── Hermes Agent
│   └── 127.0.0.1:8642
│
├── Hermes Dashboard
│   └── 127.0.0.1:9119
│
├── Hermes Workspace
│   └── 0.0.0.0:3000
│
├── systemd --user
│
└── HERMES_PASSWORD
```

การเข้าถึง:

```text
PC / Phone
     │
     │ Tailscale
     ▼
100.x.x.x:3000
     │
     ▼
Hermes Workspace
     │
     ├── localhost:8642
     └── localhost:9119
```

ไม่จำเป็นต้องใช้ Nginx สำหรับ topology นี้

---

# Official References

## Hermes Agent

https://github.com/NousResearch/hermes-agent

Official documentation:

https://hermes-agent.nousresearch.com/docs/

## Hermes Workspace

https://github.com/outsourc-e/hermes-workspace

Workspace ใช้ Hermes Agent แบบ zero-fork และเชื่อมต่อผ่าน Gateway/Dashboard API

---

# License

Hermes Agent:

MIT

Hermes Workspace:

MIT

โปรดตรวจสอบ license และเงื่อนไขของ dependencies ที่เกี่ยวข้องก่อนนำไปใช้ใน production/commercial environment
# Hermes Agent + Workspace Installer

ติดตั้ง **Hermes Agent + Hermes Dashboard + Hermes Workspace** บน Ubuntu 24.04 พร้อมจัดการด้วย `systemd --user`

โปรเจกต์นี้ใช้:

* [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
* [outsourc-e/hermes-workspace](https://github.com/outsourc-e/hermes-workspace)

Hermes Workspace ทำหน้าที่เป็น Web UI ส่วน Hermes Agent เป็นตัว AI Agent/Gateway และ Hermes Dashboard ให้ API สำหรับ sessions, memory, skills, jobs และข้อมูลของ Agent

---

## Architecture

หลังติดตั้งจะมี 3 services:

```text
┌──────────────────────────────────────────────┐
│              Ubuntu 24.04 Server             │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Hermes Workspace                      │  │
│  │ HTTP :3000                            │  │
│  │ Web UI                                │  │
│  └──────────────────┬─────────────────────┘  │
│                     │                        │
│          ┌──────────┴──────────┐             │
│          ▼                     ▼             │
│  ┌─────────────────┐   ┌─────────────────┐  │
│  │ Hermes Gateway  │   │ Hermes Dashboard │  │
│  │ :8642           │   │ :9119            │  │
│  └─────────────────┘   └─────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

Default binding:

```text
Workspace   127.0.0.1:3000
Gateway     127.0.0.1:8642
Dashboard   127.0.0.1:9119
```

เมื่อต้องการเข้า Workspace จากเครื่องอื่น แนะนำให้เปิดเฉพาะ Workspace ผ่าน **Tailscale**

```text
PC / Laptop / Phone
        │
        │ Tailscale
        ▼
100.x.x.x:3000
        │
        ▼
Hermes Workspace
        │
        ├── 127.0.0.1:8642
        └── 127.0.0.1:9119
```

ไม่จำเป็นต้องเปิด `8642` และ `9119` ออก network

---

# Requirements

## Operating System

แนะนำ:

```text
Ubuntu 24.04 LTS
```

สถาปัตยกรรม:

```text
x86_64
```

หรือ ARM64 ที่รองรับ dependencies ของ Hermes

---

## User

ควรติดตั้งด้วย **normal user** ไม่ใช่ root

ตรวจสอบ:

```bash
whoami
```

ตัวอย่าง:

```text
user
```

ไม่ควรเป็น:

```text
root
```

ตรวจสอบ home:

```bash
echo $HOME
```

ตัวอย่าง:

```text
/home/user
```

---

# Installation

สมมติว่าไฟล์ชื่อ:

```text
install-hermes.sh
```

## 1. Download / Copy Script

ตัวอย่าง:

```bash
nano install-hermes.sh
```

วาง script แล้วบันทึก

หรือถ้ามีไฟล์อยู่แล้ว:

```bash
ls -lh install-hermes.sh
```

---

## 2. เพิ่ม execute permission

```bash
chmod +x install-hermes.sh
```

---

## 3. Run installer

```bash
./install-hermes.sh
```

**ไม่ต้องใช้:**

```bash
sudo ./install-hermes.sh
```

เพราะ Hermes Agent และ Workspace จะถูกติดตั้งใน user environment

ตัว installer จะใช้ `sudo` เฉพาะส่วนที่จำเป็น เช่น:

* apt packages
* Node.js
* pnpm
* system configuration

---

# What the Installer Does

Script จะดำเนินการตามลำดับดังนี้:

```text
1. ตรวจสอบ Ubuntu
2. ตรวจสอบ user
3. ติดตั้ง system dependencies
4. ติดตั้ง Node.js 22+
5. ติดตั้ง pnpm
6. ติดตั้ง Hermes Agent
7. สร้าง ~/.hermes
8. เปิด Hermes API Server
9. Clone Hermes Workspace
10. สร้าง .env
11. pnpm install
12. pnpm build
13. สร้าง systemd services
14. enable services
15. start services
16. health check
```

---

# Directory Structure

หลังติดตั้งโดยทั่วไปจะได้:

```text
~/
├── .hermes/
│   ├── .env
│   ├── skills/
│   └── logs/
│
├── hermes-workspace/
│   ├── .env
│   ├── package.json
│   ├── dist/
│   ├── node_modules/
│   └── ...
│
└── .config/
    └── systemd/
        └── user/
            ├── hermes-gateway.service
            ├── hermes-dashboard.service
            └── hermes-workspace.service
```

---

# Services

มีทั้งหมด 3 services

## Hermes Gateway

```text
hermes-gateway.service
```

Port:

```text
8642
```

ตรวจสอบ:

```bash
systemctl --user status hermes-gateway
```

---

## Hermes Dashboard

```text
hermes-dashboard.service
```

Port:

```text
9119
```

ตรวจสอบ:

```bash
systemctl --user status hermes-dashboard
```

---

## Hermes Workspace

```text
hermes-workspace.service
```

Port:

```text
3000
```

ตรวจสอบ:

```bash
systemctl --user status hermes-workspace
```

---

# Check All Services

ใช้:

```bash
systemctl --user --type=service | grep hermes
```

หรือ:

```bash
systemctl --user status hermes-gateway
systemctl --user status hermes-dashboard
systemctl --user status hermes-workspace
```

สถานะที่ต้องการ:

```text
Active: active (running)
```

---

# Health Check

## Gateway

```bash
curl http://127.0.0.1:8642/health
```

ควรได้ response ประมาณ:

```json
{
  "status": "ok"
}
```

---

## Dashboard

```bash
curl http://127.0.0.1:9119/api/status
```

ควรได้รับ JSON response

---

## Workspace

```bash
curl -I http://127.0.0.1:3000
```

ควรได้ HTTP response เช่น:

```text
HTTP/1.1 200 OK
```

---

# Check Ports

```bash
ss -lntp | grep -E ':3000|:8642|:9119'
```

ตัวอย่าง:

```text
127.0.0.1:8642
127.0.0.1:9119
127.0.0.1:3000
```

---

# Configure Remote Access with Tailscale

แนะนำให้ใช้ Tailscale สำหรับการเข้า Workspace จากเครื่องอื่น

## Install Tailscale

หากยังไม่ได้ติดตั้ง:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Login:

```bash
sudo tailscale up
```

ตรวจสอบ IP:

```bash
tailscale ip -4
```

ตัวอย่าง:

```text
100.100.100.10
```

ตรวจสอบ:

```bash
tailscale status
```

---

# Expose Workspace to Tailscale

ค่าเริ่มต้นของ Workspace คือ:

```text
127.0.0.1:3000
```

ดังนั้นเครื่องอื่นจะเข้าไม่ได้

แก้:

```bash
nano ~/.config/systemd/user/hermes-workspace.service
```

เปลี่ยน:

```ini
Environment=HOST=127.0.0.1
```

เป็น:

```ini
Environment=HOST=0.0.0.0
```

จากนั้น:

```bash
systemctl --user daemon-reload
systemctl --user restart hermes-workspace
```

ตรวจสอบ:

```bash
ss -lntp | grep :3000
```

ควรเห็น:

```text
0.0.0.0:3000
```

---

# Workspace Environment

ไฟล์:

```text
~/hermes-workspace/.env
```

ค่าที่สำคัญ:

```env
HERMES_API_URL=http://127.0.0.1:8642
HERMES_DASHBOARD_URL=http://127.0.0.1:9119

HOST=0.0.0.0
PORT=3000

NODE_ENV=production
```

จุดสำคัญคือ:

```env
HERMES_API_URL=http://127.0.0.1:8642
HERMES_DASHBOARD_URL=http://127.0.0.1:9119
```

**ไม่ต้องเปลี่ยนเป็น Tailscale IP** หาก Workspace, Gateway และ Dashboard อยู่เครื่องเดียวกัน

เพราะ Workspace เป็นตัวกลางในการติดต่อ Backend

---

# Workspace Password

แนะนำให้เปิด password protection หาก Workspace สามารถเข้าถึงผ่าน network ได้

แก้:

```bash
nano ~/hermes-workspace/.env
```

เพิ่ม:

```env
HERMES_PASSWORD=CHANGE_THIS_TO_A_STRONG_PASSWORD
```

ตัวอย่าง:

```env
HERMES_PASSWORD=MyVeryStrongPassword_2026!
```

จากนั้น:

```bash
systemctl --user restart hermes-workspace
```

**อย่า commit `.env` เข้า Git**

---

# Access from Another Computer

ดู Tailscale IP:

```bash
tailscale ip -4
```

สมมติ:

```text
100.100.100.10
```

จากเครื่องอื่นที่ติดตั้ง Tailscale แล้วเปิด:

```text
http://100.100.100.10:3000
```

ตัวอย่าง:

```text
http://100.100.100.10:3000
```

---

# Recommended Network Design

ควรใช้รูปแบบนี้:

```text
                    Tailscale
                       │
                       ▼
              ┌─────────────────┐
              │ Workspace :3000 │
              └────────┬────────┘
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
      Gateway :8642        Dashboard :9119
       localhost              localhost
```

ไม่แนะนำ:

```text
Internet
   │
   ├── :3000  Workspace
   ├── :8642  Gateway       ❌
   └── :9119  Dashboard     ❌
```

Gateway และ Dashboard ไม่ควรเปิด public โดยไม่จำเป็น

---

# systemd User Services

Installer ใช้:

```bash
systemctl --user
```

ไม่ใช่:

```bash
systemctl
```

ดังนั้นคำสั่งต้องมี `--user`

ตัวอย่าง:

```bash
systemctl --user restart hermes-gateway
```

---

# Enable Services

ตรวจสอบ:

```bash
systemctl --user is-enabled hermes-gateway
systemctl --user is-enabled hermes-dashboard
systemctl --user is-enabled hermes-workspace
```

ควรได้:

```text
enabled
enabled
enabled
```

---

# Enable Start After Reboot

Installer จะเปิด user lingering:

```bash
sudo loginctl enable-linger $USER
```

ตรวจสอบ:

```bash
loginctl show-user "$USER" | grep Linger
```

ควรได้:

```text
Linger=yes
```

ทำให้ `systemd --user` สามารถเริ่ม service หลัง reboot ได้ แม้ยังไม่ได้ login ผ่าน SSH

---

# Start / Stop / Restart

## Gateway

Start:

```bash
systemctl --user start hermes-gateway
```

Stop:

```bash
systemctl --user stop hermes-gateway
```

Restart:

```bash
systemctl --user restart hermes-gateway
```

---

## Dashboard

```bash
systemctl --user restart hermes-dashboard
```

---

## Workspace

```bash
systemctl --user restart hermes-workspace
```

---

# Restart Everything

แนะนำให้ restart ตามลำดับ:

```bash
systemctl --user restart hermes-gateway
sleep 3

systemctl --user restart hermes-dashboard
sleep 3

systemctl --user restart hermes-workspace
```

หรือ:

```bash
systemctl --user restart hermes-gateway hermes-dashboard hermes-workspace
```

---

# Logs

## Gateway

ดู log แบบ realtime:

```bash
journalctl --user -u hermes-gateway -f
```

ย้อนหลัง:

```bash
journalctl --user -u hermes-gateway -n 200 --no-pager
```

---

## Dashboard

```bash
journalctl --user -u hermes-dashboard -f
```

---

## Workspace

```bash
journalctl --user -u hermes-workspace -f
```

---

# Check Recent Errors

```bash
journalctl --user -u hermes-gateway \
    -u hermes-dashboard \
    -u hermes-workspace \
    -p warning \
    -n 200 \
    --no-pager
```

---

# Hermes CLI

ตรวจสอบ:

```bash
hermes --version
```

ดู help:

```bash
hermes --help
```

ดู config:

```bash
hermes config get
```

Setup:

```bash
hermes setup
```

เลือก model:

```bash
hermes model
```

ตรวจสอบระบบ:

```bash
hermes doctor
```

---

# Hermes Gateway Manual Test

หยุด service ก่อน หากต้องการ debug แบบ foreground:

```bash
systemctl --user stop hermes-gateway
```

จากนั้น:

```bash
hermes gateway run
```

จะเห็น log โดยตรงใน terminal

กด:

```text
Ctrl+C
```

แล้วกลับมา:

```bash
systemctl --user start hermes-gateway
```

---

# Hermes Dashboard Manual Test

หยุด service:

```bash
systemctl --user stop hermes-dashboard
```

รัน:

```bash
hermes dashboard --host 127.0.0.1 --port 9119
```

ทดสอบจาก terminal อีกตัว:

```bash
curl http://127.0.0.1:9119/api/status
```

---

# Workspace Manual Test

หยุด:

```bash
systemctl --user stop hermes-workspace
```

เข้า directory:

```bash
cd ~/hermes-workspace
```

รัน:

```bash
pnpm start
```

หรือสำหรับ development:

```bash
pnpm dev
```

---

# Updating Hermes Agent

Hermes Agent มีคำสั่ง update:

```bash
hermes update
```

หลัง update แนะนำ restart:

```bash
systemctl --user restart hermes-gateway
systemctl --user restart hermes-dashboard
systemctl --user restart hermes-workspace
```

ตรวจสอบ:

```bash
hermes --version
```

---

# Updating Hermes Workspace

เข้า directory:

```bash
cd ~/hermes-workspace
```

ดึง code:

```bash
git pull --ff-only
```

ติดตั้ง dependencies:

```bash
pnpm install
```

build:

```bash
pnpm build
```

restart:

```bash
systemctl --user restart hermes-workspace
```

---

# Full Workspace Update

```bash
cd ~/hermes-workspace

git pull --ff-only

pnpm install

pnpm build

systemctl --user restart hermes-workspace
```

---

# Troubleshooting

## Workspace Offline

ตรวจสอบ Gateway:

```bash
curl http://127.0.0.1:8642/health
```

ตรวจ Dashboard:

```bash
curl http://127.0.0.1:9119/api/status
```

ตรวจ Workspace:

```bash
curl -I http://127.0.0.1:3000
```

ดู logs:

```bash
journalctl --user -u hermes-workspace -n 200 --no-pager
```

---

# 401 Unauthorized / no_cookie

หากพบ:

```text
401
unauthenticated
no_cookie
Unauthorized
```

อย่าเพิ่งแก้ด้วยการปิด authentication แบบสุ่ม

ตรวจสอบ Workspace `.env`:

```bash
cat ~/hermes-workspace/.env
```

และ Hermes environment:

```bash
cat ~/.hermes/.env
```

ค้นหา authentication settings:

```bash
grep -E 'API_SERVER|HERMES_API' ~/.hermes/.env
```

และ:

```bash
grep -E 'HERMES_API|HERMES_DASHBOARD' ~/hermes-workspace/.env
```

ถ้า Hermes Gateway ใช้:

```env
API_SERVER_KEY=...
```

Workspace ต้องได้รับ token เดียวกันผ่าน:

```env
HERMES_API_TOKEN=...
```

ตัวอย่าง:

```env
HERMES_API_TOKEN=YOUR_API_SERVER_KEY
```

จากนั้น:

```bash
systemctl --user restart hermes-gateway
systemctl --user restart hermes-dashboard
systemctl --user restart hermes-workspace
```

---

# Dashboard Not Responding

ตรวจ process:

```bash
ps aux | grep '[h]ermes'
```

ตรวจ port:

```bash
ss -lntp | grep 9119
```

ตรวจ service:

```bash
systemctl --user status hermes-dashboard
```

ดู log:

```bash
journalctl --user -u hermes-dashboard -n 300 --no-pager
```

---

# Gateway Not Responding

```bash
systemctl --user status hermes-gateway
```

```bash
journalctl --user -u hermes-gateway -n 300 --no-pager
```

ตรวจ:

```bash
curl -v http://127.0.0.1:8642/health
```

---

# Port Already in Use

ตรวจสอบ:

```bash
sudo ss -lntp | grep -E ':3000|:8642|:9119'
```

หรือ:

```bash
sudo lsof -i :3000
sudo lsof -i :8642
sudo lsof -i :9119
```

หากมี Hermes process เก่าค้างอยู่ ให้ตรวจ:

```bash
ps aux | grep '[h]ermes'
```

อย่า kill process แบบสุ่มก่อนดูว่าเป็น service ตัวไหน

---

# Firewall

หากใช้ UFW:

```bash
sudo ufw status
```

สำหรับ Tailscale ไม่จำเป็นต้องเปิด ports ให้ Internet

หากต้องการจำกัด Workspace ให้รับเฉพาะ Tailscale ควรพิจารณา firewall policy เพิ่มเติมแทนการเปิด `3000/tcp` ให้ทุก interface

ตรวจ Tailscale interface:

```bash
ip addr show tailscale0
```

---

# Security Recommendations

## 1. ใช้ Tailscale

แนะนำ:

```text
Tailscale
    +
Workspace password
```

แทนการเปิด Workspace public โดยตรง

---

## 2. อย่า expose Gateway

ควรคง:

```text
127.0.0.1:8642
```

---

## 3. อย่า expose Dashboard

ควรคง:

```text
127.0.0.1:9119
```

---

## 4. อย่า commit secrets

ห้าม commit:

```text
.env
~/.hermes/.env
```

ตรวจ:

```bash
git status
```

---

## 5. Protect environment files

```bash
chmod 600 ~/.hermes/.env
chmod 600 ~/hermes-workspace/.env
```

---

# Complete Diagnostic

เมื่อมีปัญหา ให้รัน:

```bash
echo "===== SYSTEM ====="
uname -a
cat /etc/os-release | head

echo
echo "===== NODE ====="
node --version
pnpm --version

echo
echo "===== HERMES ====="
which hermes
hermes --version

echo
echo "===== TAILSCALE ====="
tailscale ip -4 || true
tailscale status || true

echo
echo "===== PORTS ====="
ss -lntp | grep -E ':3000|:8642|:9119' || true

echo
echo "===== SERVICES ====="
systemctl --user --no-pager status \
    hermes-gateway \
    hermes-dashboard \
    hermes-workspace

echo
echo "===== GATEWAY ====="
curl -fsS http://127.0.0.1:8642/health || true

echo
echo "===== DASHBOARD ====="
curl -fsS http://127.0.0.1:9119/api/status || true

echo
echo "===== WORKSPACE ====="
curl -I http://127.0.0.1:3000 || true
```

---

# Useful Commands

## All services

```bash
systemctl --user status hermes-gateway hermes-dashboard hermes-workspace
```

## Restart all

```bash
systemctl --user restart hermes-gateway hermes-dashboard hermes-workspace
```

## Logs all

```bash
journalctl --user \
    -u hermes-gateway \
    -u hermes-dashboard \
    -u hermes-workspace \
    -f
```

## Check ports

```bash
ss -lntp | grep -E ':3000|:8642|:9119'
```

## Check Tailscale

```bash
tailscale ip -4
tailscale status
```

## Check Hermes

```bash
hermes doctor
```

---

# Uninstall

## Stop services

```bash
systemctl --user disable --now hermes-workspace
systemctl --user disable --now hermes-dashboard
systemctl --user disable --now hermes-gateway
```

## Remove systemd units

```bash
rm -f ~/.config/systemd/user/hermes-gateway.service
rm -f ~/.config/systemd/user/hermes-dashboard.service
rm -f ~/.config/systemd/user/hermes-workspace.service

systemctl --user daemon-reload
```

## Remove Workspace

```bash
rm -rf ~/hermes-workspace
```

## Remove Hermes data

**คำเตือน:** ขั้นตอนนี้จะลบ configuration, memory, skills และข้อมูลของ Hermes ที่อยู่ใน `~/.hermes`

```bash
rm -rf ~/.hermes
```

ไม่ควรทำหากต้องการเก็บข้อมูลเดิมไว้

---

# Recommended Production Setup

สำหรับ server ที่ต้องการใช้งานจริง แนะนำ:

```text
Ubuntu 24.04
│
├── Tailscale
│
├── Hermes Agent
│   └── 127.0.0.1:8642
│
├── Hermes Dashboard
│   └── 127.0.0.1:9119
│
├── Hermes Workspace
│   └── 0.0.0.0:3000
│
├── systemd --user
│
└── HERMES_PASSWORD
```

การเข้าถึง:

```text
PC / Phone
     │
     │ Tailscale
     ▼
100.x.x.x:3000
     │
     ▼
Hermes Workspace
     │
     ├── localhost:8642
     └── localhost:9119
```

ไม่จำเป็นต้องใช้ Nginx สำหรับ topology นี้

---

# Official References

## Hermes Agent

https://github.com/NousResearch/hermes-agent

Official documentation:

https://hermes-agent.nousresearch.com/docs/

## Hermes Workspace

https://github.com/outsourc-e/hermes-workspace

Workspace ใช้ Hermes Agent แบบ zero-fork และเชื่อมต่อผ่าน Gateway/Dashboard API

---

# License

Hermes Agent:

MIT

Hermes Workspace:

MIT

โปรดตรวจสอบ license และเงื่อนไขของ dependencies ที่เกี่ยวข้องก่อนนำไปใช้ใน production/commercial environment
