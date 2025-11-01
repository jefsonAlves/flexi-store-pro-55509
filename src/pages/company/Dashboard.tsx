import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { toast } from "sonner";
import { Package, Users, Truck, LogOut, BarChart3 } from "lucide-react";

const CompanyDashboard = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<any>(null);
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
        <div className="max-w-6xl mx-auto space-y-6">
          <Card className="p-6">
            <h2 className="text-2xl font-bold mb-4">Bem-vindo, Empresa!</h2>
            <p className="text-muted-foreground mb-6">
              Gerencie seus produtos, pedidos e entregadores em um só lugar.
            </p>

            <div className="grid md:grid-cols-4 gap-4">
              <Card className="p-4 text-center hover:shadow-lg transition-smooth">
                <Package className="h-8 w-8 text-primary mx-auto mb-2" />
                <p className="text-sm font-medium">Produtos</p>
                <p className="text-2xl font-bold">0</p>
              </Card>

              <Card className="p-4 text-center hover:shadow-lg transition-smooth">
                <BarChart3 className="h-8 w-8 text-accent mx-auto mb-2" />
                <p className="text-sm font-medium">Pedidos Hoje</p>
                <p className="text-2xl font-bold">0</p>
              </Card>

              <Card className="p-4 text-center hover:shadow-lg transition-smooth">
                <Truck className="h-8 w-8 text-secondary mx-auto mb-2" />
                <p className="text-sm font-medium">Entregadores</p>
                <p className="text-2xl font-bold">0</p>
              </Card>

              <Card className="p-4 text-center hover:shadow-lg transition-smooth">
                <Users className="h-8 w-8 text-primary mx-auto mb-2" />
                <p className="text-sm font-medium">Clientes</p>
                <p className="text-2xl font-bold">0</p>
              </Card>
            </div>
          </Card>

          <Card className="p-6">
            <h3 className="font-semibold mb-4">Funcionalidades em Desenvolvimento</h3>
            <div className="grid md:grid-cols-2 gap-4">
              <div className="p-4 border rounded-lg">
                <h4 className="font-medium mb-2">📦 Gestão de Produtos</h4>
                <p className="text-sm text-muted-foreground">Cadastre água e gás com preços e estoque</p>
              </div>
              <div className="p-4 border rounded-lg">
                <h4 className="font-medium mb-2">📋 Pedidos</h4>
                <p className="text-sm text-muted-foreground">Visualize e gerencie pedidos em tempo real</p>
              </div>
              <div className="p-4 border rounded-lg">
                <h4 className="font-medium mb-2">🚚 Entregadores</h4>
                <p className="text-sm text-muted-foreground">Cadastre e monitore sua equipe</p>
              </div>
              <div className="p-4 border rounded-lg">
                <h4 className="font-medium mb-2">📊 Relatórios</h4>
                <p className="text-sm text-muted-foreground">Analise o desempenho do seu negócio</p>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default CompanyDashboard;