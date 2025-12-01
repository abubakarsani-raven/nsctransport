"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";

async function fetchJSON(url: string) {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to load");
  return res.json();
}

export default function Page() {
  const qc = useQueryClient();
  const [isCancelling, setIsCancelling] = useState(false);
  const [cancelResult, setCancelResult] = useState<string | null>(null);

  const { data: activeTrips, isLoading: loadingTrips } = useQuery({
    queryKey: ["activeTrips"],
    queryFn: () => fetchJSON("/api/dashboard/active-trips"),
  });
  const { data: pendingTransportRequests, isLoading: loadingTransportRequests } = useQuery({
    queryKey: ["pendingTransportRequests"],
    queryFn: () => fetchJSON("/api/dashboard/pending-transport-requests"),
  });
  const { data: pendingIctRequests, isLoading: loadingIctRequests } = useQuery({
    queryKey: ["pendingIctRequests"],
    queryFn: () => fetchJSON("/api/dashboard/pending-ict-requests"),
  });
  const { data: pendingStoreRequests, isLoading: loadingStoreRequests } = useQuery({
    queryKey: ["pendingStoreRequests"],
    queryFn: () => fetchJSON("/api/dashboard/pending-store-requests"),
  });
  const { data: availableVehicles, isLoading: loadingVehicles } = useQuery({
    queryKey: ["availableVehicles"],
    queryFn: () => fetchJSON("/api/dashboard/available-vehicles"),
  });

  const isLoading = loadingTrips || loadingTransportRequests || loadingIctRequests || loadingStoreRequests || loadingVehicles;

  async function handleCancelAllActiveTrips() {
    setIsCancelling(true);
    setCancelResult(null);
    try {
      const res = await fetch("/api/trips/admin/cancel-all-active", {
        method: "POST",
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || "Failed to cancel active trips");
      }
      const data = await res.json();
      const count = typeof data.cancelledTrips === "number" ? data.cancelledTrips : 0;
      setCancelResult(`Cancelled ${count} active trip${count === 1 ? "" : "s"}.`);
      // Refresh dashboard stats
      qc.invalidateQueries({ queryKey: ["activeTrips"] });
      qc.invalidateQueries({ queryKey: ["availableVehicles"] });
    } catch (err: any) {
      setCancelResult(err.message || "Failed to cancel active trips");
    } finally {
      setIsCancelling(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Dashboard Overview</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Real-time statistics and system metrics
          </p>
        </div>
        <div className="flex flex-col items-start gap-2 md:items-end">
          <Button
            variant="destructive"
            size="sm"
            onClick={handleCancelAllActiveTrips}
            disabled={isCancelling}
          >
            {isCancelling ? "Cancelling active trips..." : "Cancel All Active Trips"}
          </Button>
          {cancelResult && (
            <p className="text-xs text-muted-foreground max-w-xs text-right">
              {cancelResult}
            </p>
          )}
        </div>
      </div>
      <div className="grid gap-4 md:gap-6 grid-cols-1 md:grid-cols-3 lg:grid-cols-5">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Active Trips</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-bold">{activeTrips ?? 0}</div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pending Transport Requests</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-bold">{pendingTransportRequests ?? 0}</div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pending ICT Requests</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-bold">{pendingIctRequests ?? 0}</div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pending Store Requests</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-bold">{pendingStoreRequests ?? 0}</div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Available Vehicles</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-bold">{availableVehicles ?? 0}</div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}


