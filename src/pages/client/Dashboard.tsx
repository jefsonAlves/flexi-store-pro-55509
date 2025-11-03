import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { toast } from "sonner";
import { Package, LogOut, User } from "lucide-react";
import { NewOrderDialog } from "@/components/client/NewOrderDialog";
import { ProfileForm } from "@/components/client/ProfileForm";

const ClientDashboard = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<any>(null);
  const [clientId, setClientId] = useState<string>("");
  const [tenantId, setTenantId] = useState<string>("");
  const [loading, setLoading] = useState(true);
  const [orderDialogOpen, setOrderDialogOpen] = useState(false);

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

      // Buscar dados do cliente
      const { data: clientData, error: clientError } = await supabase
        .from("clients")
        .select("id, tenant_id")
        .eq("user_id", session.user.id)
        .single();

      if (clientError) throw clientError;
      if (clientData) {
        setClientId(clientData.id);
        setTenantId(clientData.tenant_id);
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
          <h1 className="text-xl font-bold">Meus Pedidos</h1>
          <Button variant="ghost" size="sm" onClick={handleLogout}>
            <LogOut className="h-4 w-4 mr-2" />
            Sair
          </Button>
        </div>
      </header>

      {/* CONTEÚDO */}
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-5xl mx-auto">
          <Tabs defaultValue="pedidos" className="w-full">
            <TabsList className="grid w-full grid-cols-2 mb-8">
              <TabsTrigger value="pedidos">
                <Package className="h-4 w-4 mr-2" />
                Fazer Pedido
              </TabsTrigger>
              <TabsTrigger value="perfil">
                <User className="h-4 w-4 mr-2" />
                Meu Perfil
              </TabsTrigger>
            </TabsList>

            <TabsContent value="pedidos">
              <div className="text-center py-12">
                <Package className="h-16 w-16 mx-auto mb-4 text-muted-foreground" />
                <h2 className="text-2xl font-bold mb-4">Fazer Pedido</h2>
                <p className="text-muted-foreground mb-6">
                  Clique no botão abaixo para criar um novo pedido
                </p>
                <Button size="lg" onClick={() => setOrderDialogOpen(true)}>
                  <Package className="h-5 w-5 mr-2" />
                  Novo Pedido
                </Button>
              </div>
            </TabsContent>

            <TabsContent value="perfil">
              {user && <ProfileForm userId={user.id} />}
            </TabsContent>
          </Tabs>

          {clientId && tenantId && (
            <NewOrderDialog
              open={orderDialogOpen}
              onOpenChange={setOrderDialogOpen}
              clientId={clientId}
              tenantId={tenantId}
              onSuccess={() => {
                toast.success("Pedido criado com sucesso!");
              }}
            />
          )}
        </div>
      </div>
    </div>
  );
};

export default ClientDashboard;