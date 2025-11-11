"use client";

import { useState, useEffect } from "react";
import { useMutation, useQueryClient, useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/components/ui/use-toast";
import { MaintenanceType, MAINTENANCE_TYPE_LABELS, MaintenanceRecord, CreateMaintenanceRecordDto } from "@/types/maintenance";
import { DatePicker } from "@/components/ui/date-picker";

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed");
  return res.json();
}

interface EditMaintenanceRecordDialogProps {
  vehicleId: string;
  record: MaintenanceRecord;
  onClose: () => void;
}

export function EditMaintenanceRecordDialog({ vehicleId, record, onClose }: EditMaintenanceRecordDialogProps) {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [form, setForm] = useState<CreateMaintenanceRecordDto>({
    maintenanceType: record.maintenanceType,
    customTypeName: record.customTypeName || "",
    description: record.description || "",
    performedAt: new Date(record.performedAt),
    availableUntil: record.availableUntil ? new Date(record.availableUntil) : undefined,
    quantity: record.quantity,
    performedBy: typeof record.performedBy === "string" ? record.performedBy : record.performedBy?._id,
    cost: record.cost,
  });

  const { data: users = [] } = useQuery<any[]>({
    queryKey: ["users"],
    queryFn: () => fetchJSON<any[]>("/api/users"),
  });

  const updateMutation = useMutation({
    mutationFn: async (data: CreateMaintenanceRecordDto) => {
      const res = await fetch(`/api/maintenance/records/${record._id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.message || "Failed to update record");
      }
      return res.json();
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["maintenance-records", vehicleId] });
      qc.invalidateQueries({ queryKey: ["vehicles"] });
      onClose();
      success("Maintenance record updated successfully");
    },
    onError: (err: any) => {
      error(err.message || "Failed to update record");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.performedAt) {
      error("Performed At date is required");
      return;
    }
    if (form.availableUntil && form.availableUntil < form.performedAt) {
      error("Available Until date must be greater than or equal to Performed At date");
      return;
    }
    const submitData = {
      ...form,
      performedAt: form.performedAt.toISOString(),
      availableUntil: form.availableUntil ? form.availableUntil.toISOString() : undefined,
      quantity: form.quantity ? Number(form.quantity) : undefined,
      cost: form.cost ? Number(form.cost) : undefined,
      customTypeName: form.maintenanceType === MaintenanceType.OTHER ? form.customTypeName : undefined,
    };
    updateMutation.mutate(submitData as any);
  };

  return (
    <Dialog open={true} onOpenChange={onClose}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto overflow-x-hidden">
        <DialogHeader>
          <DialogTitle>Edit Maintenance Record</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="maintenanceType">Maintenance Type *</Label>
                <Select
                  value={form.maintenanceType}
                  onValueChange={(value) => setForm({ ...form, maintenanceType: value as MaintenanceType })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {Object.entries(MAINTENANCE_TYPE_LABELS).map(([value, label]) => (
                      <SelectItem key={value} value={value}>
                        {label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {form.maintenanceType === MaintenanceType.OTHER && (
                <div className="space-y-2">
                  <Label htmlFor="customTypeName">Custom Type Name *</Label>
                  <Input
                    id="customTypeName"
                    value={form.customTypeName || ""}
                    onChange={(e) => setForm({ ...form, customTypeName: e.target.value })}
                    placeholder="Enter custom type"
                    required={form.maintenanceType === MaintenanceType.OTHER}
                  />
                </div>
              )}
            </div>

            <div className="space-y-2">
              <Label>Performed At *</Label>
              <DatePicker
                date={form.performedAt}
                onDateChange={(date) => {
                  const newDate = date || new Date();
                  if (form.availableUntil && newDate > form.availableUntil) {
                    error("Performed At date cannot be greater than Available Until date");
                    return;
                  }
                  setForm({ ...form, performedAt: newDate });
                }}
                placeholder="Select date"
              />
            </div>

            <div className="space-y-2">
              <Label>Available Until</Label>
              <DatePicker
                date={form.availableUntil}
                onDateChange={(date) => {
                  if (date && form.performedAt && date < form.performedAt) {
                    error("Available Until date must be greater than or equal to Performed At date");
                    return;
                  }
                  setForm({ ...form, availableUntil: date });
                }}
                placeholder="Select date (optional)"
              />
              {form.availableUntil && form.performedAt && form.availableUntil < form.performedAt && (
                <p className="text-sm text-red-500">Available Until must be greater than or equal to Performed At</p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="quantity">Quantity</Label>
                <Input
                  id="quantity"
                  type="number"
                  step="0.01"
                  value={form.quantity || ""}
                  onChange={(e) =>
                    setForm({ ...form, quantity: e.target.value ? Number(e.target.value) : undefined })
                  }
                  placeholder="e.g., 5 (liters, units, etc.)"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="cost">Cost</Label>
                <Input
                  id="cost"
                  type="number"
                  step="0.01"
                  value={form.cost || ""}
                  onChange={(e) =>
                    setForm({ ...form, cost: e.target.value ? Number(e.target.value) : undefined })
                  }
                  placeholder="0.00"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="performedBy">Performed By</Label>
              <Select
                value={form.performedBy || "__none__"}
                onValueChange={(value) => setForm({ ...form, performedBy: value === "__none__" ? undefined : value })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select user" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="__none__">None</SelectItem>
                  {users.map((user: any) => (
                    <SelectItem key={user._id} value={user._id}>
                      {user.name} ({user.email})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                value={form.description || ""}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder="Additional notes or details"
                rows={3}
              />
            </div>
          </div>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={updateMutation.isPending}>
              {updateMutation.isPending ? "Updating..." : "Update Record"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

