# ออมสุข (OmSook) — deploy บน Vercel

## 1) เตรียม Supabase
1. สร้างโปรเจกต์ใหม่ที่ https://supabase.com
2. SQL Editor → วางไฟล์ `supabase-schema.sql` ทั้งไฟล์ → Run
3. Authentication → Providers → เปิด **Google** แล้วใส่ Client ID / Secret
   (สร้างที่ Google Cloud Console → OAuth client → Web application,
   Authorized redirect URI = `https://<project-ref>.supabase.co/auth/v1/callback`)
4. Authentication → URL Configuration → Site URL = โดเมน Vercel ของคุณ และเพิ่มโดเมนนั้นใน Redirect URLs
5. Settings → API → คัดลอก **Project URL** และ **anon public key**

## 2) Deploy ขึ้น Vercel
- ลากโฟลเดอร์นี้ทั้งโฟลเดอร์เข้า https://vercel.com/new (เลือก Other / no framework)
- หรือรัน `npx vercel --prod` ในโฟลเดอร์นี้
- ⚠️ ต้องอัพโหลด **index.html และ support.js คู่กัน** เสมอ

## 3) ตั้งค่าครั้งแรก
เปิดเว็บ → **ฉันเป็นคุณครู** → กด "ตั้งค่าการเชื่อมต่อฐานข้อมูล (Supabase)" → วาง Project URL + anon key → บันทึก → **เข้าสู่ระบบด้วย Google**

## ความปลอดภัย
- **ครู**: Google OAuth + Row Level Security — เห็นและแก้ได้เฉพาะห้องของตัวเองและห้องที่ถูกเชิญเป็นครูผู้ช่วย
- **นักเรียน**: ไม่มีบัญชี เข้าผ่านรหัสห้อง 6 หลัก + PIN 4 ตัว เรียกได้แค่ฟังก์ชันอ่านข้อมูล (read-only) — ตารางจริงถูกล็อกด้วย RLS ทั้งหมด แก้ไขอะไรไม่ได้
- anon key เป็นคีย์สาธารณะ ปลอดภัยที่จะฝังในหน้าเว็บ
