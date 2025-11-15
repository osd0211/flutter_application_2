import pandas as pd
from pathlib import Path

ROOT_DIR = Path(__file__).parent
RAW_DIR = ROOT_DIR / "data_raw"
OUT_DIR = ROOT_DIR / "data_prepared"
OUT_DIR.mkdir(exist_ok=True)

print("Reading CSV files from:", RAW_DIR)

# --- 1) Load raw CSVs ---

header = pd.read_csv(RAW_DIR / "euroleague_header.csv")
teams = pd.read_csv(RAW_DIR / "euroleague_teams.csv")
players = pd.read_csv(RAW_DIR / "euroleague_players.csv")
box = pd.read_csv(RAW_DIR / "euroleague_box_score.csv")

print("Shapes:")
print(" header:", header.shape)
print(" teams:", teams.shape)
print(" players:", players.shape)
print(" box:", box.shape)

# --- 2) Detect season column & filter last season ---

season_col = None
for cand in ["season", "Season", "SEASON", "season_code", "SeasonCode", "SEASON_CODE"]:
    if cand in header.columns:
        season_col = cand
        break

if season_col is None:
    print("Header columns:", header.columns.tolist())
    raise RuntimeError("Season/season_code column not found in euroleague_header.csv")

latest_season = header[season_col].max()
print("Using season:", latest_season)

header = header[header[season_col] == latest_season].copy()

# --- 3) Detect key columns (game, teams, scores) ---

def pick(colnames, candidates, required=True, label=""):
    for c in candidates:
        if c in colnames:
            return c
    if required:
        print("Available columns:", colnames)
        raise RuntimeError(f"Could not find column for {label} (candidates={candidates})")
    return None

# header mapping
h_game_id   = pick(header.columns, ["game_id", "GAME_ID", "Game_ID", "GameId"], label="game_id")
h_date      = pick(header.columns, ["date", "Date", "GAME_DATE"], label="game_date")
h_time      = pick(header.columns, ["time", "Time", "GAME_TIME"], required=False, label="game_time")

h_home_team_id = pick(
    header.columns,
    ["home_team_id", "HomeTeamID", "HOME_TEAM_ID", "home_team_code", "HomeTeamCode", "team_id_a"],
    required=False,
    label="home_team_id",
)
h_away_team_id = pick(
    header.columns,
    ["away_team_id", "AwayTeamID", "AWAY_TEAM_ID", "away_team_code", "AwayTeamCode", "team_id_b"],
    required=False,
    label="away_team_id",
)

# takım isimleri – dataset’te 'team_a', 'team_b' var
h_home_name = pick(
    header.columns,
    ["home_team", "Home_Team", "home", "HOME", "HomeTeam", "team_a"],
    required=False,
    label="home_team_name",
)
h_away_name = pick(
    header.columns,
    ["away_team", "Away_Team", "away", "AWAY", "AwayTeam", "team_b"],
    required=False,
    label="away_team_name",
)

# skorlar – dataset’te 'score_a', 'score_b' var
h_home_pts = pick(
    header.columns,
    ["home_score", "Home_Score", "PTS_HOME", "home_pts", "ScoreHome", "score_a"],
    required=False,
    label="home_score",
)
h_away_pts = pick(
    header.columns,
    ["away_score", "Away_Score", "PTS_AWAY", "away_pts", "ScoreAway", "score_b"],
    required=False,
    label="away_score",
)


# --- 3) Detect key columns (game, teams, scores) ---

# teams mapping
t_id = pick(teams.columns, ["team_id", "Team_ID", "TEAM_ID", "TeamId"], label="team_id")
t_name = pick(
    teams.columns,
    ["team_name", "Team", "team", "Team_Name"],
    required=False,
    label="team_name",
)

teams_small = None
if t_name is not None:
    teams_small = teams[[t_id, t_name]].drop_duplicates()
    teams_small.columns = ["team_id", "team_name"]
else:
    print("⚠ No team_name column in euroleague_teams.csv, skipping team-name merge from this file.")


# players mapping
p_id   = pick(players.columns, ["player_id", "Player_ID", "PLAYER_ID", "PlayerId"], label="player_id")
p_name = pick(players.columns, ["player_name", "Player", "player", "Player_Name"], label="player_name")
p_team = pick(players.columns, ["team_id", "Team_ID", "TEAM_ID", "TeamId"], required=False, label="player_team_id")

