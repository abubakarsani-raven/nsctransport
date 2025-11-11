"use client";

import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

async function fetchJSON(url: string) {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to load");
  return res.json();
}

export default function Page() {
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

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Dashboard Overview</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Real-time statistics and system metrics
        </p>
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


