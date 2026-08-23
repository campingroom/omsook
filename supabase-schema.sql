-- ============================================================
--  ออมสุข (OmSook) — Supabase schema
--  วิธีใช้: Supabase Dashboard → SQL Editor → วางทั้งไฟล์ → Run
-- ============================================================
create extension if not exists "pgcrypto";

-- ---------- ตาราง ----------
create table if not exists public.teachers (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text,
  created_at   timestamptz default now()
);

create table if not exists public.classrooms (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  academic_year int  not null,
  join_code     text not null unique,
  share_totals  boolean not null default true,
  goal_amount   numeric default 0,
  teacher_sig   text default '',
  principal_sig text default '',
  archived      boolean default false,
  created_at    timestamptz default now()
);

-- เดือนที่ปิดบัญชีแล้ว (ล็อกการแก้ยอด) — รูปแบบ 'YYYY-MM'
alter table public.classrooms add column if not exists closed_months text[] default '{}';

-- ครูผู้ช่วยร่วมห้อง (เชิญด้วยอีเมล)
create table if not exists public.classroom_members (
  classroom_id  uuid not null references public.classrooms(id) on delete cascade,
  teacher_email text not null,
  role          text default 'assistant',
  created_at    timestamptz default now(),
  primary key (classroom_id, teacher_email)
);

create table if not exists public.students (
  id              uuid primary key default gen_random_uuid(),
  classroom_id    uuid not null references public.classrooms(id) on delete cascade,
  student_code    text not null,
  no              int,
  full_name       text not null,
  nickname        text default '',
  pin             text default '',
  opening_balance numeric default 0,
  active          boolean default true,
  created_at      timestamptz default now(),
  unique (classroom_id, student_code)
);

-- 1 แถว = ยอดของนักเรียน 1 คน ใน 1 วัน 1 ประเภท
create table if not exists public.transactions (
  id           uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  student_id   uuid not null references public.students(id) on delete cascade,
  tx_date      date not null,
  amount       numeric not null,
  kind         text not null default 'deposit',   -- deposit | withdraw
  note         text default '',
  created_by   uuid,
  created_at   timestamptz default now(),
  unique (student_id, tx_date, kind)
);

create table if not exists public.audit_log (
  id           bigserial primary key,
  classroom_id uuid references public.classrooms(id) on delete cascade,
  actor        text,
  action       text,
  detail       text,
  created_at   timestamptz default now()
);

create index if not exists tx_class_date_idx on public.transactions(classroom_id, tx_date);
create index if not exists students_class_idx on public.students(classroom_id);
create index if not exists audit_class_idx    on public.audit_log(classroom_id, created_at desc);

-- ---------- สิทธิ์: ครูเจ้าของห้อง หรือ ครูผู้ช่วยที่ถูกเชิญ ----------
create or replace function public.can_edit_class(cid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from classrooms c where c.id = cid and c.owner_id = auth.uid())
      or exists (select 1 from classroom_members m
                  where m.classroom_id = cid
                    and lower(m.teacher_email) = lower(coalesce(auth.jwt() ->> 'email','~')));
$$;

alter table public.teachers          enable row level security;
alter table public.classrooms        enable row level security;
alter table public.classroom_members enable row level security;
alter table public.students          enable row level security;
alter table public.transactions      enable row level security;
alter table public.audit_log         enable row level security;

drop policy if exists teachers_self on public.teachers;
create policy teachers_self on public.teachers
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ให้ครูผู้ช่วยอ่านชื่อ/อีเมลของครูเจ้าของห้องที่ตัวเองเข้าถึงได้ (เพื่อแสดงป้ายบนการ์ดห้อง)
drop policy if exists teachers_owner_visible on public.teachers;
create policy teachers_owner_visible on public.teachers
  for select to authenticated using (
    id = auth.uid()
    or exists (select 1 from classrooms c where c.owner_id = teachers.id and public.can_edit_class(c.id))
  );

