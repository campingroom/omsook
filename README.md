# ออมสุข · OmSook

โปรแกรมออมเงินนักเรียน — ครูบันทึกรายวัน, พิมพ์แบบบันทึกการออมเงินตามแบบราชการ, นักเรียนดูยอดตัวเองด้วยรหัสห้อง + PIN

ไฟล์ในโฟลเดอร์นี้เป็นเว็บสถิต ไม่ต้อง build ไม่ต้อง npm install

```
index.html    ตัวแอปทั้งหมด
support.js    ไลบรารีรันไทม์ที่แอปเรียกใช้
vercel.json   ตั้งค่า deploy (static)
```

## 1) ขึ้น GitHub

```bash
git init
git add .
git commit -m "OmSook: student savings app"
git branch -M main
git remote add origin https://github.com/<user>/omsook.git
git push -u origin main
```

หรือใช้ GitHub Desktop / กด "Add file → Upload files" บนหน้าเว็บ GitHub ก็ได้

## 2) ต่อ Vercel

1. vercel.com → Add New → Project → Import จาก GitHub repo นี้
2. Framework Preset: **Other**
3. Build Command: เว้นว่าง · Output Directory: เว้นว่าง (root)
4. Deploy → จะได้โดเมน เช่น `omsook.vercel.app`

ถ้าไฟล์อยู่ในโฟลเดอร์ย่อยของ repo ให้ตั้ง **Root Directory** เป็นโฟลเดอร์นั้น

## 3) ต่อ Supabase

1. Supabase → SQL Editor → วางไฟล์ `supabase-schema.sql` ทั้งไฟล์ → Run
   (ในไฟล์มีบรรทัดกำหนดอีเมลผู้ดูแลระบบ — แก้ให้เป็นอีเมลของคุณก่อนรัน)
2. Authentication → Providers → เปิด **Google**
   - Authorized redirect URI ใน Google Cloud Console:
     `https://<project-ref>.supabase.co/auth/v1/callback`
3. Authentication → URL Configuration
   - Site URL: `https://<โดเมน-vercel>`
   - Additional Redirect URLs: `https://<โดเมน-vercel>/**`
4. เปิดเว็บที่ deploy แล้ว → หน้าเข้าสู่ระบบครู → ใส่ **Project URL** และ **anon public key**
   (Settings → API) ครั้งเดียว ค่าจะถูกจำไว้ในเครื่องนั้น
5. เมื่อครูเข้ามาครบแล้ว: Authentication → Sign In / Providers → ปิด
   *Allow new users to sign up* คนนอกจะสมัครเพิ่มไม่ได้

anon key เป็นคีย์สาธารณะ ปลอดภัยที่จะอยู่ในเบราว์เซอร์ — ความปลอดภัยจริงมาจาก RLS
และ allowlist ครูในตาราง `teacher_access` / `app_admins`

## 4) สิทธิ์เข้าใช้

- อีเมลใน `app_admins` = ผู้ดูแลระบบ เห็นปุ่ม 🔐 ผู้ดูแลระบบ บนหน้าห้องเรียน
- ครูคนอื่นที่ล็อกอินเข้ามาจะอยู่สถานะ "รออนุมัติ" ใช้งานไม่ได้จนผู้ดูแลกดอนุมัติ
- นักเรียนไม่ต้องมีบัญชี — เข้าด้วยรหัสห้อง + เลือกชื่อ + PIN 4 ตัว (เก็บเป็น bcrypt hash,
  ใส่ผิดเกิน 5 ครั้ง/10 นาที จะถูกหยุดชั่วคราว)

built by campingroom —
