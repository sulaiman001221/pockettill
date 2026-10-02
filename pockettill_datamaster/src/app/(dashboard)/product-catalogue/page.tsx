import { VerificationQueueTab } from "@/components/catalogue/verification-queue-tab";
import { VerifiedCatalogueTab } from "@/components/catalogue/verified-catalogue-tab";
import { PageHeader } from "@/components/shared/page-header";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export const metadata = { title: "Product Catalogue" };

// The panel's "Enhance with AI" server action runs under this route's limits
// and waits on a Gemini image generation (typically ~10-20s) - well past
// Vercel's default function timeout.
export const maxDuration = 60;

export default async function ProductCataloguePage({
  searchParams,
}: {
  searchParams: { q?: string; category?: string };
}) {
  const search = searchParams.q ?? "";
  const category = searchParams.category ?? "";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Product Catalogue"
        description="Cross-store catalogue, deduplicated by barcode."
      />

      <Tabs defaultValue="verification-queue">
        <TabsList>
          <TabsTrigger value="verification-queue">Verification Queue</TabsTrigger>
          <TabsTrigger value="verified">Verified Catalogue</TabsTrigger>
        </TabsList>

        <TabsContent value="verification-queue">
          <VerificationQueueTab />
        </TabsContent>

        <TabsContent value="verified">
          <VerifiedCatalogueTab search={search} category={category} />
        </TabsContent>
      </Tabs>
    </div>
  );
}
