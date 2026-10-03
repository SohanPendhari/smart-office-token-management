@echo off
REM Creates the database, schema and seed data (Windows). Usage: setup.bat [pg_user] [db_name]
REM Requires psql on PATH, e.g. C:\Program Files\PostgreSQL\16\bin
set PGU=%1
if "%PGU%"=="" set PGU=postgres
set DB=%2
if "%DB%"=="" set DB=smart_office
cd /d "%~dp0"
psql -U %PGU% -c "CREATE DATABASE %DB%" 2>nul
psql -U %PGU% -d %DB% -v ON_ERROR_STOP=1 -f schema.sql || exit /b 1
psql -U %PGU% -d %DB% -v ON_ERROR_STOP=1 -f seed.sql || exit /b 1
echo Database %DB% is ready.
