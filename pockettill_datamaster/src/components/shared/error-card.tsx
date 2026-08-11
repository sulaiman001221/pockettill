"use client";

import { AlertTriangle } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

interface ErrorCardProps {
  title?: string;
  description?: string;
  onRetry?: () => void;
}

export function ErrorCard({
  title = "This section couldn't load",
  description = "Something went wrong while fetching this data. Try again, or check back shortly.",
  onRetry,
}: ErrorCardProps) {
  return (
    <Card>
      <CardContent className="flex flex-col items-center justify-center gap-3 py-16 text-center">
        <div className="flex size-12 items-center justify-center rounded-full bg-destructive/10">
          <AlertTriangle className="size-6 text-destructive" />
        </div>
        <div className="space-y-1">
          <p className="text-sm font-medium">{title}</p>
          <p className="max-w-sm text-sm text-muted-foreground">{description}</p>
        </div>
        {onRetry ? (
          <Button size="sm" variant="outline" onClick={onRetry} className="mt-1">
            Try again
          </Button>
        ) : null}
      </CardContent>
    </Card>
  );
}
