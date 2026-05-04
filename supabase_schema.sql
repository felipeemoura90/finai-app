-- Execute este script no painel do Supabase (SQL Editor)

CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    data TIMESTAMP WITH TIME ZONE NOT NULL,
    descricao TEXT NOT NULL,
    valor NUMERIC(10, 2) NOT NULL,
    categoria TEXT,
    icon TEXT,
    raw_data TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Configurando Row Level Security (RLS)
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Política para permitir que usuários vejam apenas suas próprias transações
CREATE POLICY "Users can view their own transactions"
ON public.transactions FOR SELECT
USING (auth.uid() = user_id);

-- Política para permitir que usuários insiram suas próprias transações
CREATE POLICY "Users can insert their own transactions"
ON public.transactions FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Política para permitir que usuários atualizem suas próprias transações
CREATE POLICY "Users can update their own transactions"
ON public.transactions FOR UPDATE
USING (auth.uid() = user_id);

-- Política para permitir que usuários deletem suas próprias transações
CREATE POLICY "Users can delete their own transactions"
ON public.transactions FOR DELETE
USING (auth.uid() = user_id);
