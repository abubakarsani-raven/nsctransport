import { notFound } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import Link from "next/link";

type RequestDetails = {
  _id: string;
  destination?: string;
  purpose?: string;
  startDate?: string;
  endDate?: string;
  status: string;
  passengerCount?: number;
  requester?: {
    name?: string;
    email?: string;
    department?: string;
  };
  assignedDriverId?: {
    name?: string;
    email?: string;
    phone?: string;
  } | null;
  assignedVehicleId?: {
    plateNumber?: string;
    make?: string;
    model?: string;
    capacity?: number;
  } | null;
  approvalChain?: any[];
  tripMetrics?: {
    distanceKm?: number;
    durationMinutes?: number;
    averageSpeedKph?: number;
  } | null;
};

async function fetchRequest(id: string): Promise<RequestDetails | null> {
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:3000"}/requests/${id}`, {
    cache: "no-store",
    credentials: "include",
  });

  if (res.status === 404) return null;
  if (!res.ok) {
    console.error("Failed to load request details", res.status);
    return null;
  }

  return res.json();
}

function formatStatus(status: string) {
  return status
    .split("_")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

function formatDate(value?: string) {
  if (!value) return "N/A";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default async function TransportRequestDetailsPage({ params }: { params: { id: string } }) {
  const request = await fetchRequest(params.id);
  if (!request) {
    notFound();
  }

  const { requester, assignedDriverId, assignedVehicleId, tripMetrics } = request;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Trip Details</h1>
          <p className="text-sm text-muted-foreground">View full information for this completed trip.</p>
        </div>
        <Button asChild variant="outline" size="sm">
          <Link href="/transport/requests">Back to Requests</Link>
        </Button>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card className="md:col-span-2">
          <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div>
              <CardTitle>{request.destination ?? "Unknown destination"}</CardTitle>
              {request.purpose && (
                <p className="mt-1 text-sm text-muted-foreground">{request.purpose}</p>
              )}
            </div>
            <Badge variant="outline" className="whitespace-nowrap">
              {formatStatus(request.status)}
            </Badge>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-1">
                <p className="text-xs font-medium text-muted-foreground">Start time</p>
                <p className="text-sm">{formatDate(request.startDate)}</p>
              </div>
              <div className="space-y-1">
                <p className="text-xs font-medium text-muted-foreground">End time</p>
                <p className="text-sm">{formatDate(request.endDate)}</p>
              </div>
              <div className="space-y-1">
                <p className="text-xs font-medium text-muted-foreground">Passengers</p>
                <p className="text-sm">{request.passengerCount ?? "N/A"}</p>
              </div>
            </div>

            <Separator />

            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-1">
                <p className="text-xs font-medium text-muted-foreground">Requester</p>
                <p className="text-sm font-medium">
                  {requester?.name ?? "Unknown requester"}
                </p>
                <p className="text-xs text-muted-foreground">
                  {requester?.email ?? "No email"}{" "}
                  {requester?.department ? `• ${requester.department}` : ""}
                </p>
              </div>

              <div className="space-y-2">
                <p className="text-xs font-medium text-muted-foreground">Assignment</p>
                <div className="space-y-1">
                  <p className="text-xs text-muted-foreground">Driver</p>
                  <p className="text-sm">
                    {assignedDriverId?.name ?? "Not assigned"}
                  </p>
                  {assignedDriverId?.email && (
                    <p className="text-xs text-muted-foreground">
                      {assignedDriverId.email}
                    </p>
                  )}
                </div>
                <div className="space-y-1">
                  <p className="text-xs text-muted-foreground">Vehicle</p>
                  <p className="text-sm">
                    {assignedVehicleId
                      ? `${assignedVehicleId.plateNumber ?? "Unknown plate"} • ${[
                          assignedVehicleId.make,
                          assignedVehicleId.model,
                        ]
                          .filter(Boolean)
                          .join(" ")}`
                      : "Not assigned"}
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Trip Metrics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Distance</span>
                <span>{tripMetrics?.distanceKm != null ? `${tripMetrics.distanceKm.toFixed(1)} km` : "N/A"}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Duration</span>
                <span>
                  {tripMetrics?.durationMinutes != null
                    ? `${Math.round(tripMetrics.durationMinutes)} min`
                    : "N/A"}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Average speed</span>
                <span>
                  {tripMetrics?.averageSpeedKph != null
                    ? `${tripMetrics.averageSpeedKph.toFixed(1)} km/h`
                    : "N/A"}
                </span>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}


