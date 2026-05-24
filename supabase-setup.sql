-- ============================================================
-- BENCHSCORE — SUPABASE SETUP SCRIPT
-- Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ────────────────────────────────────────────
-- 1. TABLES
-- ────────────────────────────────────────────

create table if not exists public.profiles (
  id         uuid references auth.users(id) on delete cascade primary key,
  username   text unique not null,
  fav_sport  text default 'nba',
  created_at timestamptz default now()
);

create table if not exists public.games (
  id          text primary key,
  sport       text not null,
  league      text,
  home        text not null,
  away        text not null,
  home_score  integer,
  away_score  integer,
  date        date,
  venue       text,
  description text,
  video_url   text default '',
  tags        text[] default '{}',
  created_by  uuid references auth.users(id),
  created_at  timestamptz default now()
);

create table if not exists public.reviews (
  id         uuid primary key default gen_random_uuid(),
  game_id    text references public.games(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete cascade not null,
  username   text not null,
  rating     integer check (rating between 1 and 5),
  body       text default '',
  video_url  text default '',
  created_at timestamptz default now(),
  unique(game_id, user_id)
);

create table if not exists public.likes (
  review_id  uuid references public.reviews(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete cascade,
  primary key (review_id, user_id)
);

create table if not exists public.watchlist (
  game_id    text references public.games(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete cascade,
  primary key (game_id, user_id),
  created_at timestamptz default now()
);

-- ────────────────────────────────────────────
-- 2. ROW LEVEL SECURITY
-- ────────────────────────────────────────────

alter table public.profiles  enable row level security;
alter table public.games     enable row level security;
alter table public.reviews   enable row level security;
alter table public.likes     enable row level security;
alter table public.watchlist enable row level security;

-- Profiles: public read, owner write
create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- Games: public read, any authenticated user can add
create policy "games_select" on public.games for select using (true);
create policy "games_insert" on public.games for insert with check (auth.role() = 'authenticated');

-- Reviews: public read, owner write/delete
create policy "reviews_select" on public.reviews for select using (true);
create policy "reviews_insert" on public.reviews for insert with check (auth.uid() = user_id);
create policy "reviews_update" on public.reviews for update using (auth.uid() = user_id);
create policy "reviews_delete" on public.reviews for delete using (auth.uid() = user_id);

-- Likes: public read, owner write/delete
create policy "likes_select" on public.likes for select using (true);
create policy "likes_insert" on public.likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.likes for delete using (auth.uid() = user_id);

-- Watchlist: private to owner
create policy "watchlist_select" on public.watchlist for select using (auth.uid() = user_id);
create policy "watchlist_insert" on public.watchlist for insert with check (auth.uid() = user_id);
create policy "watchlist_delete" on public.watchlist for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────
-- 3. AUTO-CREATE PROFILE ON SIGNUP
-- ────────────────────────────────────────────

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, fav_sport)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'fav_sport', 'nba')
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ────────────────────────────────────────────
-- 4. SEED GAMES (25 iconic matchups)
-- ────────────────────────────────────────────

insert into public.games (id, sport, league, home, away, home_score, away_score, date, venue, description, video_url, tags) values
('g1','nba','nba','Los Angeles Lakers','Boston Celtics',112,108,'2025-06-15','Crypto.com Arena','NBA Finals Game 7. LeBron James dropped 38 points in a legendary closeout.','',ARRAY['playoffs','classic']),
('g2','nba','nba','Golden State Warriors','Miami Heat',98,101,'2025-05-20','Chase Center','Heat stun the Warriors in overtime with a Jimmy Butler buzzer-beater.','',ARRAY['overtime','upset']),
('g3','nfl','nfl','Kansas City Chiefs','San Francisco 49ers',24,21,'2025-02-02','Caesars Superdome','Super Bowl LX. Chiefs win their fourth title in five years.','',ARRAY['super bowl','dynasty']),
('g4','nfl','nfl','Philadelphia Eagles','Dallas Cowboys',34,28,'2025-01-18','Lincoln Financial Field','NFC Championship. Jalen Hurts leads a miraculous 4th quarter comeback.','',ARRAY['comeback','rivalry']),
('g5','mlb','mlb','New York Yankees','Boston Red Sox',7,4,'2025-07-04','Yankee Stadium','July 4th fireworks rivaled by a 3-homer night from Aaron Judge.','',ARRAY['rivalry','home run']),
('g6','mlb','mlb','Los Angeles Dodgers','Houston Astros',3,2,'2025-10-25','Dodger Stadium','World Series Game 6. Shohei Ohtani pitches 8 shutout innings before closing.','',ARRAY['world series','classic']),
('g7','nhl','nhl','Edmonton Oilers','Florida Panthers',4,3,'2025-06-22','Rogers Place','Stanley Cup Final Game 7. Connor McDavid ends a 30-year Cup drought for Edmonton.','',ARRAY['stanley cup','game 7']),
('g8','nhl','nhl','Colorado Avalanche','Toronto Maple Leafs',5,2,'2025-04-10','Ball Arena','Cale Makar records 4 assists in a dominant playoff opener.','',ARRAY['playoffs']),
('g9','soccer','ucl','Real Madrid','Manchester City',3,3,'2025-04-30','Santiago Bernabéu','UCL Semi-Final second leg. Real Madrid advance on aggregate in a breathtaking match.','',ARRAY['ucl','classic']),
('g10','soccer','epl','Arsenal','Chelsea',2,1,'2025-05-11','Emirates Stadium','Premier League title decider. Arsenal clinch the title with a Saka winner.','',ARRAY['title race','derby']),
('g11','nba','nba','Denver Nuggets','Oklahoma City Thunder',115,120,'2025-05-05','Ball Arena','OKC stun Denver with a 3rd-quarter blitz behind Shai Gilgeous-Alexander (42pts).','',ARRAY['playoffs','performance']),
('g12','nfl','nfl','Buffalo Bills','Miami Dolphins',31,29,'2025-12-20','Highmark Stadium','Snow game classic. Josh Allen throws for 300 yards in a whiteout.','',ARRAY['weather','classic']),
('g13','mlb','mlb','Chicago Cubs','St. Louis Cardinals',9,8,'2025-08-15','Wrigley Field','12-inning thriller with 4 lead changes in the final 3 innings.','',ARRAY['rivalry','extra innings']),
('g14','nhl','nhl','Boston Bruins','New York Rangers',2,3,'2025-05-15','TD Garden','OT winner by Panarin sends the Blueshirts to the second round.','',ARRAY['overtime','playoffs']),
('g15','soccer','laliga','Barcelona','Atletico Madrid',4,2,'2025-03-15','Camp Nou','Lamine Yamal hat-trick in a magnificent La Liga showdown.','',ARRAY['laliga','hat-trick']),
('g16','nba','nba','Dallas Mavericks','Minnesota Timberwolves',108,106,'2025-05-25','American Airlines Center','Luka Doncic goes for 44-12-10 in a must-win Game 5.','',ARRAY['playoffs','triple-double']),
('g17','mlb','mlb','Atlanta Braves','New York Mets',1,0,'2025-09-28','Truist Park','Spencer Strider throws a complete game shutout to clinch the NL East.','',ARRAY['clincher','shutout']),
('g18','soccer','ucl','Liverpool','Real Madrid',2,2,'2025-04-16','Anfield','Champions League QF first leg. Salah and Vinicius both score twice in a classic.','',ARRAY['ucl','classic']),
('g19','nhl','nhl','Vegas Golden Knights','Dallas Stars',3,2,'2025-06-05','T-Mobile Arena','WCF Game 6. Vegas clinch the series with a late power play goal.','',ARRAY['playoffs','power play']),
('g20','nfl','nfl','Detroit Lions','Green Bay Packers',42,17,'2025-11-28','Ford Field','Thanksgiving blowout. Jared Goff leads the Lions to an emphatic win.','',ARRAY['thanksgiving','rivalry']),
('g21','nba','nba','Boston Celtics','Indiana Pacers',133,128,'2025-05-14','TD Garden','Five-overtime thriller in the Eastern Conference Finals. Jrue Holiday hits the winner.','',ARRAY['overtime','classic','ecf']),
('g22','soccer','epl','Manchester City','Tottenham Hotspur',4,0,'2025-03-29','Etihad Stadium','Erling Haaland bags four in a dominant City performance.','',ARRAY['hat-trick','dominant']),
('g23','nfl','nfl','Baltimore Ravens','Pittsburgh Steelers',27,26,'2025-01-11','M&T Bank Stadium','Wild Card classic. Lamar Jackson drives 85 yards in the final minute.','',ARRAY['rivalry','comeback','wild card']),
('g24','nhl','nhl','Toronto Maple Leafs','Boston Bruins',4,3,'2025-04-28','Scotiabank Arena','Game 7 classic. Auston Matthews ends a two-decade playoff drought against Boston.','',ARRAY['game 7','rivalry','playoffs']),
('g25','soccer','laliga','Real Madrid','Atletico Madrid',2,1,'2025-02-08','Santiago Bernabéu','El Derecho. Mbappé heads the winner in the 89th minute to silence the away end.','',ARRAY['derby','last minute','laliga'])
on conflict (id) do nothing;
