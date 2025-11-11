"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ArrowLeft } from "lucide-react";
import { MaintenanceRecordsTable } from "@/components/maintenance/MaintenanceRecordsTable";
import { MaintenanceRemindersList } from "@/components/maintenance/MaintenanceRemindersList";

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

type Vehicle = {
  _id: string;
  plateNumber: string;
  make: string;
  model: string;
  year: number;
  capacity: number;
  status: string;
  permanentlyAssignedToUserId?: string | { _id: string; name: string; email: string; roles?: string[] };
  permanentlyAssignedDriverId?: string | { _id: string; name: string; email: string; phone?: string; employeeId?: string };
  permanentAssignmentPosition?: string;
  permanentAssignmentNotes?: string;
};

function getStatusVariant(status: string) {
  switch (status) {
    case "available":
      return "default";
    case "assigned":
      return "secondary";
    case "maintenance":
      return "destructive";
    case "permanently_assigned":
      return "outline";
    default:
      return "secondary";
  }
}

function getStatusLabel(status: string) {
  return status
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

export default function VehicleDetailPage() {
  const params = useParams();
  const router = useRouter();
  const vehicleId = params.id as string;

  const { data: vehicle, isLoading } = useQuery<Vehicle>({
    queryKey: ["vehicle", vehicleId],
    queryFn: () => fetchJSON<Vehicle>(`/api/vehicles/${vehicleId}`),
  });

  if (isLoading) {
    return (
      <div className="container mx-auto p-6">
        <div className="text-center py-8">Loading vehicle details...</div>
      </div>
    );
  }

  if (!vehicle) {
    return (
      <div className="container mx-auto p-6">
        <div className="text-center py-8">
          <p className="text-muted-foreground mb-4">Vehicle not found</p>
          <Button onClick={() => router.push("/transport/vehicles")}>Back to Vehicles</Button>
        </div>
      </div>
    );
  }

  const assignedUser = typeof vehicle.permanentlyAssignedToUserId === "object" ? vehicle.permanentlyAssignedToUserId : null;
  const assignedDriver = typeof vehicle.permanentlyAssignedDriverId === "object" ? vehicle.permanentlyAssignedDriverId : null;

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="outline" onClick={() => router.push("/transport/vehicles")}>
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back
        </Button>
        <div>
          <h1 className="text-3xl font-bold">{vehicle.plateNumber}</h1>
          <p className="text-muted-foreground">
            {vehicle.make} {vehicle.model} ({vehicle.year})
          </p>
        </div>
      </div>

      <Tabs defaultValue="details" className="space-y-4">
        <TabsList>
          <TabsTrigger value="details">Vehicle Details</TabsTrigger>
          <TabsTrigger value="records">Maintenance Records</TabsTrigger>
          <TabsTrigger value="reminders">Reminders</TabsTrigger>
        </TabsList>

        <TabsContent value="details" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Vehicle Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Plate Number</p>
                  <p className="text-lg font-semibold">{vehicle.plateNumber}</p>
                </div>
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Make & Model</p>
                  <p className="text-lg font-semibold">
                    {vehicle.make} {vehicle.model}
                  </p>
                </div>
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Year</p>
                  <p className="text-lg font-semibold">{vehicle.year}</p>
                </div>
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Capacity</p>
                  <p className="text-lg font-semibold">{vehicle.capacity} passengers</p>
                </div>
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Status</p>
                  <Badge variant={getStatusVariant(vehicle.status)}>{getStatusLabel(vehicle.status)}</Badge>
                </div>
              </div>

              {vehicle.status === "permanently_assigned" && (
                <div className="mt-6 pt-6 border-t space-y-4">
                  <h3 className="font-semibold">Permanent Assignment</h3>
                  {assignedUser && (
                    <div>
                      <p className="text-sm font-medium text-muted-foreground">Assigned Staff</p>
                      <p className="text-lg">{assignedUser.name}</p>
                      <p className="text-sm text-muted-foreground">{assignedUser.email}</p>
                    </div>
                  )}
                  {assignedDriver && (
                    <div>
                      <p className="text-sm font-medium text-muted-foreground">Assigned Driver</p>
                      <p className="text-lg">{assignedDriver.name}</p>
                      {assignedDriver.phone && <p className="text-sm text-muted-foreground">{assignedDriver.phone}</p>}
                    </div>
                  )}
                  {vehicle.permanentAssignmentPosition && (
                    <div>
                      <p className="text-sm font-medium text-muted-foreground">Position</p>
                      <p className="text-lg">{vehicle.permanentAssignmentPosition}</p>
                    </div>
                  )}
                  {vehicle.permanentAssignmentNotes && (
                    <div>
                      <p className="text-sm font-medium text-muted-foreground">Notes</p>
                      <p className="text-lg">{vehicle.permanentAssignmentNotes}</p>
                    </div>
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="records">
          <MaintenanceRecordsTable vehicleId={vehicleId} />
        </TabsContent>

        <TabsContent value="reminders">
          <MaintenanceRemindersList vehicleId={vehicleId} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

