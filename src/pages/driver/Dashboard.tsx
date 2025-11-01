import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { toast } from "sonner";
import { MapPin, Package, Clock, LogOut } from "lucide-react";

const DriverDashboard = () => {
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
          <h1 className="text-xl font-bold">Minhas Entregas</h1>
          <Button variant="ghost" size="sm" onClick={handleLogout}>
            <LogOut className="h-4 w-4 mr-2" />
            Sair
          </Button>
        </div>
      </header>

      {/* CONTEÚDO */}
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto space-y-6">
          <Card className="p-6">
            <h2 className="text-2xl font-bold mb-4">Bem-vindo, Entregador!</h2>
            <p className="text-muted-foreground mb-6">
              Gerencie suas entregas e atualize o status em tempo real.
            </p>

            <div className="grid md:grid-cols-3 gap-4 mb-6">
              <Card className="p-4 text-center">
                <Package className="h-8 w-8 text-primary mx-auto mb-2" />
                <p className="text-sm font-medium">Entregas Pendentes</p>
                <p className="text-2xl font-bold">0</p>
              </Card>

              <Card className="p-4 text-center">
                <MapPin className="h-8 w-8 text-accent mx-auto mb-2" />
                <p className="text-sm font-medium">Em Rota</p>
                <p className="text-2xl font-bold">0</p>
              </Card>

              <Card className="p-4 text-center">
                <Clock className="h-8 w-8 text-secondary mx-auto mb-2" />
                <p className="text-sm font-medium">Concluídas Hoje</p>
                <p className="text-2xl font-bold">0</p>
              </Card>
            </div>

            <div className="border rounded-lg p-4">
              <h3 className="font-semibold mb-2">📱 App em Desenvolvimento</h3>
              <p className="text-sm text-muted-foreground">
                Em breve você poderá:
              </p>
              <ul className="text-sm text-muted-foreground mt-2 space-y-1">
                <li>• Receber notificações de novas entregas</li>
                <li>• Visualizar rotas no mapa</li>
                <li>• Atualizar status em tempo real</li>
                <li>• Ver histórico e ganhos</li>
              </ul>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default DriverDashboard;