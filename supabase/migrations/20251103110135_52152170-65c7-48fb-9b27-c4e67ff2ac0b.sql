-- Criar tabela para rastrear sessões de disponibilidade dos motoristas
CREATE TABLE IF NOT EXISTS public.driver_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Índices para melhorar performance
CREATE INDEX idx_driver_sessions_driver_id ON public.driver_sessions(driver_id);
CREATE INDEX idx_driver_sessions_tenant_id ON public.driver_sessions(tenant_id);
CREATE INDEX idx_driver_sessions_started_at ON public.driver_sessions(started_at);

-- Habilitar RLS
ALTER TABLE public.driver_sessions ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
CREATE POLICY "Company admins can view tenant driver sessions"
  ON public.driver_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = driver_sessions.tenant_id
    )
    AND has_role(auth.uid(), 'company_admin'::app_role)
  );

CREATE POLICY "Drivers can view own sessions"
  ON public.driver_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers
      WHERE drivers.id = driver_sessions.driver_id
      AND drivers.user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can insert own sessions"
  ON public.driver_sessions
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.drivers
      WHERE drivers.id = driver_sessions.driver_id
      AND drivers.user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can update own sessions"
  ON public.driver_sessions
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.drivers
      WHERE drivers.id = driver_sessions.driver_id
      AND drivers.user_id = auth.uid()
    )
  );

-- Adicionar coluna de endereço no perfil do cliente se não existir
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS address JSONB;

-- Função para atualizar updated_at se não existir
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at em driver_sessions (não precisa pois não tem updated_at)