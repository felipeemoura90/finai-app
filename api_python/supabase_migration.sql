-- =============================================================
-- FinAI - Migration: Adicionar coluna fitid à tabela transactions
-- =============================================================
-- Execute este script no Supabase Dashboard > SQL Editor
-- =============================================================

-- 1. Adiciona a coluna fitid (idempotente: não falha se já existir)
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS fitid TEXT;

-- 2. Garante unicidade por combinação fitid + user_id.
--    Isso permite que dois usuários diferentes importem um extrato
--    com o mesmo FITID sem conflito, mas evita que o mesmo
--    usuário insira a mesma transação duas vezes.
ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS transactions_fitid_user_unique;

ALTER TABLE transactions
  ADD CONSTRAINT transactions_fitid_user_unique
  UNIQUE (fitid, user_id);

-- 3. Verificação: mostra a estrutura final da tabela
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'transactions'
-- ORDER BY ordinal_position;