players_cols = [p_id, p_name]
new_cols = ["player_id", "player_name"]
if p_team:
    players_cols.append(p_team)
    new_cols.append("team_id")

players_small = players[players_cols].drop_duplicates()
players_small.columns = new_cols

# box-score mapping
b_game_id = pick(box.columns, ["game_id", "GAME_ID", "Game_ID", "GameId"], label="box_game_id")
b_player_id = pick(box.columns, ["player_id", "Player_ID", "PLAYER_ID", "PlayerId"], label="box_player_id")
b_team_id = pick(box.columns, ["team_id", "Team_ID", "TEAM_ID", "TeamId"], required=False, label="box_team_id")

# Kaggle kolonları genelde küçük harf: 'points', 'assists', 'total_rebounds'
b_pts = pick(box.columns, ["PTS", "Points", "pts", "points"], required=False, label="PTS")
b_ast = pick(box.columns, ["AST", "Assists", "ast", "assists"], required=False, label="AST")
b_reb = pick(
    box.columns,
    ["REB", "TRB", "Rebounds", "reb", "total_rebounds"],
    required=False,
    label="REB",
)


box_cols = [b_game_id, b_player_id]
box_new = ["game_id", "player_id"]

if b_team_id:
    box_cols.append(b_team_id)
    box_new.append("team_id")
if b_pts:
    box_cols.append(b_pts)
    box_new.append("pts")
if b_ast:
    box_cols.append(b_ast)
    box_new.append("ast")
if b_reb:
    box_cols.append(b_reb)
    box_new.append("reb")

box_small = box[box_cols].copy()
box_small.columns = box_new

# --- 4) Merge everything into one flat table: one row = (game, player) ---

# merge header + box-score on game_id
df = box_small.merge(
    header[[h_game_id, h_date] + ([h_time] if h_time else []) +
           ([h_home_name] if h_home_name else []) +
           ([h_away_name] if h_away_name else []) +
           ([h_home_pts] if h_home_pts else []) +
           ([h_away_pts] if h_away_pts else [])],
    left_on="game_id",
    right_on=h_game_id,
    how="left",
)

# merge teams (for player team name) – only if we actually built teams_small
if "team_id" in df.columns and teams_small is not None:
    df = df.merge(
        teams_small,
        on="team_id",
        how="left",
    )


# merge players (for player name)
df = df.merge(
    players_small,
    on="player_id",
    how="left",
)

# rename columns to a clean, app-friendly schema
rename_map = {
    h_date: "game_date",
}
if h_time:
    rename_map[h_time] = "game_time"
if h_home_name:
    rename_map[h_home_name] = "home_team_name"
if h_away_name:
    rename_map[h_away_name] = "away_team_name"
if h_home_pts:
    rename_map[h_home_pts] = "home_score"
if h_away_pts:
    rename_map[h_away_pts] = "away_score"
if "team_name" in df.columns:
    rename_map["team_name"] = "player_team_name"

df = df.rename(columns=rename_map)

# keep only useful columns
keep_cols = ["game_id", "game_date"]

if "game_time" in df.columns:
    keep_cols.append("game_time")

# these may or may not exist, check first
for col in [
    "home_team_name",
    "away_team_name",
    "home_score",
    "away_score",
    "player_id",
    "player_name",
    "player_team_name",
]:
    if col in df.columns:
        keep_cols.append(col)

for stat_col in ["pts", "ast", "reb"]:
    if stat_col in df.columns:
        keep_cols.append(stat_col)

df = df[keep_cols]


# --- 5) Save one big flat file + daily files ---

flat_path = OUT_DIR / "euroleague_flat.csv"
df.to_csv(flat_path, index=False)
print("Saved flat file:", flat_path)

# group by date and save per-day csv (for app usage)
days_dir = OUT_DIR / "by_day"
days_dir.mkdir(exist_ok=True)

unique_dates = sorted(df["game_date"].dropna().unique())
print("Unique game dates:", len(unique_dates))

for d in unique_dates:
    day_df = df[df["game_date"] == d]
    safe = str(d).replace("/", "-").replace(".", "-")
    day_path = days_dir / f"boxscores_{safe}.csv"
    day_df.to_csv(day_path, index=False)

print("Saved per-day files into:", days_dir)

print("✅ Done.")
