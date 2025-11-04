-- FASE 7 & 9: Adicionar billing_configs e coordenadas para roteamento

-- 1. Criar tabela de configurações de cobrança
CREATE TABLE public.billing_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES public.tenants(id) NOT NULL,
  billing_type TEXT NOT NULL CHECK (billing_type IN ('percentage', 'monthly')),
  value NUMERIC NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id)
);

-- 2. Adicionar coordenadas aos pedidos (FASE 9 - roteamento)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS latitude NUMERIC;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS longitude NUMERIC;

-- 3. Adicionar índices para performance
CREATE INDEX IF NOT EXISTS idx_orders_tenant_status ON public.orders(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_driver_status ON public.orders(assigned_driver, status);
CREATE INDEX IF NOT EXISTS idx_driver_sessions_driver_dates ON public.driver_sessions(driver_id, started_at, ended_at);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON public.orders(client_id);

-- 4. RLS para billing_configs
ALTER TABLE public.billing_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin master can manage billing configs"
ON public.billing_configs FOR ALL
USING (has_role(auth.uid(), 'admin_master'::app_role));

CREATE POLICY "Company admins can view own billing config"
ON public.billing_configs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.tenant_id = billing_configs.tenant_id
  )
  AND has_role(auth.uid(), 'company_admin'::app_role)
);