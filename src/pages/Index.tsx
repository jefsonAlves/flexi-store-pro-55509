import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Building2, Rocket, Shield, Zap } from "lucide-react";

const Index = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/30 to-background">
      <div className="container mx-auto px-4 py-16">
        <div className="text-center space-y-8 max-w-4xl mx-auto">
          <div className="inline-flex items-center justify-center h-20 w-20 rounded-full bg-gradient-hero shadow-glow mb-6 animate-bounce">
            <Building2 className="h-10 w-10 text-white" />
          </div>
          
          <h1 className="text-5xl md:text-7xl font-bold tracking-tight">
            <span className="bg-gradient-hero bg-clip-text text-transparent">
              DeliveryPro
            </span>
          </h1>
          
          <p className="text-xl md:text-2xl text-muted-foreground max-w-2xl mx-auto">
            Plataforma White Label Multi-Tenant para Delivery e E-commerce
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center pt-8">
            <Button
              size="lg"
              className="gradient-hero shadow-glow hover:shadow-xl transition-smooth text-lg"
              onClick={() => navigate("/admin/login")}
            >
              <Shield className="mr-2 h-5 w-5" />
              Acesso Admin Master
            </Button>
          </div>

          <div className="grid md:grid-cols-3 gap-6 pt-16">
            <div className="p-6 rounded-xl bg-card border transition-smooth hover:shadow-lg hover:-translate-y-1">
              <div className="h-12 w-12 rounded-lg bg-primary/10 flex items-center justify-center mb-4">
                <Rocket className="h-6 w-6 text-primary" />
              </div>
              <h3 className="font-semibold text-lg mb-2">Multi-Tenant</h3>
              <p className="text-sm text-muted-foreground">
                Crie múltiplas instâncias isoladas com branding personalizado
              </p>
            </div>

            <div className="p-6 rounded-xl bg-card border transition-smooth hover:shadow-lg hover:-translate-y-1">
              <div className="h-12 w-12 rounded-lg bg-accent/10 flex items-center justify-center mb-4">
                <Zap className="h-6 w-6 text-accent" />
              </div>
              <h3 className="font-semibold text-lg mb-2">Tempo Real</h3>
              <p className="text-sm text-muted-foreground">
                Acompanhamento de pedidos com atualizações instantâneas
              </p>
            </div>

            <div className="p-6 rounded-xl bg-card border transition-smooth hover:shadow-lg hover:-translate-y-1">
              <div className="h-12 w-12 rounded-lg bg-secondary/10 flex items-center justify-center mb-4">
                <Shield className="h-6 w-6 text-secondary" />
              </div>
              <h3 className="font-semibold text-lg mb-2">Seguro</h3>
              <p className="text-sm text-muted-foreground">
                RLS nativo com isolamento completo de dados entre empresas
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Index;
