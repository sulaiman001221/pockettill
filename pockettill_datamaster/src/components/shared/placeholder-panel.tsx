import type { LucideIcon } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";

interface PlaceholderPanelProps {
  icon: LucideIcon;
  title: string;
  description: string;
}

export function PlaceholderPanel({ icon: Icon, title, description }: PlaceholderPanelProps) {
  return (
    <Card>
      <CardContent className="flex flex-col items-center justify-center gap-3 py-16 text-center">
        <div className="flex size-12 items-center justify-center rounded-full bg-muted">
          <Icon className="size-6 text-muted-foreground" />
        </div>
        <div className="space-y-1">
          <p className="text-sm font-medium">{title}</p>
          <p className="max-w-sm text-sm text-muted-foreground">{description}</p>
        </div>
      </CardContent>
    </Card>
  );
}
