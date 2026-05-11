@echo off
REM Script de desenvolvimento local do FinAI Flutter
REM Injeta as variáveis de ambiente do Supabase via --dart-define
REM
REM Como usar:
REM   1. Preencha os valores SUPABASE_URL e SUPABASE_ANON_KEY abaixo
REM   2. Execute este script no terminal: .\run_dev.bat

set SUPABASE_URL=https://seu-projeto.supabase.co
set SUPABASE_ANON_KEY=sua_anon_key_aqui

flutter run -d web-server --web-port 3000 ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
