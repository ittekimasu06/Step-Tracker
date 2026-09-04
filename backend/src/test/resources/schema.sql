-- Mirrors the production PostgreSQL schema so Hibernate's `validate` catches any
-- drift between the JPA entities and the real database.
DROP TABLE IF EXISTS hourly_steps;
DROP TABLE IF EXISTS daily_steps;
DROP TABLE IF EXISTS user_profiles;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES users(id),
  full_name VARCHAR(255),
  age INTEGER,
  weight_kg DECIMAL(5,2),
  height_cm DECIMAL(5,2),
  gender VARCHAR(20),
  profile_completed BOOLEAN DEFAULT FALSE,
  step_goal INTEGER,
  active_minutes_goal INTEGER,
  calorie_goal INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE daily_steps (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  step_date DATE NOT NULL,
  step_count INTEGER NOT NULL DEFAULT 0,
  active_minutes INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_daily_steps_user_date UNIQUE (user_id, step_date)
);

CREATE TABLE hourly_steps (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  step_date DATE NOT NULL,
  hour_of_day INTEGER NOT NULL,
  step_count INTEGER NOT NULL DEFAULT 0,
  active_minutes INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_hourly_steps_user_date_hour UNIQUE (user_id, step_date, hour_of_day)
);
