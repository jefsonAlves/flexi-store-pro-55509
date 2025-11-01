-- =====================================================
-- FASE 1: CORREÇÃO DE SEGURANÇA - SEPARAR ROLES
-- Ordem correta: criar nova estrutura, dropar policies antigas, remover coluna, criar novas policies
-- =====================================================

-- 1. Criar tabela user_roles (roles NÃO podem estar na tabela profiles)
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  UNIQUE (user_id, role)
);

-- 2. Habilitar RLS na user_roles
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- 3. Criar função SECURITY DEFINER para verificar roles (evita recursão RLS)
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- 4. Migrar roles existentes da profiles para user_roles
INSERT INTO public.user_roles (user_id, role)
SELECT id, role FROM public.profiles
WHERE role IS NOT NULL
ON CONFLICT (user_id, role) DO NOTHING;

-- =====================================================
-- DROPAR TODAS AS POLICIES QUE DEPENDEM DE role
-- =====================================================

-- PROFILES
DROP POLICY IF EXISTS "Admin master can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- TENANTS
DROP POLICY IF EXISTS "Admin master can manage all tenants" ON public.tenants;
DROP POLICY IF EXISTS "Company admins can view own tenant" ON public.tenants;

-- AUDIT_LOGS
DROP POLICY IF EXISTS "Admin master can view all audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Company admins can view tenant audit logs" ON public.audit_logs;

-- DRIVERS
DROP POLICY IF EXISTS "Company admins can manage drivers" ON public.drivers;
DROP POLICY IF EXISTS "Drivers can view own profile" ON public.drivers;

-- CLIENTS
DROP POLICY IF EXISTS "Company admins can view tenant clients" ON public.clients;
DROP POLICY IF EXISTS "Clients can manage own profile" ON public.clients;

-- PRODUCTS
DROP POLICY IF EXISTS "Company admins can manage own products" ON public.products;
DROP POLICY IF EXISTS "Clients can view active products" ON public.products;

-- ORDERS
DROP POLICY IF EXISTS "Company admins can manage tenant orders" ON public.orders;
DROP POLICY IF EXISTS "Clients can create orders" ON public.orders;
DROP POLICY IF EXISTS "Clients can view own orders" ON public.orders;
DROP POLICY IF EXISTS "Drivers can view assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Drivers can update assigned orders" ON public.orders;

-- ORDER_ITEMS
DROP POLICY IF EXISTS "Users can view order items of accessible orders" ON public.order_items;

-- 5. Remover coluna role da profiles (agora pode remover com segurança)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS role CASCADE;

-- 6. Adicionar coluna user_type para identificar tipo de cadastro
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_type TEXT;

-- =====================================================
-- CRIAR NOVAS POLICIES USANDO has_role()
-- =====================================================

-- PROFILES
CREATE POLICY "Admin master can view all profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin_master'));

CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id);

-- TENANTS
CREATE POLICY "Admin master can manage all tenants"
ON public.tenants FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin_master'));

CREATE POLICY "Company admins can view own tenant"
ON public.tenants FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = tenants.id
  ) AND public.has_role(auth.uid(), 'company_admin')
);

-- AUDIT_LOGS
CREATE POLICY "Admin master can view all audit logs"
ON public.audit_logs FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin_master'));

CREATE POLICY "Company admins can view tenant audit logs"
ON public.audit_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = audit_logs.tenant_id
  ) AND public.has_role(auth.uid(), 'company_admin')
);

-- DRIVERS
CREATE POLICY "Company admins can manage drivers"
ON public.drivers FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = drivers.tenant_id
  ) AND public.has_role(auth.uid(), 'company_admin')
);

CREATE POLICY "Drivers can view own profile"
ON public.drivers FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- CLIENTS
CREATE POLICY "Company admins can view tenant clients"
ON public.clients FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = clients.tenant_id
  ) AND public.has_role(auth.uid(), 'company_admin')
);

CREATE POLICY "Clients can manage own profile"
ON public.clients FOR ALL
TO authenticated
USING (auth.uid() = user_id);

-- PRODUCTS
CREATE POLICY "Company admins can manage own products"
ON public.products FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = products.tenant_id
  ) AND public.has_role(auth.uid(), 'company_admin')
);

CREATE POLICY "Clients can view active products"
ON public.products FOR SELECT
TO authenticated
USING (
  active = true AND
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = products.tenant_id
  )
);

-- ORDERS
CREATE POLICY "Company admins can manage tenant orders"
ON public.orders FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.tenant_id = orders.tenant_id
  ) AND public.has_role(auth.uid(), 'company_admin')
);

CREATE POLICY "Clients can create orders"
ON public.orders FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.clients
    WHERE clients.id = orders.client_id
      AND clients.user_id = auth.uid()
  )
);

CREATE POLICY "Clients can view own orders"
ON public.orders FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.clients
    WHERE clients.id = orders.client_id
      AND clients.user_id = auth.uid()
  )
);

CREATE POLICY "Drivers can view assigned orders"
ON public.orders FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.drivers
    WHERE drivers.id = orders.assigned_driver
      AND drivers.user_id = auth.uid()
  )
);

CREATE POLICY "Drivers can update assigned orders"
ON public.orders FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.drivers
    WHERE drivers.id = orders.assigned_driver
      AND drivers.user_id = auth.uid()
  )
);

-- ORDER_ITEMS
CREATE POLICY "Users can view order items of accessible orders"
ON public.order_items FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id = order_items.order_id
      AND (
        EXISTS (
          SELECT 1 FROM public.clients
          WHERE clients.id = orders.client_id
            AND clients.user_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id = auth.uid()
            AND profiles.tenant_id = orders.tenant_id
            AND (
              public.has_role(auth.uid(), 'company_admin')
              OR public.has_role(auth.uid(), 'driver')
            )
        )
      )
  )
);

-- USER_ROLES
CREATE POLICY "Admin master can manage all roles"
ON public.user_roles FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin_master'));

CREATE POLICY "Users can view own roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- =====================================================
-- TRIGGER PARA AUTO-CRIAR PROFILE E ROLE AO REGISTRAR
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, user_type)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'user_type', 'client')
  );
  
  -- Inserir role baseado no user_type
  INSERT INTO public.user_roles (user_id, role)
  VALUES (
    NEW.id,
    CASE 
      WHEN NEW.raw_user_meta_data->>'user_type' = 'company' THEN 'company_admin'::app_role
      WHEN NEW.raw_user_meta_data->>'user_type' = 'driver' THEN 'driver'::app_role
      ELSE 'client'::app_role
    END
  );
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();