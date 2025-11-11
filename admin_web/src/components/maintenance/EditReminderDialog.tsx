"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/components/ui/use-toast";
import { MaintenanceType, MAINTENANCE_TYPE_LABELS, MaintenanceReminder, CreateReminderDto } from "@/types/maintenance";
import { DatePicker } from "@/components/ui/date-picker";

interface EditReminderDialogProps {
  vehicleId: string;
  reminder: MaintenanceReminder;
  onClose: () => void;
}

export function EditReminderDialog({ vehicleId, reminder, onClose }: EditReminderDialogProps) {
  const qc = useQueryClient();
  const { success, error } = useToast();
  const [form, setForm] = useState<CreateReminderDto>({
    maintenanceType: reminder.maintenanceType,
    customTypeName: reminder.customTypeName || "",
    reminderIntervalDays: reminder.reminderIntervalDays,
    lastPerformedDate: reminder.lastPerformedDate ? new Date(reminder.lastPerformedDate) : undefined,
    isActive: reminder.isActive,
    notes: reminder.notes || "",
  });

  const updateMutation = useMutation({
    mutationFn: async (data: {
      maintenanceType?: MaintenanceType;
      customTypeName?: string;
      reminderIntervalDays?: number;
      lastPerformedDate?: string;
      isActive?: boolean;
      notes?: string;
    }) => {
      const res = await fetch(`/api/maintenance/reminders/${reminder._id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.message || "Failed to update reminder");
      }
      return res.json();
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["maintenance-reminders", vehicleId] });
      onClose();
      success("Reminder updated successfully");
    },
    onError: (err: any) => {
      error(err.message || "Failed to update reminder");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    updateMutation.mutate({
      maintenanceType: form.maintenanceType,
      customTypeName: form.maintenanceType === MaintenanceType.OTHER ? form.customTypeName : undefined,
      reminderIntervalDays: Number(form.reminderIntervalDays),
      lastPerformedDate: form.lastPerformedDate ? form.lastPerformedDate.toISOString() : undefined,
      isActive: form.isActive,
      notes: form.notes,
    });
  };

  return (
    <Dialog open={true} onOpenChange={onClose}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Edit Maintenance Reminder</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
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

          <div className="space-y-2">
            <Label htmlFor="reminderIntervalDays">Reminder Interval (days) *</Label>
            <Input
              id="reminderIntervalDays"
              type="number"
              min="1"
              value={form.reminderIntervalDays}
              onChange={(e) => setForm({ ...form, reminderIntervalDays: Number(e.target.value) })}
              required
              placeholder="e.g., 90"
            />
          </div>

          <div className="space-y-2">
            <Label>Last Performed Date (optional)</Label>
            <DatePicker
              date={form.lastPerformedDate}
              onDateChange={(date) => setForm({ ...form, lastPerformedDate: date })}
              placeholder="Select date (optional)"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="isActive">Active</Label>
            <Select
              value={form.isActive ? "true" : "false"}
              onValueChange={(value) => setForm({ ...form, isActive: value === "true" })}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="true">Active</SelectItem>
                <SelectItem value="false">Inactive</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="notes">Notes</Label>
            <Textarea
              id="notes"
              value={form.notes || ""}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
              placeholder="Additional notes about this reminder"
              rows={3}
            />
          </div>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={updateMutation.isPending}>
              {updateMutation.isPending ? "Updating..." : "Update Reminder"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

