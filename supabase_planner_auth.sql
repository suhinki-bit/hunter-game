-- ============================================================
--  일정 관리 + 스케치 앱 : 로그인 & 공유 보드 설정
--  Supabase 대시보드 > SQL Editor 에 붙여넣고 RUN 하세요.
--  (여러 번 실행해도 안전합니다 / 재실행 시 계정이 재생성됩니다)
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1) 계정 3개 생성
--    관리자 sketchmemo1 / 팀원 sketchmemo2 / 열람자 sketchmemoax
--    로그인 시 앱이 아이디 뒤에 @sketchmemo.app 을 자동으로 붙입니다.
-- ------------------------------------------------------------
do $$
declare
  acct record;
  uid  uuid;
begin
  for acct in
    select * from (values
      ('sketchmemo1@sketchmemo.app',  '1234',   'sketchmemo1',  'admin'),
      ('sketchmemo2@sketchmemo.app',  '4321',   'sketchmemo2',  'editor'),
      ('sketchmemoax@sketchmemo.app', '1234ax', 'sketchmemoax', 'viewer')
    ) as t(email, pw, username, role)
  loop
    -- 기존 동일 계정 제거 (identities 는 cascade 로 함께 삭제)
    delete from auth.users where email = acct.email;

    uid := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000',
      uid, 'authenticated', 'authenticated', acct.email,
      crypt(acct.pw, gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', acct.username, 'role', acct.role),
      '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid,
      jsonb_build_object('sub', uid::text, 'email', acct.email),
      'email', acct.email,
      now(), now(), now()
    );
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2) 공유 보드 테이블 (스케치 / 백버너 / 오늘 / 내일)
--    모든 계정이 같은 'main' 보드를 함께 봅니다.
-- ------------------------------------------------------------
create table if not exists public.boards (
  id         text primary key,
  sketch     jsonb not null default '[]'::jsonb,
  burner     jsonb not null default '[]'::jsonb,
  today      jsonb not null default '[]'::jsonb,
  tomorrow   jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by text
);

insert into public.boards (id) values ('main')
  on conflict (id) do nothing;

alter table public.boards enable row level security;

-- 기존 정책 정리 후 재생성
drop policy if exists "로그인 사용자만 조회"     on public.boards;
drop policy if exists "관리자와 팀원만 수정"     on public.boards;

-- 로그인한 계정은 모두 읽기 가능 (열람자 포함)
create policy "로그인 사용자만 조회"
  on public.boards for select
  to authenticated
  using (true);

-- 쓰기는 admin / editor 만. 열람자(viewer)는 서버에서 차단됨.
create policy "관리자와 팀원만 수정"
  on public.boards for update
  to authenticated
  using      ((auth.jwt() -> 'user_metadata' ->> 'role') in ('admin', 'editor'))
  with check ((auth.jwt() -> 'user_metadata' ->> 'role') in ('admin', 'editor'));

-- ------------------------------------------------------------
-- 3) 실시간 동기화 활성화 (다른 사람 수정이 즉시 반영)
-- ------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.boards;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- ------------------------------------------------------------
-- 확인용: 생성된 계정 조회
-- ------------------------------------------------------------
select
  raw_user_meta_data ->> 'username' as 아이디,
  raw_user_meta_data ->> 'role'     as 권한,
  email                             as 로그인이메일
from auth.users
where email like '%@sketchmemo.app'
order by 2;


-- ============================================================
--  [참고] 나중에 비밀번호를 바꾸고 싶을 때 (권장)
--  아래 주석을 풀고 '새비밀번호' 부분만 수정해서 실행하세요.
-- ============================================================
-- update auth.users
--    set encrypted_password = crypt('새비밀번호', gen_salt('bf'))
--  where email = 'sketchmemo1@sketchmemo.app';
