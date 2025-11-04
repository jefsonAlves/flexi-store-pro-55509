import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { toast } from "sonner";
import { Package, LogOut, Truck, Users, BarChart3 } from "lucide-react";
import { ProductList } from "@/components/company/ProductList";
import { DriversList } from "@/components/company/DriversList";
import { OrdersManagement } from "@/components/company/OrdersManagement";
import { DriverSessionsReport } from "@/components/company/DriverSessionsReport";
import { RevenueReport } from "@/components/company/RevenueReport";

const CompanyDashboard = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<any>(null);
  const [tenantId, setTenantId] = useState<string>("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        navigate("/auth/login");
        return;
      }

      setUser(session.user);

      // Buscar tenant_id do perfil
      const { data: profileData, error: profileError } = await supabase
        .from("profiles")
        .select("tenant_id")
        .eq("id", session.user.id)
        .single();

      if (profileError) throw profileError;
      if (profileData?.tenant_id) {
        setTenantId(profileData.tenant_id);
      }
    } catch (error) {
      console.error("Erro ao verificar autenticação:", error);
      navigate("/auth/login");
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    toast.success("Logout realizado com sucesso!");
    navigate("/");
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p>Carregando...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/30 to-background">
      {/* HEADER */}
      <header className="bg-card border-b">
        <div className="container mx-auto px-4 h-16 flex items-center justify-between">
          <h1 className="text-xl font-bold">Painel da Empresa</h1>
          <Button variant="ghost" size="sm" onClick={handleLogout}>
            <LogOut className="h-4 w-4 mr-2" />
            Sair
          </Button>
        </div>
      </header>

      {/* CONTEÚDO */}
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-7xl mx-auto">
          <Tabs defaultValue="produtos" className="w-full">
            <TabsList className="grid w-full grid-cols-4 mb-8">
              <TabsTrigger value="produtos">
                <Package className="h-4 w-4 mr-2" />
                Produtos
              </TabsTrigger>
              <TabsTrigger value="motoristas">
                <Truck className="h-4 w-4 mr-2" />
                Motoristas
              </TabsTrigger>
              <TabsTrigger value="pedidos">
                <BarChart3 className="h-4 w-4 mr-2" />
                Pedidos
              </TabsTrigger>
              <TabsTrigger value="relatorios">
                <Users className="h-4 w-4 mr-2" />
                Relatórios
              </TabsTrigger>
            </TabsList>

            <TabsContent value="produtos">
              {tenantId && <ProductList tenantId={tenantId} />}
            </TabsContent>

            <TabsContent value="motoristas">
              {tenantId && <DriversList tenantId={tenantId} />}
            </TabsContent>

            <TabsContent value="pedidos">
              <Card className="p-6">
                <h2 className="text-2xl font-bold mb-4">Pedidos</h2>
                <p className="text-muted-foreground">
                  Funcionalidade de gestão de pedidos em desenvolvimento.
                </p>
              </Card>
            </TabsContent>

            <TabsContent value="relatorios">
              <Card className="p-6">
                <h2 className="text-2xl font-bold mb-4">Relatórios</h2>
                <p className="text-muted-foreground">
                  Funcionalidade de relatórios em desenvolvimento.
                </p>
              </Card>
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  );
};

export default CompanyDashboard;