drop policy if exists class_read on public.classrooms;
create policy class_read on public.classrooms
  for select to authenticated using (public.can_edit_class(id));
drop policy if exists class_insert on public.classrooms;
create policy class_insert on public.classrooms
  for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists class_update on public.classrooms;
create policy class_update on public.classrooms
  for update to authenticated using (public.can_edit_class(id));
drop policy if exists class_delete on public.classrooms;
create policy class_delete on public.classrooms
  for delete to authenticated using (owner_id = auth.uid());

drop policy if exists members_rw on public.classroom_members;
create policy members_rw on public.classroom_members
  for all to authenticated
  using (exists (select 1 from classrooms c where c.id = classroom_id and c.owner_id = auth.uid()))
  with check (exists (select 1 from classrooms c where c.id = classroom_id and c.owner_id = auth.uid()));

drop policy if exists students_rw on public.students;
create policy students_rw on public.students
  for all to authenticated
  using (public.can_edit_class(classroom_id)) with check (public.can_edit_class(classroom_id));

drop policy if exists tx_rw on public.transactions;
create policy tx_rw on public.transactions
  for all to authenticated
  using (public.can_edit_class(classroom_id)) with check (public.can_edit_class(classroom_id));

drop policy if exists audit_rw on public.audit_log;
create policy audit_rw on public.audit_log
  for all to authenticated
  using (public.can_edit_class(classroom_id)) with check (public.can_edit_class(classroom_id));

-- ---------- สิทธิ์เข้าใช้ระดับครู: allowlist + รออนุมัติ ----------
create table if not exists public.app_admins (
  email text primary key
);

create table if not exists public.teacher_access (
  email        text primary key,
  status       text not null default 'pending' check (status in ('pending','approved','blocked')),
  note         text,
  requested_at timestamptz not null default now(),
  decided_at   timestamptz,
  decided_by   text
);

-- ⚠️ อีเมลผู้ดูแลระบบ (เพิ่ม/เปลี่ยนได้ที่นี่)
insert into public.app_admins (email) values ('campingroom@gmail.com') on conflict do nothing;
insert into public.teacher_access (email, status, decided_at, decided_by)
  select email, 'approved', now(), 'system' from public.app_admins
  on conflict (email) do update set status = 'approved';

create or replace function public.my_email()
returns text language sql stable set search_path = public as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from app_admins a where lower(a.email) = public.my_email());
$$;

create or replace function public.is_approved()
returns boolean language sql security definer stable set search_path = public as $$
  select public.is_admin()
      or exists (select 1 from teacher_access t
                  where lower(t.email) = public.my_email() and t.status = 'approved');
$$;

-- สถานะของตัวเอง (แอปเรียกหลังล็อกอิน)
create or replace function public.my_access()
returns json language sql security definer stable set search_path = public as $$
  select json_build_object(
    'email', public.my_email(),
    'is_admin', public.is_admin(),
    'status', coalesce((select t.status from teacher_access t where lower(t.email) = public.my_email()),
                       case when public.is_admin() then 'approved' else 'pending' end)
  );
$$;

alter table public.app_admins     enable row level security;
alter table public.teacher_access enable row level security;

drop policy if exists admins_read on public.app_admins;
create policy admins_read on public.app_admins
  for select to authenticated using (public.is_admin());

drop policy if exists access_self on public.teacher_access;
create policy access_self on public.teacher_access
  for select to authenticated using (lower(email) = public.my_email() or public.is_admin());
drop policy if exists access_admin_write on public.teacher_access;
create policy access_admin_write on public.teacher_access
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- บันทึกคำขอเข้าใช้เมื่อล็อกอินครั้งแรก (สถานะ pending — ใช้งานยังไม่ได้)
create or replace function public.request_access(p_note text default null)
returns json language plpgsql security definer set search_path = public as $$
begin
  if public.my_email() = '' then return json_build_object('error','ไม่พบอีเมล'); end if;
  insert into teacher_access (email, status, note)
       values (public.my_email(), 'pending', p_note)
  on conflict (email) do update set note = coalesce(excluded.note, teacher_access.note);
  return public.my_access();
