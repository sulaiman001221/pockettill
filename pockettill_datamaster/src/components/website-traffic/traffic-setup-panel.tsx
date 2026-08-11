import { Globe } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";

const STEPS = [
  "Create a GA4 property for pockettill.co.za in Google Analytics.",
  "Create a Google Cloud service account with GA4 Viewer role.",
  "Add the service account JSON credentials to your env vars.",
];

export function TrafficSetupPanel() {
  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-4 py-16 text-center">
        <div className="flex size-12 items-center justify-center rounded-full bg-muted">
          <Globe className="size-6 text-muted-foreground" />
        </div>
        <div className="space-y-1">
          <p className="text-sm font-medium">To enable website traffic:</p>
        </div>
        <ol className="flex max-w-md flex-col gap-2 text-left text-sm text-muted-foreground">
          {STEPS.map((step, i) => (
            <li key={step} className="flex gap-2">
              <span className="font-medium text-foreground">{i + 1}.</span>
              {step}
            </li>
          ))}
        </ol>
        <p className="text-xs text-muted-foreground">
          Needs <code className="rounded bg-muted px-1 py-0.5">GA4_PROPERTY_ID</code>,{" "}
          <code className="rounded bg-muted px-1 py-0.5">GA4_CLIENT_EMAIL</code>, and{" "}
          <code className="rounded bg-muted px-1 py-0.5">GA4_PRIVATE_KEY</code> in env vars.
        </p>
      </CardContent>
    </Card>
  );
}
