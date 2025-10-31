
-- Migration: 20251030134610
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types
CREATE TYPE app_role AS ENUM ('admin_master', 'company_admin', 'driver', 'client');
CREATE TYPE order_status AS ENUM ('PENDENTE', 'ACEITO', 'EM_PREPARO', 'A_CAMINHO', 'NA_PORTA', 'ENTREGUE', 'CANCELADO');
CREATE TYPE payment_method AS ENUM ('PIX', 'CARD', 'CASH');
CREATE TYPE payment_status AS ENUM ('PENDING', 'PAID', 'FAILED');
CREATE TYPE tenant_status AS ENUM ('ACTIVE', 'SUSPENDED');
CREATE TYPE driver_status AS ENUM ('INACTIVE', 'ACTIVE', 'ONLINE', 'IN_SERVICE');
CREATE TYPE product_type AS ENUM ('product', 'service');
CREATE TYPE vehicle_type AS ENUM ('MOTO', 'CARRO', 'BICICLETA', 'A_PE');

-- Profiles table (extends Supabase Auth users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone TEXT,
  cpf TEXT,
  role app_role NOT NULL,
  tenant_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Tenants (empresas/instâncias)
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  cnpj TEXT,
  email TEXT,
  phone TEXT,
  domain TEXT UNIQUE,
  primary_color TEXT DEFAULT '#3b82f6',
  secondary_color TEXT DEFAULT '#f59e0b',
  logo_url TEXT,
  banner_urls TEXT[],
  status tenant_status DEFAULT 'ACTIVE' NOT NULL,
  plan TEXT DEFAULT 'basic',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Products
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  category TEXT,
  type product_type DEFAULT 'product' NOT NULL,
  description TEXT,
  price NUMERIC(12,2) NOT NULL,
  stock INTEGER DEFAULT 0 NOT NULL,
  prepare_time_minutes INTEGER DEFAULT 15 NOT NULL,
  images TEXT[],
  active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Drivers
CREATE TABLE drivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  cpf TEXT,
  phone TEXT,
  vehicle vehicle_type,
  plate TEXT,
  photo_url TEXT,
  status driver_status DEFAULT 'INACTIVE' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Clients
CREATE TABLE clients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  cpf TEXT,
  phone TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Orders
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES clients(id) NOT NULL,
  total NUMERIC(12,2) NOT NULL,
  payment_method payment_method NOT NULL,
  payment_status payment_status DEFAULT 'PENDING' NOT NULL,
  change_for NUMERIC(12,2),
  address JSONB NOT NULL,
  status order_status DEFAULT 'PENDENTE' NOT NULL,
  assigned_driver UUID REFERENCES drivers(id),
  cancel_reason TEXT,
  eta_minutes INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  accepted_at TIMESTAMPTZ,
  preparing_at TIMESTAMPTZ,
  on_way_at TIMESTAMPTZ,
  at_door_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Order Items
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES products(id),
  name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Audit Logs (somente INSERT por service_role)
CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  actor_id UUID,
  action TEXT NOT NULL,
  resource TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Profiles
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admin master can view all profiles" ON profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin_master')
);

-- RLS Policies for Tenants
CREATE POLICY "Admin master can manage all tenants" ON tenants FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin_master')
);
CREATE POLICY "Company admins can view own tenant" ON tenants FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = tenants.id AND role = 'company_admin')
);

-- RLS Policies for Products
CREATE POLICY "Company admins can manage own products" ON products FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = products.tenant_id AND role = 'company_admin')
);
CREATE POLICY "Clients can view active products" ON products FOR SELECT USING (
  active = true AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = products.tenant_id)
);

-- RLS Policies for Drivers
CREATE POLICY "Company admins can manage drivers" ON drivers FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = drivers.tenant_id AND role = 'company_admin')
);
CREATE POLICY "Drivers can view own profile" ON drivers FOR SELECT USING (
  auth.uid() = user_id
);

-- RLS Policies for Clients
CREATE POLICY "Clients can manage own profile" ON clients FOR ALL USING (
  auth.uid() = user_id
);
CREATE POLICY "Company admins can view tenant clients" ON clients FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = clients.tenant_id AND role = 'company_admin')
);

-- RLS Policies for Orders
CREATE POLICY "Clients can view own orders" ON orders FOR SELECT USING (
  EXISTS (SELECT 1 FROM clients WHERE id = orders.client_id AND user_id = auth.uid())
);
CREATE POLICY "Clients can create orders" ON orders FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM clients WHERE id = orders.client_id AND user_id = auth.uid())
);
CREATE POLICY "Company admins can manage tenant orders" ON orders FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = orders.tenant_id AND role = 'company_admin')
);
CREATE POLICY "Drivers can view assigned orders" ON orders FOR SELECT USING (
  EXISTS (SELECT 1 FROM drivers WHERE id = orders.assigned_driver AND user_id = auth.uid())
);
CREATE POLICY "Drivers can update assigned orders" ON orders FOR UPDATE USING (
  EXISTS (SELECT 1 FROM drivers WHERE id = orders.assigned_driver AND user_id = auth.uid())
);

-- RLS Policies for Order Items
CREATE POLICY "Users can view order items of accessible orders" ON order_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM orders WHERE id = order_items.order_id AND (
      EXISTS (SELECT 1 FROM clients WHERE id = orders.client_id AND user_id = auth.uid()) OR
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = orders.tenant_id AND role IN ('company_admin', 'driver'))
    )
  )
);

-- RLS Policies for Audit Logs (somente service_role pode inserir)
CREATE POLICY "Only service_role can insert audit logs" ON audit_logs FOR INSERT WITH CHECK (false);
CREATE POLICY "Admin master can view all audit logs" ON audit_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin_master')
);
CREATE POLICY "Company admins can view tenant audit logs" ON audit_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND tenant_id = audit_logs.tenant_id AND role = 'company_admin')
);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed data: Admin Master (Jeffson)
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'jefson.ti@gmail.com',
  crypt('81864895', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Jeffson Admin Master"}'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, email, full_name, phone, cpf, role, tenant_id)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'jefson.ti@gmail.com',
  'Jeffson Admin Master',
  '(62) 98209-4069',
  '009.958.453-01',
  'admin_master',
  NULL
)
ON CONFLICT (id) DO NOTHING;

-- Create indexes for performance
CREATE INDEX idx_products_tenant_id ON products(tenant_id);
CREATE INDEX idx_products_active ON products(active);
CREATE INDEX idx_orders_tenant_id ON orders(tenant_id);
CREATE INDEX idx_orders_client_id ON orders(client_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_drivers_tenant_id ON drivers(tenant_id);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_clients_tenant_id ON clients(tenant_id);
CREATE INDEX idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