end $$;

grant execute on function public.my_access() to authenticated;
grant execute on function public.request_access(text) to authenticated;

-- ปิดทางการเข้าถึงข้อมูลห้องเรียนสำหรับคนที่ยังไม่ได้รับอนุมัติ
create or replace function public.can_edit_class(cid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select public.is_approved() and (
    exists (select 1 from classrooms c where c.id = cid and c.owner_id = auth.uid())
    or exists (select 1 from classroom_members m
                join auth.users u on lower(u.email) = lower(m.teacher_email)
               where m.classroom_id = cid and u.id = auth.uid())
  );
$$;

drop policy if exists class_insert on public.classrooms;
create policy class_insert on public.classrooms
  for insert to authenticated with check (owner_id = auth.uid() and public.is_approved());
drop policy if exists class_delete on public.classrooms;
create policy class_delete on public.classrooms
  for delete to authenticated using (owner_id = auth.uid() and public.is_approved());

drop policy if exists members_rw on public.classroom_members;
create policy members_rw on public.classroom_members
  for all to authenticated
  using (public.is_approved() and exists (select 1 from classrooms c where c.id = classroom_id and c.owner_id = auth.uid()))
  with check (public.is_approved() and exists (select 1 from classrooms c where c.id = classroom_id and c.owner_id = auth.uid()));

-- ---------- ฝั่งนักเรียน: อ่านได้เท่านั้น ผ่านฟังก์ชันเท่านั้น ----------
-- 1) ขอรายชื่อ (ชื่อเล่น + เลขที่) ของห้องจากรหัสห้อง — ไม่มียอดเงินติดมา
create or replace function public.class_roster_public(p_code text)
returns json language sql security definer stable set search_path = public as $$
  select json_build_object(
    'classroom', (select json_build_object('name', c.name, 'year', c.academic_year)
                    from classrooms c
                   where upper(c.join_code) = upper(trim(p_code)) and not coalesce(c.archived,false)),
    'students', coalesce((select json_agg(json_build_object('id', s.id, 'no', s.no, 'nickname', s.nickname, 'name', s.full_name) order by s.no)
                            from students s join classrooms c on c.id = s.classroom_id
                           where upper(c.join_code) = upper(trim(p_code)) and coalesce(s.active,true)), '[]'::json)
  );
$$;

-- 2) เข้าดูยอดของตัวเอง (+ ตารางรวมห้อง ถ้าครูเปิดให้เห็น)
-- PIN: เก็บ hash ไว้ใน pin_hash (bcrypt) — ช่องทางนักเรียนตรวจกับ hash เท่านั้น
create extension if not exists pgcrypto;
alter table public.students add column if not exists pin_hash text;

create or replace function public.hash_student_pin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.pin is not null and new.pin <> '' then
    if tg_op = 'INSERT' or new.pin is distinct from old.pin then
      new.pin_hash := crypt(new.pin, gen_salt('bf', 8));
    end if;
  else
    new.pin_hash := null;
  end if;
  return new;
end $$;

drop trigger if exists students_hash_pin on public.students;
create trigger students_hash_pin before insert or update on public.students
  for each row execute function public.hash_student_pin();

-- เติม hash ให้ข้อมูลเดิม
update public.students set pin_hash = crypt(pin, gen_salt('bf', 8))
 where coalesce(pin,'') <> '' and pin_hash is null;

-- กันเดา PIN: เก็บประวัติการพยายามเข้า
create table if not exists public.login_attempts (
  id         bigserial primary key,
  student_id uuid,
  join_code  text,
  ok         boolean not null default false,
  at         timestamptz not null default now()
);
create index if not exists login_attempts_lookup on public.login_attempts (student_id, at desc);
alter table public.login_attempts enable row level security;

