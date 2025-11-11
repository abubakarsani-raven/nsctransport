"use client";

import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { useState } from "react";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Pencil, Trash2 } from "lucide-react";
import { useToast } from "@/components/ui/use-toast";
import { MaintenanceRecord, MAINTENANCE_TYPE_LABELS } from "@/types/maintenance";
import { CreateMaintenanceRecordDialog } from "./CreateMaintenanceRecordDialog";
import { EditMaintenanceRecordDialog } from "./EditMaintenanceRecordDialog";

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

interface MaintenanceRecordsTableProps {
  vehicleId: string;
}

export function MaintenanceRecordsTable({ vehicleId }: MaintenanceRecordsTableProps) {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [editingRecord, setEditingRecord] = useState<MaintenanceRecord | null>(null);

  const { data: records = [], isLoading } = useQuery<MaintenanceRecord[]>({
    queryKey: ["maintenance-records", vehicleId],
    queryFn: () => fetchJSON<MaintenanceRecord[]>(`/api/maintenance/vehicles/${vehicleId}/records`),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/maintenance/records/${id}`, {
        method: "DELETE",
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || "Failed to delete record");
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["maintenance-records", vehicleId] });
      success("Maintenance record deleted successfully");
    },
    onError: (err: any) => {
      error(err.message || "Failed to delete record");
    },
  });

  const formatDate = (dateString?: string) => {
    if (!dateString) return "-";
    return new Date(dateString).toLocaleString();
  };

  const getTypeLabel = (record: MaintenanceRecord) => {
    if (record.maintenanceType === "other" && record.customTypeName) {
      return record.customTypeName;
    }
    return MAINTENANCE_TYPE_LABELS[record.maintenanceType] || record.maintenanceType;
  };

  const getPerformedByName = (performedBy: string | { _id: string; name: string; email: string } | undefined) => {
    if (!performedBy) return "-";
    if (typeof performedBy === "string") return "-";
    return performedBy.name;
  };

  if (isLoading) {
    return <div className="text-center py-4">Loading records...</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">Maintenance Records</h3>
        <CreateMaintenanceRecordDialog vehicleId={vehicleId} />
      </div>

      {records.length === 0 ? (
        <div className="text-center py-8 text-muted-foreground">
          No maintenance records found. Add your first record.
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Type</TableHead>
                <TableHead>Performed At</TableHead>
                <TableHead>Available Until</TableHead>
                <TableHead>Quantity</TableHead>
                <TableHead>Cost</TableHead>
                <TableHead>Performed By</TableHead>
                <TableHead>Description</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {records.map((record) => (
                <TableRow key={record._id}>
                  <TableCell className="font-medium">{getTypeLabel(record)}</TableCell>
                  <TableCell>{formatDate(record.performedAt)}</TableCell>
                  <TableCell>
                    {record.availableUntil ? (
                      <Badge variant={new Date(record.availableUntil) > new Date() ? "default" : "secondary"}>
                        {formatDate(record.availableUntil)}
                      </Badge>
                    ) : (
                      "-"
                    )}
                  </TableCell>
                  <TableCell>{record.quantity ?? "-"}</TableCell>
                  <TableCell>{record.cost ? `$${record.cost.toFixed(2)}` : "-"}</TableCell>
                  <TableCell>{getPerformedByName(record.performedBy)}</TableCell>
                  <TableCell className="max-w-xs truncate">{record.description || "-"}</TableCell>
                  <TableCell className="text-right">
                    <div className="flex gap-2 justify-end">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => setEditingRecord(record)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          if (confirm("Are you sure you want to delete this record?")) {
                            deleteMutation.mutate(record._id);
                          }
                        }}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {editingRecord && (
        <EditMaintenanceRecordDialog
          vehicleId={vehicleId}
          record={editingRecord}
          onClose={() => setEditingRecord(null)}
        />
      )}
    </div>
  );
}

