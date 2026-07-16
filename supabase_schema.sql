-- 사냥꾼 게임 랭킹 테이블
create table scores (
  id bigint generated always as identity primary key,
  nickname text not null check (char_length(nickname) between 1 and 20),
  score integer not null check (score >= 0),
  difficulty text not null check (difficulty in ('easy', 'normal', 'hard')),
  created_at timestamptz not null default now()
);

-- 익명 사용자도 읽고 쓸 수 있도록 RLS 활성화 + 정책 추가
alter table scores enable row level security;

create policy "누구나 점수를 등록할 수 있음"
  on scores for insert
  to anon
  with check (true);

create policy "누구나 랭킹을 조회할 수 있음"
  on scores for select
  to anon
  using (true);

-- 상위 점수 조회를 빠르게 하기 위한 인덱스
create index scores_score_idx on scores (score desc);