create or replace function public.student_portal(p_code text, p_student uuid, p_pin text)
returns json language plpgsql security definer set search_path = public as $$
declare v_class classrooms; v_stu students; v_res json; v_fail int; v_ok boolean;
begin
  select c.* into v_class from classrooms c
   where upper(c.join_code) = upper(trim(p_code)) and not coalesce(c.archived,false);
  if v_class.id is null then return json_build_object('error','ไม่พบรหัสห้องนี้'); end if;

  select s.* into v_stu from students s
   where s.id = p_student and s.classroom_id = v_class.id and coalesce(s.active,true);
  if v_stu.id is null then return json_build_object('error','ไม่พบชื่อนักเรียนในห้องนี้'); end if;

  select count(*) into v_fail from login_attempts
   where student_id = v_stu.id and not ok and at > now() - interval '10 minutes';
  if v_fail >= 5 then
    return json_build_object('error','ใส่ PIN ผิดหลายครั้งเกินไป — รออีก 10 นาทีแล้วลองใหม่');
  end if;

  if coalesce(v_stu.pin_hash,'') <> '' then
    v_ok := (v_stu.pin_hash = crypt(coalesce(trim(p_pin),''), v_stu.pin_hash));
  elsif coalesce(v_stu.pin,'') <> '' then
    v_ok := (v_stu.pin = coalesce(trim(p_pin),''));
  else
    v_ok := true;
  end if;

  if not v_ok then
    insert into login_attempts (student_id, join_code, ok) values (v_stu.id, p_code, false);
    return json_build_object('error','PIN ไม่ถูกต้อง');
  end if;
  insert into login_attempts (student_id, join_code, ok) values (v_stu.id, p_code, true);

  select json_build_object(
    'classroom', json_build_object('name', v_class.name, 'year', v_class.academic_year,
                                   'shareTotals', v_class.share_totals, 'goal', v_class.goal_amount),
    'student', json_build_object('id', v_stu.id, 'no', v_stu.no, 'name', v_stu.full_name,
                                 'nickname', v_stu.nickname, 'opening', v_stu.opening_balance),
    'tx', coalesce((select json_agg(json_build_object('date', t.tx_date, 'amount', t.amount, 'kind', t.kind) order by t.tx_date desc)
                      from transactions t where t.student_id = v_stu.id), '[]'::json),
    'table', case when v_class.share_totals then coalesce((
       select json_agg(json_build_object('no', x.no, 'nickname', x.nickname, 'name', x.full_name, 'total', x.total, 'opening', x.opening) order by x.no)
         from (select s2.no, s2.nickname, s2.full_name, coalesce(s2.opening_balance,0) as opening,
                      coalesce(s2.opening_balance,0) + coalesce((select sum(case when t2.kind = 'withdraw' then -t2.amount else t2.amount end)
                                                                  from transactions t2 where t2.student_id = s2.id),0) as total
                 from students s2 where s2.classroom_id = v_class.id and coalesce(s2.active,true)) x
       ), '[]'::json) else null end,
    'classTx', case when v_class.share_totals then coalesce((
       select json_agg(json_build_object('no', s3.no, 'date', t3.tx_date, 'amount', t3.amount, 'kind', t3.kind))
         from transactions t3 join students s3 on s3.id = t3.student_id
        where s3.classroom_id = v_class.id and coalesce(s3.active,true)
       ), '[]'::json) else null end
  ) into v_res;
  return v_res;
end $$;

revoke all on function public.class_roster_public(text) from public;
revoke all on function public.student_portal(text, uuid, text) from public;
grant execute on function public.class_roster_public(text) to anon, authenticated;
grant execute on function public.student_portal(text, uuid, text) to anon, authenticated;

-- ---------- เปิด realtime ให้แอปรีเฟรชเองเมื่อครูอีกคนบันทึก (รันซ้ำได้) ----------
do $$ begin
  alter publication supabase_realtime add table public.transactions;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.students;
exception when duplicate_object then null; end $$;

create or replace function public.handle_new_teacher()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.teachers (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_teacher();
