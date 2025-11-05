-- FASE 2 & 3: Ajustar estrutura e atualizar trigger

-- Tornar tenant_id nullable em clients (multi-tenant)
ALTER TABLE public.clients ALTER COLUMN tenant_id DROP NOT NULL;

-- Tornar tenant_id nullable em drivers
ALTER TABLE public.drivers ALTER COLUMN tenant_id DROP NOT NULL;

-- Atualizar trigger para criar registros nas tabelas corretas
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_tenant_id uuid;
BEGIN
  -- Inserir perfil base
  INSERT INTO public.profiles (id, email, full_name, user_type, phone, cpf, tenant_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'user_type', 'client'),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'cpf', ''),
    NULL -- Multi-tenant: clientes não têm tenant_id fixo
  )
  ON CONFLICT (id) DO NOTHING;
  
  -- Processar baseado no tipo de usuário
  CASE NEW.raw_user_meta_data->>'user_type'
    
    -- COMPANY: criar tenant e associar
    WHEN 'company' THEN
      INSERT INTO public.tenants (name, cnpj, email, phone, status)
      VALUES (
        COALESCE(NEW.raw_user_meta_data->>'company_name', 'Nova Empresa'),
        COALESCE(NEW.raw_user_meta_data->>'cnpj', ''),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        'ACTIVE'
      )
      RETURNING id INTO new_tenant_id;
      
      -- Atualizar profile com tenant_id
      UPDATE public.profiles 
      SET tenant_id = new_tenant_id 
      WHERE id = NEW.id;
      
      -- Inserir role company_admin
      INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, 'company_admin'::app_role)
      ON CONFLICT (user_id, role) DO NOTHING;
    
    -- DRIVER: criar registro de driver
    WHEN 'driver' THEN
      INSERT INTO public.drivers (user_id, name, cpf, phone, vehicle, status)
      VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'cpf', ''),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        COALESCE(NEW.raw_user_meta_data->>'vehicle', '')::vehicle_type,
        'INACTIVE'::driver_status
      );
      
      -- Inserir role driver
      INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, 'driver'::app_role)
      ON CONFLICT (user_id, role) DO NOTHING;
    
    -- CLIENT: criar registro de cliente
    ELSE
      INSERT INTO public.clients (user_id, full_name, email, phone, cpf)
      VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        COALESCE(NEW.raw_user_meta_data->>'cpf', '')
      )
      ON CONFLICT DO NOTHING;
      
      -- Inserir role client
      INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, 'client'::app_role)
      ON CONFLICT (user_id, role) DO NOTHING;
  END CASE;
  
  RETURN NEW;
END;
$$;

-- FASE 4: Migration corretiva - criar registros de clients faltantes
INSERT INTO public.clients (user_id, full_name, email, phone, cpf)
SELECT 
  ur.user_id,
  COALESCE(p.full_name, ''),
  p.email,
  COALESCE(p.phone, ''),
  COALESCE(p.cpf, '')
FROM public.user_roles ur
LEFT JOIN public.profiles p ON p.id = ur.user_id
LEFT JOIN public.clients c ON c.user_id = ur.user_id
WHERE ur.role = 'client'::app_role
  AND c.id IS NULL
ON CONFLICT DO NOTHING;