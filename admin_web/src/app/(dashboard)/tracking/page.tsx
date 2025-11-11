"use client";

import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

export default function TrackingPage() {
  const { data: vehicles = [], isLoading: loadingVehicles } = useQuery<any[]>({ 
    queryKey: ['vehicleLocations'], 
    queryFn: () => fetchJSON('/api/tracking/vehicles') 
  });
  const { data: drivers = [], isLoading: loadingDrivers } = useQuery<any[]>({ 
    queryKey: ['driverLocations'], 
    queryFn: () => fetchJSON('/api/tracking/drivers') 
  });

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Live Tracking</h1>
        <p className="text-sm text-muted-foreground mt-1">
          (Map integration pending) Below are live location entries.
        </p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card>
          <CardHeader>
            <CardTitle>Vehicles</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="max-h-[400px] overflow-auto">
              {loadingVehicles ? (
                <div className="text-center text-sm text-muted-foreground py-4">Loading...</div>
              ) : vehicles.length === 0 ? (
                <div className="text-center text-sm text-muted-foreground py-4">No vehicle locations</div>
              ) : (
                <div className="space-y-3">
                  {vehicles.map((v, index) => (
                    <div key={v?.vehicleId || v?.tripId || `vehicle-${v?.plateNumber}`}>
                      {index > 0 && <Separator className="my-3" />}
                      <div className="space-y-1 text-sm">
                        <div className="font-medium">Plate: {v?.plateNumber ?? 'N/A'}</div>
                        <div className="text-muted-foreground">Trip: {v?.tripId ?? 'N/A'}</div>
                        <div className="text-muted-foreground">
                          Location: {v?.location?.lat?.toFixed(6) ?? 'N/A'}, {v?.location?.lng?.toFixed(6) ?? 'N/A'}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Drivers</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="max-h-[400px] overflow-auto">
              {loadingDrivers ? (
                <div className="text-center text-sm text-muted-foreground py-4">Loading...</div>
              ) : drivers.length === 0 ? (
                <div className="text-center text-sm text-muted-foreground py-4">No driver locations</div>
              ) : (
                <div className="space-y-3">
                  {drivers.map((d, index) => (
                    <div key={d?.driverId || d?.tripId || `driver-${d?.driverName}`}>
                      {index > 0 && <Separator className="my-3" />}
                      <div className="space-y-1 text-sm">
                        <div className="font-medium">Name: {d?.driverName ?? 'N/A'}</div>
                        <div className="text-muted-foreground">Trip: {d?.tripId ?? 'N/A'}</div>
                        <div className="text-muted-foreground">
                          Location: {d?.location?.lat?.toFixed(6) ?? 'N/A'}, {d?.location?.lng?.toFixed(6) ?? 'N/A'}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}


