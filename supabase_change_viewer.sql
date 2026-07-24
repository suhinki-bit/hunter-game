-- ============================================================
--  열람자 계정 변경
--    변경 전 : sketchmemoax / 1234ax
--    변경 후 : aumleeax     / aumleeax!
--
--  Supabase 대시보드 > SQL Editor 에 붙여넣고 RUN 하세요.
--  관리자(sketchmemo1) · 팀원(sketchmemo2) 계정은 건드리지 않습니다.
--  여러 번 실행해도 안전합니다.
-- ============================================================

create extension if not exists pgcrypto;

do $$
declare
  v_email    text := 'aumleeax@sketchmemo.app';
  v_pw       text := 'aumleeax!';
  v_username text := 'aumleeax';
  uid        uuid;
begin
  -- 1) 구 열람자 계정 삭제 (identities 는 cascade 로 함께 삭제됨)
  delete from auth.users where email = 'sketchmemoax@sketchmemo.app';

  -- 2) 동일 계정이 이미 있으면 제거 후 재생성
  delete from auth.users where email = v_email;

  uid := gen_random_uuid();

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000',
    uid, 'authenticated', 'authenticated', v_email,
    crypt(v_pw, gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('username', v_username, 'role', 'viewer'),
    '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), uid,
    jsonb_build_object('sub', uid::text, 'email', v_email),
    'email', v_email,
    now(), now(), now()
  );
end $$;

-- ------------------------------------------------------------
-- 확인용: 현재 계정 목록
-- ------------------------------------------------------------
select
  raw_user_meta_data ->> 'username' as 아이디,
  raw_user_meta_data ->> 'role'     as 권한,
  email                             as 로그인이메일
from auth.users
where email like '%@sketchmemo.app'
order by 2;
