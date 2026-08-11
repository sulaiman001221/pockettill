import { SupabaseCostSection } from "@/components/infrastructure/supabase-cost-section";
import { TwilioSection } from "@/components/infrastructure/twilio-section";
import { PageHeader } from "@/components/shared/page-header";
import { Separator } from "@/components/ui/separator";

export const metadata = { title: "Infrastructure Costs" };

export default function InfrastructureCostsPage() {
  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Infrastructure Costs"
        description="Read-only usage and cost tracking for platform services."
      />

      <div className="flex flex-col gap-4">
        <h2 className="text-lg font-semibold">Supabase</h2>
        <SupabaseCostSection />
      </div>

      <Separator />

      <div className="flex flex-col gap-4">
        <h2 className="text-lg font-semibold">Twilio</h2>
        <TwilioSection />
      </div>
    </div>
  );
}
